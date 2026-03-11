/**
 * Sends a backend request through the system2 HTTP transport.
 */
bool SendSystem2Request(const char[] szEndpoint, const char[] szInput, bool bBatch, Handle hPack)
{
	char szUrl[MAX_API_URL_LENGTH];
	BuildSteamIDToolsUrl(szEndpoint, szInput, false, szUrl, sizeof(szUrl));

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
 * Receives a system2 response and forwards it to the shared completion path.
 */
public void System2_Callback(bool bSuccess, const char[] szError, System2HTTPRequest hRequest, System2HTTPResponse hResponse, HTTPRequestMethod method)
{
	Handle hPack = view_as<Handle>(hRequest.Any);
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
