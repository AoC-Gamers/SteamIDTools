/**
 * Sends a backend request through the SteamWorks HTTP transport.
 */
bool SendSteamWorksRequest(const char[] szEndpoint, const char[] szInput, bool bBatch, Handle hPack)
{
	char szUrl[MAX_API_URL_LENGTH];
	BuildSteamIDToolsUrl(szEndpoint, szInput, true, szUrl, sizeof(szUrl));

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
 * Receives a SteamWorks response and forwards it to the shared completion path.
 */
public void OnSteamIDConversionResponse(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data1)
{
	Handle hPack = view_as<Handle>(data1);
	if (bFailure || !bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		char szError[96];
		Format(szError, sizeof(szError), "SteamWorks request failed (status %d)", view_as<int>(eStatusCode));
		CompleteRequest(hPack, false, szError);
		return;
	}

	int iBodySize = 0;
	if (!SteamWorks_GetHTTPResponseBodySize(hRequest, iBodySize) || iBodySize <= 0)
	{
		CompleteRequest(hPack, false, "Empty response");
		return;
	}

	char[] szResponse = new char[iBodySize + 1];
	SteamWorks_GetHTTPResponseBodyData(hRequest, szResponse, iBodySize);
	szResponse[iBodySize] = '\0';
	TrimString(szResponse);

	if (szResponse[0] == '\0')
	{
		CompleteRequest(hPack, false, "Empty response");
		return;
	}

	CompleteRequest(hPack, true, szResponse);
}

/**
 * Reuses the same response handling for batch requests executed by SteamWorks.
 */
public void OnSteamIDBatchResponse(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data1)
{
	OnSteamIDConversionResponse(hRequest, bFailure, bRequestSuccessful, eStatusCode, data1);
}
