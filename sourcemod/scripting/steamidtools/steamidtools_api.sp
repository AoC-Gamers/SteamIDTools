static const char g_szHexChars[] = "0123456789ABCDEF";

/**
 * Reads the backend base URL from the plugin cvar and removes a trailing slash.
 */
void GetApiBaseUrlInternal(char[] szBaseUrl, int iMaxLen)
{
	g_hApiBaseUrl.GetString(szBaseUrl, iMaxLen);
	TrimString(szBaseUrl);

	int iLen = strlen(szBaseUrl);
	if (iLen > 0 && szBaseUrl[iLen - 1] == '/')
	{
		szBaseUrl[iLen - 1] = '\0';
	}
}

/**
 * Returns true when a byte can be emitted without percent-encoding in a URL.
 */
bool IsUrlUnreservedChar(int iChar)
{
	return ((iChar >= 'A' && iChar <= 'Z')
		|| (iChar >= 'a' && iChar <= 'z')
		|| (iChar >= '0' && iChar <= '9')
		|| iChar == '-'
		|| iChar == '_'
		|| iChar == '.'
		|| iChar == '~');
}

/**
 * Percent-encodes the request payload before sending it to the backend.
 */
void UrlEncodeComponent(const char[] szInput, char[] szOutput, int iMaxLen)
{
	int iPos = 0;

	for (int i = 0; szInput[i] != '\0' && iPos < iMaxLen - 1; i++)
	{
		int iChar = szInput[i] & 0xFF;
		if (IsUrlUnreservedChar(iChar))
		{
			szOutput[iPos++] = view_as<char>(iChar);
			continue;
		}

		if (iPos + 3 >= iMaxLen)
		{
			break;
		}

		szOutput[iPos++] = '%';
		szOutput[iPos++] = g_szHexChars[(iChar >> 4) & 0x0F];
		szOutput[iPos++] = g_szHexChars[iChar & 0x0F];
	}

	szOutput[iPos] = '\0';
}

/**
 * Builds the final backend URL used by the HTTP transport providers.
 */
void BuildSteamIDToolsUrl(const char[] szEndpoint, const char[] szParam, bool bNullTerm, char[] szUrl, int iMaxLen)
{
	char szBaseUrl[MAX_API_BASE_URL_LENGTH];
	char szEncodedParam[STEAMIDTOOLS_MAX_REQUEST_LENGTH];

	GetApiBaseUrlInternal(szBaseUrl, sizeof(szBaseUrl));
	UrlEncodeComponent(szParam, szEncodedParam, sizeof(szEncodedParam));
	Format(szUrl, iMaxLen, "%s%s?steamid=%s%s", szBaseUrl, szEndpoint, szEncodedParam, bNullTerm ? "&nullterm=1" : "");
}

/**
 * Builds the backend health-check URL used by the transport providers.
 */
void BuildSteamIDToolsHealthUrl(char[] szUrl, int iMaxLen)
{
	char szBaseUrl[MAX_API_BASE_URL_LENGTH];

	GetApiBaseUrlInternal(szBaseUrl, sizeof(szBaseUrl));
	Format(szUrl, iMaxLen, "%s%s", szBaseUrl, API_Health);
}

/**
 * Checks whether the requested HTTP provider extension is currently available.
 */
bool IsProviderLoaded(SteamIDToolsProvider provider)
{
	switch (provider)
	{
		case SteamIDToolsProvider_SteamWorks:
		{
			return g_bSteamWorksLoaded;
		}
		case SteamIDToolsProvider_System2:
		{
			return g_bSystem2Loaded;
		}
	}

	return false;
}

/**
 * Returns true when the enum maps to a supported provider slot.
 */
bool IsValidProvider(SteamIDToolsProvider provider)
{
	return (provider == SteamIDToolsProvider_SteamWorks || provider == SteamIDToolsProvider_System2);
}

/**
 * Returns the last cached backend status for a provider.
 */
SteamIDToolsBackendStatus GetBackendStatusInternal(SteamIDToolsProvider provider)
{
	if (!IsValidProvider(provider))
	{
		return SteamIDToolsBackendStatus_Unknown;
	}

	int iProvider = view_as<int>(provider);
	if (!g_bBackendStatusKnown[iProvider])
	{
		return SteamIDToolsBackendStatus_Unknown;
	}

	return g_bBackendOnline[iProvider] ? SteamIDToolsBackendStatus_Online : SteamIDToolsBackendStatus_Offline;
}

/**
 * Returns true when the provider transport exists and the backend is healthy.
 */
bool IsProviderReadyInternal(SteamIDToolsProvider provider)
{
	return (IsProviderLoaded(provider) && GetBackendStatusInternal(provider) == SteamIDToolsBackendStatus_Online);
}

/**
 * Selects the provider that should execute a request when the caller does not
 * want to pin one explicitly.
 *
 * Preference order:
 * 1. A provider that is both loaded and backend-ready
 * 2. A provider that is at least loaded, even if health is still unknown/offline
 */
SteamIDToolsProvider ResolveRequestProvider(SteamIDToolsProvider provider)
{
	if (provider != SteamIDToolsProvider_Auto)
	{
		return provider;
	}

	if (IsProviderReadyInternal(SteamIDToolsProvider_SteamWorks))
	{
		return SteamIDToolsProvider_SteamWorks;
	}

	if (IsProviderReadyInternal(SteamIDToolsProvider_System2))
	{
		return SteamIDToolsProvider_System2;
	}

	if (IsProviderLoaded(SteamIDToolsProvider_SteamWorks))
	{
		return SteamIDToolsProvider_SteamWorks;
	}

	if (IsProviderLoaded(SteamIDToolsProvider_System2))
	{
		return SteamIDToolsProvider_System2;
	}

	return SteamIDToolsProvider_Auto;
}

/**
 * Returns a readable provider name for logs and diagnostics.
 */
void GetProviderName(SteamIDToolsProvider provider, char[] szBuffer, int iMaxLen)
{
	switch (provider)
	{
		case SteamIDToolsProvider_SteamWorks:
		{
			strcopy(szBuffer, iMaxLen, "SteamWorks");
		}
		case SteamIDToolsProvider_System2:
		{
			strcopy(szBuffer, iMaxLen, "system2");
		}
		default:
		{
			strcopy(szBuffer, iMaxLen, "unknown");
		}
	}
}

/**
 * Fires the public forward used to notify backend status changes.
 */
void FireBackendStatusChangedForward(SteamIDToolsProvider provider, SteamIDToolsBackendStatus status, const char[] szMessage)
{
	if (g_hBackendStatusChangedForward == INVALID_HANDLE)
	{
		return;
	}

	Call_StartForward(g_hBackendStatusChangedForward);
	Call_PushCell(view_as<int>(provider));
	Call_PushCell(view_as<int>(status));
	Call_PushString(szMessage);
	Call_Finish();
}

/**
 * Updates the cached backend status and notifies listeners when it changes.
 */
void SetBackendStatus(SteamIDToolsProvider provider, SteamIDToolsBackendStatus status, const char[] szMessage)
{
	if (!IsValidProvider(provider))
	{
		return;
	}

	int iProvider = view_as<int>(provider);
	SteamIDToolsBackendStatus oldStatus = GetBackendStatusInternal(provider);
	char szOldMessage[STEAMIDTOOLS_BACKEND_STATUS_TEXT_LENGTH];
	strcopy(szOldMessage, sizeof(szOldMessage), g_szBackendStatusMessage[iProvider]);

	g_bBackendStatusKnown[iProvider] = (status != SteamIDToolsBackendStatus_Unknown);
	g_bBackendOnline[iProvider] = (status == SteamIDToolsBackendStatus_Online);
	strcopy(g_szBackendStatusMessage[iProvider], sizeof(g_szBackendStatusMessage[]), szMessage);
	char szProviderName[16];
	GetProviderName(provider, szProviderName, sizeof(szProviderName));
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_HEALTH, "Backend status updated. provider=%s status=%d message=%s", szProviderName, view_as<int>(status), szMessage);

	if (oldStatus != status || !StrEqual(szOldMessage, szMessage))
	{
		FireBackendStatusChangedForward(provider, status, szMessage);
	}
}

/**
 * Restarts the periodic health timer after configuration changes.
 */
void RestartHealthCheckTimer()
{
	if (g_hHealthCheckTimer != INVALID_HANDLE)
	{
		delete g_hHealthCheckTimer;
		g_hHealthCheckTimer = INVALID_HANDLE;
	}

	float flInterval = g_hHealthCheckInterval.FloatValue;
	if (flInterval <= 0.0)
	{
		SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_HEALTH, "Health timer disabled.");
		return;
	}

	g_hHealthCheckTimer = CreateTimer(flInterval, Timer_BackendHealthCheck, _, TIMER_REPEAT);
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_HEALTH, "Health timer started. interval=%.2f", flInterval);
}

/**
 * Creates the small context used by the internal health-check callbacks.
 */
Handle CreateHealthCheckContext(SteamIDToolsProvider provider)
{
	Handle hPack = CreateDataPack();
	WritePackCell(hPack, view_as<int>(provider));
	return hPack;
}

/**
 * Completes one internal health check and stores the resulting status.
 */
void CompleteHealthCheck(Handle hPack, bool bSuccess, const char[] szMessage)
{
	ResetPack(hPack);
	SteamIDToolsProvider provider = view_as<SteamIDToolsProvider>(ReadPackCell(hPack));
	delete hPack;

	if (!IsValidProvider(provider))
	{
		return;
	}

	int iProvider = view_as<int>(provider);
	g_bHealthCheckInFlight[iProvider] = false;
	char szProviderName[16];
	GetProviderName(provider, szProviderName, sizeof(szProviderName));
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_HEALTH, "Health check completed. provider=%s success=%d message=%s", szProviderName, bSuccess ? 1 : 0, szMessage);
	SetBackendStatus(provider, bSuccess ? SteamIDToolsBackendStatus_Online : SteamIDToolsBackendStatus_Offline, szMessage);
}

/**
 * Allocates the next positive request id exposed to plugin consumers.
 */
int AllocateRequestId()
{
	g_iNextRequestId++;
	if (g_iNextRequestId <= 0)
	{
		g_iNextRequestId = 1;
	}

	return g_iNextRequestId;
}

/**
 * Serializes request metadata so transport callbacks can complete it later.
 */
Handle CreateRequestContext(int iRequestId, SteamIDToolsProvider provider, bool bBatch, const char[] szEndpoint, const char[] szInput, const char[] szTag)
{
	Handle hPack = CreateDataPack();
	WritePackCell(hPack, iRequestId);
	WritePackCell(hPack, view_as<int>(provider));
	WritePackCell(hPack, bBatch ? 1 : 0);
	WritePackString(hPack, szEndpoint);
	WritePackString(hPack, szInput);
	WritePackString(hPack, szTag);
	return hPack;
}

/**
 * Restores request metadata from the serialized transport context.
 */
void ReadRequestContext(Handle hPack, int &iRequestId, SteamIDToolsProvider &provider, bool &bBatch, char[] szEndpoint, int iEndpointLen, char[] szInput, int iInputLen, char[] szTag, int iTagLen)
{
	ResetPack(hPack);
	iRequestId = ReadPackCell(hPack);
	provider = view_as<SteamIDToolsProvider>(ReadPackCell(hPack));
	bBatch = (ReadPackCell(hPack) != 0);
	ReadPackString(hPack, szEndpoint, iEndpointLen);
	ReadPackString(hPack, szInput, iInputLen);
	ReadPackString(hPack, szTag, iTagLen);
}

/**
 * Emits the public completion forward consumed by external plugins.
 */
void FireRequestFinishedForward(int iRequestId, SteamIDToolsProvider provider, bool bSuccess, bool bBatch, const char[] szEndpoint, const char[] szInput, const char[] szResult, const char[] szTag)
{
	if (g_hRequestFinishedForward == INVALID_HANDLE)
	{
		return;
	}

	Call_StartForward(g_hRequestFinishedForward);
	Call_PushCell(iRequestId);
	Call_PushCell(view_as<int>(provider));
	Call_PushCell(bSuccess ? 1 : 0);
	Call_PushCell(bBatch ? 1 : 0);
	Call_PushString(szEndpoint);
	Call_PushString(szInput);
	Call_PushString(szResult);
	Call_PushString(szTag);
	Call_Finish();

	char szProviderName[16];
	GetProviderName(provider, szProviderName, sizeof(szProviderName));
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_REQUEST, "Request finished. id=%d provider=%s success=%d batch=%d endpoint=%s input=%s tag=%s result=%s", iRequestId, szProviderName, bSuccess ? 1 : 0, bBatch ? 1 : 0, szEndpoint, szInput, szTag, szResult);
}

/**
 * Completes a queued request by unpacking its metadata and firing the forward.
 */
void CompleteRequest(Handle hPack, bool bSuccess, const char[] szResult)
{
	int iRequestId = 0;
	SteamIDToolsProvider provider = SteamIDToolsProvider_Auto;
	bool bBatch = false;
	char szEndpoint[STEAMIDTOOLS_MAX_ENDPOINT_LENGTH];
	char szInput[STEAMIDTOOLS_MAX_REQUEST_LENGTH];
	char szTag[STEAMIDTOOLS_MAX_TAG_LENGTH];

	ReadRequestContext(hPack, iRequestId, provider, bBatch, szEndpoint, sizeof(szEndpoint), szInput, sizeof(szInput), szTag, sizeof(szTag));
	delete hPack;

	if (IsValidProvider(provider))
	{
		SetBackendStatus(provider, bSuccess ? SteamIDToolsBackendStatus_Online : SteamIDToolsBackendStatus_Offline, bSuccess ? "Request OK" : szResult);
	}

	FireRequestFinishedForward(iRequestId, provider, bSuccess, bBatch, szEndpoint, szInput, szResult, szTag);
}

/**
 * Rejects empty endpoint or payload values before a request is queued.
 */
bool IsValidRequestInput(const char[] szEndpoint, const char[] szInput)
{
	return (szEndpoint[0] != '\0' && szInput[0] != '\0');
}

/**
 * Dispatches the request to the selected HTTP provider implementation.
 */
bool SendProviderRequest(SteamIDToolsProvider provider, const char[] szEndpoint, const char[] szInput, bool bBatch, Handle hPack)
{
	switch (provider)
	{
		case SteamIDToolsProvider_SteamWorks:
		{
			return SendSteamWorksRequest(szEndpoint, szInput, bBatch, hPack);
		}
		case SteamIDToolsProvider_System2:
		{
			return SendSystem2Request(szEndpoint, szInput, bBatch, hPack);
		}
	}

	return false;
}

/**
 * Starts an async backend health probe for the selected provider.
 */
bool RequestBackendHealthCheck(SteamIDToolsProvider provider)
{
	if (!IsValidProvider(provider) || !IsProviderLoaded(provider))
	{
		SetBackendStatus(provider, SteamIDToolsBackendStatus_Unknown, "Provider unavailable");
		return false;
	}

	int iProvider = view_as<int>(provider);
	if (g_bHealthCheckInFlight[iProvider])
	{
		SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_HEALTH, "Health check skipped because one is already in flight. provider=%d", iProvider);
		return false;
	}

	Handle hPack = CreateHealthCheckContext(provider);
	g_bHealthCheckInFlight[iProvider] = true;
	char szProviderName[16];
	GetProviderName(provider, szProviderName, sizeof(szProviderName));
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_HEALTH, "Queueing health check. provider=%s", szProviderName);

	switch (provider)
	{
		case SteamIDToolsProvider_SteamWorks:
		{
			if (SendSteamWorksHealthCheck(hPack))
			{
				return true;
			}
		}
		case SteamIDToolsProvider_System2:
		{
			if (SendSystem2HealthCheck(hPack))
			{
				return true;
			}
		}
	}

	g_bHealthCheckInFlight[iProvider] = false;
	delete hPack;
	SetBackendStatus(provider, SteamIDToolsBackendStatus_Offline, "Failed to start health check");
	return false;
}

/**
 * Queues health checks for all currently loaded providers.
 */
void RequestAllBackendHealthChecks()
{
	RequestBackendHealthCheck(SteamIDToolsProvider_SteamWorks);
	RequestBackendHealthCheck(SteamIDToolsProvider_System2);
}

/**
 * Validates and enqueues a new online request exposed through the public natives.
 */
int StartOnlineRequest(SteamIDToolsProvider provider, const char[] szEndpoint, const char[] szInput, bool bBatch, const char[] szTag)
{
	provider = ResolveRequestProvider(provider);

	if (!IsProviderLoaded(provider))
	{
		char szProviderName[16];
		GetProviderName(provider, szProviderName, sizeof(szProviderName));
		SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_REQUEST, "Request rejected because provider is unavailable. provider=%s endpoint=%s input=%s", szProviderName, szEndpoint, szInput);
		LogError("[STEAMIDTOOLS] Provider unavailable: %s", szProviderName);
		return 0;
	}

	if (!IsValidRequestInput(szEndpoint, szInput))
	{
		SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_REQUEST, "Request rejected because input is invalid. endpoint=%s input=%s", szEndpoint, szInput);
		LogError("[STEAMIDTOOLS] Invalid online request input");
		return 0;
	}

	int iRequestId = AllocateRequestId();
	Handle hPack = CreateRequestContext(iRequestId, provider, bBatch, szEndpoint, szInput, szTag);
	char szProviderName[16];
	GetProviderName(provider, szProviderName, sizeof(szProviderName));
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_REQUEST, "Queueing request. id=%d provider=%s batch=%d endpoint=%s input=%s tag=%s", iRequestId, szProviderName, bBatch ? 1 : 0, szEndpoint, szInput, szTag);
	if (!SendProviderRequest(provider, szEndpoint, szInput, bBatch, hPack))
	{
		SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_REQUEST, "Failed to dispatch request. id=%d provider=%s endpoint=%s", iRequestId, szProviderName, szEndpoint);
		delete hPack;
		return 0;
	}

	return iRequestId;
}

/**
 * Reacts to cvar changes by refreshing timer state and re-probing the backend.
 */
public void OnSteamIDToolsSettingsChanged(ConVar hConVar, const char[] szOldValue, const char[] szNewValue)
{
	char szConVarName[64];
	hConVar.GetName(szConVarName, sizeof(szConVarName));
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_GENERAL, "Setting changed. name=%s old=%s new=%s", szConVarName, szOldValue, szNewValue);

	if (hConVar == g_hDebugMask)
	{
		return;
	}

	if (hConVar == g_hHealthCheckInterval)
	{
		RestartHealthCheckTimer();
	}

	SetBackendStatus(SteamIDToolsProvider_SteamWorks, SteamIDToolsBackendStatus_Unknown, "Health check pending");
	SetBackendStatus(SteamIDToolsProvider_System2, SteamIDToolsBackendStatus_Unknown, "Health check pending");
	RequestAllBackendHealthChecks();
}

/**
 * Periodically refreshes the cached backend status.
 */
public Action Timer_BackendHealthCheck(Handle hTimer)
{
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_HEALTH, "Periodic health check tick.");
	RequestAllBackendHealthChecks();
	return Plugin_Continue;
}

/**
 * Native wrapper that reports whether a provider can currently be used.
 */
public int Native_IsProviderAvailable(Handle hPlugin, int iNumParams)
{
	SteamIDToolsProvider provider = view_as<SteamIDToolsProvider>(GetNativeCell(1));
	return IsProviderLoaded(provider);
}

/**
 * Native wrapper that returns the current cached backend status enum.
 */
public int Native_GetBackendStatus(Handle hPlugin, int iNumParams)
{
	SteamIDToolsProvider provider = view_as<SteamIDToolsProvider>(GetNativeCell(1));
	return view_as<int>(GetBackendStatusInternal(provider));
}

/**
 * Native wrapper that returns true when both provider and backend are ready.
 */
public int Native_IsProviderReady(Handle hPlugin, int iNumParams)
{
	SteamIDToolsProvider provider = view_as<SteamIDToolsProvider>(GetNativeCell(1));
	return IsProviderReadyInternal(provider);
}

/**
 * Native wrapper that queues a backend health probe.
 */
public int Native_RequestHealthCheck(Handle hPlugin, int iNumParams)
{
	SteamIDToolsProvider provider = view_as<SteamIDToolsProvider>(GetNativeCell(1));
	return RequestBackendHealthCheck(provider);
}

/**
 * Native wrapper that returns the last cached backend status text.
 */
public int Native_GetBackendStatusMessage(Handle hPlugin, int iNumParams)
{
	SteamIDToolsProvider provider = view_as<SteamIDToolsProvider>(GetNativeCell(1));
	int iMaxLen = GetNativeCell(3);

	if (!IsValidProvider(provider))
	{
		SetNativeString(2, "", iMaxLen, true);
		return 0;
	}

	SetNativeString(2, g_szBackendStatusMessage[view_as<int>(provider)], iMaxLen, true);
	return 1;
}

/**
 * Native wrapper that returns the configured backend base URL.
 */
public int Native_GetApiBaseUrl(Handle hPlugin, int iNumParams)
{
	char szBaseUrl[MAX_API_BASE_URL_LENGTH];
	int iMaxLen = GetNativeCell(2);

	GetApiBaseUrlInternal(szBaseUrl, sizeof(szBaseUrl));
	SetNativeString(1, szBaseUrl, iMaxLen, true);
	return 1;
}

/**
 * Native wrapper that enqueues a single backend conversion request.
 */
public int Native_RequestConversion(Handle hPlugin, int iNumParams)
{
	SteamIDToolsProvider provider = view_as<SteamIDToolsProvider>(GetNativeCell(1));
	char szEndpoint[STEAMIDTOOLS_MAX_ENDPOINT_LENGTH];
	char szInput[STEAMIDTOOLS_MAX_REQUEST_LENGTH];
	char szTag[STEAMIDTOOLS_MAX_TAG_LENGTH];

	GetNativeString(2, szEndpoint, sizeof(szEndpoint));
	GetNativeString(3, szInput, sizeof(szInput));
	GetNativeString(4, szTag, sizeof(szTag));

	return StartOnlineRequest(provider, szEndpoint, szInput, false, szTag);
}

/**
 * Native wrapper that enqueues a batch backend conversion request.
 */
public int Native_RequestBatch(Handle hPlugin, int iNumParams)
{
	SteamIDToolsProvider provider = view_as<SteamIDToolsProvider>(GetNativeCell(1));
	char szEndpoint[STEAMIDTOOLS_MAX_ENDPOINT_LENGTH];
	char szInput[STEAMIDTOOLS_MAX_REQUEST_LENGTH];
	char szTag[STEAMIDTOOLS_MAX_TAG_LENGTH];

	GetNativeString(2, szEndpoint, sizeof(szEndpoint));
	GetNativeString(3, szInput, sizeof(szInput));
	GetNativeString(4, szTag, sizeof(szTag));

	return StartOnlineRequest(provider, szEndpoint, szInput, true, szTag);
}
