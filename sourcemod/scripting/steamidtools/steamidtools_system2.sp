/**
 * Sends a backend request through the system2 HTTP transport.
 */
bool SendSystem2Request(const char[] szEndpoint, const char[] szInput, bool bBatch, Handle hPack)
{
	char szUrl[MAX_API_URL_LENGTH];
	BuildSteamIDToolsUrl(szEndpoint, szInput, false, szUrl, sizeof(szUrl));
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_REQUEST, "system2 send request. batch=%d endpoint=%s input=%s url=%s", bBatch ? 1 : 0, szEndpoint, szInput, szUrl);

	System2HTTPRequest hRequest = new System2HTTPRequest(bBatch ? System2_BatchCallback : System2_Callback, szUrl);
	if (hRequest == null)
	{
		LogError("[STEAMIDTOOLS] [system2] Error creating HTTP request: %s", szUrl);
		return false;
	}

	hRequest.Any = hPack;
	hRequest.GET();
	return true;
}

/**
 * Sends a backend health request through the system2 HTTP transport.
 */
bool SendSystem2HealthCheck(Handle hPack)
{
	char szUrl[MAX_API_URL_LENGTH];
	BuildSteamIDToolsHealthUrl(szUrl, sizeof(szUrl));
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_HEALTH, "system2 send health check. url=%s", szUrl);

	System2HTTPRequest hRequest = new System2HTTPRequest(System2_HealthCallback, szUrl);
	if (hRequest == null)
	{
		LogError("[STEAMIDTOOLS] [system2] Error creating health request: %s", szUrl);
		return false;
	}

	hRequest.Any = hPack;
	hRequest.GET();
	return true;
}

/**
 * Receives a system2 response and forwards it to the shared completion path.
 */
public void System2_Callback(bool bSuccess, const char[] szError, System2HTTPRequest hRequest, System2HTTPResponse hResponse, HTTPRequestMethod method)
{
	Handle hPack = view_as<Handle>(hRequest.Any);
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_REQUEST, "system2 response received. success=%d error=%s has_response=%d", bSuccess ? 1 : 0, szError, hResponse != null ? 1 : 0);
	if (!bSuccess || hResponse == null)
	{
		CompleteRequest(hPack, false, szError);
		return;
	}

	int iContentLength = hResponse.ContentLength;
	if (iContentLength < 0)
	{
		iContentLength = 0;
	}

	char[] szResponse = new char[iContentLength + 1];
	hResponse.GetContent(szResponse, iContentLength + 1);
	TrimString(szResponse);

	if (szResponse[0] == '\0')
	{
		CompleteRequest(hPack, false, "Empty response");
		return;
	}

	CompleteRequest(hPack, true, szResponse);
}

/**
 * Reuses the same response handling for batch requests executed by system2.
 */
public void System2_BatchCallback(bool bSuccess, const char[] szError, System2HTTPRequest hRequest, System2HTTPResponse hResponse, HTTPRequestMethod method)
{
	System2_Callback(bSuccess, szError, hRequest, hResponse, method);
}

/**
 * Receives a system2 backend health response and updates cached status.
 */
public void System2_HealthCallback(bool bSuccess, const char[] szError, System2HTTPRequest hRequest, System2HTTPResponse hResponse, HTTPRequestMethod method)
{
	Handle hPack = view_as<Handle>(hRequest.Any);
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_HEALTH, "system2 health response received. success=%d error=%s has_response=%d", bSuccess ? 1 : 0, szError, hResponse != null ? 1 : 0);
	if (!bSuccess || hResponse == null)
	{
		CompleteHealthCheck(hPack, false, szError);
		return;
	}

	int iContentLength = hResponse.ContentLength;
	if (iContentLength < 0)
	{
		iContentLength = 0;
	}

	char[] szResponse = new char[iContentLength + 1];
	hResponse.GetContent(szResponse, iContentLength + 1);
	TrimString(szResponse);

	CompleteHealthCheck(hPack, true, szResponse[0] != '\0' ? szResponse : "OK");
}
