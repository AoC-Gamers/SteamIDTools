/**
 * Sends a backend request through the SteamWorks HTTP transport.
 */
bool SendSteamWorksRequest(const char[] szEndpoint, const char[] szInput, bool bBatch, Handle hPack)
{
	char szUrl[MAX_API_URL_LENGTH];
	BuildSteamIDToolsUrl(szEndpoint, szInput, true, szUrl, sizeof(szUrl));
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_REQUEST, "SteamWorks send request. batch=%d endpoint=%s input=%s url=%s", bBatch ? 1 : 0, szEndpoint, szInput, szUrl);

	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, szUrl);
	if (hRequest == INVALID_HANDLE)
	{
		LogError("[STEAMIDTOOLS] [SteamWorks] Error creating HTTP request: %s", szUrl);
		return false;
	}

	SteamWorks_SetHTTPRequestContextValue(hRequest, hPack);
	SteamWorks_SetHTTPCallbacks(hRequest, bBatch ? OnSteamIDBatchResponse : OnSteamIDConversionResponse);
	if (!SteamWorks_SendHTTPRequest(hRequest))
	{
		LogError("[STEAMIDTOOLS] [SteamWorks] Error sending HTTP request: %s", szUrl);
		delete hRequest;
		return false;
	}

	return true;
}

/**
 * Sends a backend health request through the SteamWorks HTTP transport.
 */
bool SendSteamWorksHealthCheck(Handle hPack)
{
	char szUrl[MAX_API_URL_LENGTH];
	BuildSteamIDToolsHealthUrl(szUrl, sizeof(szUrl));
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_HEALTH, "SteamWorks send health check. url=%s", szUrl);

	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, szUrl);
	if (hRequest == INVALID_HANDLE)
	{
		LogError("[STEAMIDTOOLS] [SteamWorks] Error creating health request: %s", szUrl);
		return false;
	}

	SteamWorks_SetHTTPRequestContextValue(hRequest, hPack);
	SteamWorks_SetHTTPCallbacks(hRequest, OnSteamIDHealthResponse);
	if (!SteamWorks_SendHTTPRequest(hRequest))
	{
		LogError("[STEAMIDTOOLS] [SteamWorks] Error sending health request: %s", szUrl);
		delete hRequest;
		return false;
	}

	return true;
}

/**
 * Receives a SteamWorks response and forwards it to the shared completion path.
 */
public void OnSteamIDConversionResponse(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data1)
{
	Handle hPack = view_as<Handle>(data1);
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_REQUEST, "SteamWorks response received. failure=%d request_success=%d status=%d", bFailure ? 1 : 0, bRequestSuccessful ? 1 : 0, view_as<int>(eStatusCode));
	if (bFailure || !bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		char szError[96];
		Format(szError, sizeof(szError), "SteamWorks request failed (status %d)", view_as<int>(eStatusCode));
		CompleteRequest(hPack, false, szError);
		delete hRequest;
		return;
	}

	int iBodySize = 0;
	if (!SteamWorks_GetHTTPResponseBodySize(hRequest, iBodySize) || iBodySize <= 0)
	{
		CompleteRequest(hPack, false, "Empty response");
		delete hRequest;
		return;
	}

	char[] szResponse = new char[iBodySize + 1];
	int iWritten = 0;
	bool bTruncated = false;
	if (!SteamWorks_GetHTTPResponseBodyString(hRequest, szResponse, iBodySize + 1, iWritten, bTruncated))
	{
		CompleteRequest(hPack, false, "Failed to read response body");
		delete hRequest;
		return;
	}

	if (bTruncated)
	{
		CompleteRequest(hPack, false, "Response body truncated");
		delete hRequest;
		return;
	}

	TrimString(szResponse);

	if (szResponse[0] == '\0')
	{
		CompleteRequest(hPack, false, "Empty response");
		delete hRequest;
		return;
	}

	CompleteRequest(hPack, true, szResponse);
	delete hRequest;
}

/**
 * Reuses the same response handling for batch requests executed by SteamWorks.
 */
public void OnSteamIDBatchResponse(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data1)
{
	OnSteamIDConversionResponse(hRequest, bFailure, bRequestSuccessful, eStatusCode, data1);
}

/**
 * Receives a SteamWorks backend health response and updates cached status.
 */
public void OnSteamIDHealthResponse(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data1)
{
	Handle hPack = view_as<Handle>(data1);
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_HEALTH, "SteamWorks health response received. failure=%d request_success=%d status=%d", bFailure ? 1 : 0, bRequestSuccessful ? 1 : 0, view_as<int>(eStatusCode));
	if (bFailure || !bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		char szError[96];
		Format(szError, sizeof(szError), "SteamWorks health check failed (status %d)", view_as<int>(eStatusCode));
		CompleteHealthCheck(hPack, false, szError);
		delete hRequest;
		return;
	}

	int iBodySize = 0;
	if (!SteamWorks_GetHTTPResponseBodySize(hRequest, iBodySize) || iBodySize <= 0)
	{
		CompleteHealthCheck(hPack, true, "OK");
		delete hRequest;
		return;
	}

	char[] szResponse = new char[iBodySize + 1];
	int iWritten = 0;
	bool bTruncated = false;
	if (!SteamWorks_GetHTTPResponseBodyString(hRequest, szResponse, iBodySize + 1, iWritten, bTruncated))
	{
		CompleteHealthCheck(hPack, false, "Failed to read health response");
		delete hRequest;
		return;
	}

	if (bTruncated)
	{
		CompleteHealthCheck(hPack, false, "Health response truncated");
		delete hRequest;
		return;
	}

	TrimString(szResponse);

	CompleteHealthCheck(hPack, true, szResponse[0] != '\0' ? szResponse : "OK");
	delete hRequest;
}
