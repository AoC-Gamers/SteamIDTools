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
}

/**
 * Completes a queued request by unpacking its metadata and firing the forward.
 */
void CompleteRequest(Handle hPack, bool bSuccess, const char[] szResult)
{
	int iRequestId = 0;
	SteamIDToolsProvider provider = SteamIDToolsProvider_Unknown;
	bool bBatch = false;
	char szEndpoint[STEAMIDTOOLS_MAX_ENDPOINT_LENGTH];
	char szInput[STEAMIDTOOLS_MAX_REQUEST_LENGTH];
	char szTag[STEAMIDTOOLS_MAX_TAG_LENGTH];

	ReadRequestContext(hPack, iRequestId, provider, bBatch, szEndpoint, sizeof(szEndpoint), szInput, sizeof(szInput), szTag, sizeof(szTag));
	delete hPack;

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
 * Validates and enqueues a new online request exposed through the public natives.
 */
int StartOnlineRequest(SteamIDToolsProvider provider, const char[] szEndpoint, const char[] szInput, bool bBatch, const char[] szTag)
{
	if (!IsProviderLoaded(provider))
	{
		char szProviderName[16];
		GetProviderName(provider, szProviderName, sizeof(szProviderName));
		LogError("[STEAMIDTOOLS] Provider unavailable: %s", szProviderName);
		return 0;
	}

	if (!IsValidRequestInput(szEndpoint, szInput))
	{
		LogError("[STEAMIDTOOLS] Invalid online request input");
		return 0;
	}

	int iRequestId = AllocateRequestId();
	Handle hPack = CreateRequestContext(iRequestId, provider, bBatch, szEndpoint, szInput, szTag);
	if (!SendProviderRequest(provider, szEndpoint, szInput, bBatch, hPack))
	{
		delete hPack;
		return 0;
	}

	return iRequestId;
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
