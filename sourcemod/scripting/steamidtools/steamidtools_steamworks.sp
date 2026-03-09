/**
 * Sends an HTTP GET request to convert a SteamID using the SteamWorks API.
 *
 * Constructs a URL using the provided endpoint and parameter, then creates and sends an HTTP request.
 * The request is associated with the given client and labeled for identification.
 * Handles errors in request creation and sets up necessary callbacks for response handling.
 *
 * @param szEndpoint   The API endpoint to append to the base URL.
 * @param szParam      The SteamID or parameter to include in the request.
 * @param iClient      The client index to associate with the request (used for context and replies).
 * @param szLabel      A label for the request, used in the user agent and error messages.
 */
void SendSteamWorksConversionRequest(const char[] szEndpoint, const char[] szParam, int iClient, const char[] szLabel)
{
	char szUrl[MAX_API_URL_LENGTH];
	BuildSteamIDToolsUrl(szEndpoint, szParam, true, szUrl, sizeof(szUrl));

	Handle hPack = CreateRequestContext(iClient, szLabel);
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, szUrl);
	if (hRequest == INVALID_HANDLE)
	{
		delete hPack;
		ReplyToCommand(iClient, "[STEAMIDTOOLS] %s: Error creating HTTP request", szLabel);
		return;
	}

	SteamWorks_SetHTTPRequestContextValue(hRequest, hPack);
	SteamWorks_SetHTTPCallbacks(hRequest, OnSteamIDConversionResponse);
	SteamWorks_SendHTTPRequest(hRequest);
}

public void OnSteamIDConversionResponse(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data1)
{
	Handle hPack = view_as<Handle>(data1);
	char szLabel[MAX_REQUEST_LABEL_LENGTH];
	int iClient = 0;
	bool bClientValid = ReadRequestContext(hPack, iClient, szLabel, sizeof(szLabel));
	delete hPack;

	if (!bClientValid)
	{
		return;
	}

	int bodySize = 0;
	if (bFailure || !bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] %s: Online conversion failed", szLabel);
		return;
	}

	if (SteamWorks_GetHTTPResponseBodySize(hRequest, bodySize) && bodySize > 0)
	{
		char[] szResponse = new char[bodySize + 1];
		for (int i = 0; i <= bodySize; i++)
			szResponse[i] = '\0';

		SteamWorks_GetHTTPResponseBodyData(hRequest, szResponse, bodySize);
		szResponse[bodySize] = '\0';
		TrimString(szResponse);

		if (szResponse[0] != '\0')
		{
			ReplyToCommand(iClient, "[STEAMIDTOOLS] %s: %s", szLabel, szResponse);
		}
		else
		{
			ReplyToCommand(iClient, "[STEAMIDTOOLS] %s: Empty response", szLabel);
		}
	}
	else
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] %s: Empty response", szLabel);
	}
}

/**
 * Sends a batch SteamID conversion request to the specified SteamWorks API endpoint.
 *
 * Constructs a URL using the provided endpoint and batch of SteamIDs, then creates and sends an HTTP GET request.
 * Associates the request with the client index for context and sets up the response callback.
 *
 * @param szEndpoint   The API endpoint to send the request to (e.g., "/convert").
 * @param szBatch      A string containing the batch of SteamIDs to convert, separated as required by the API.
 * @param iClient      The client index to associate with the request (used for context and replies).
 */
void SendSteamWorksBatchRequest(const char[] szEndpoint, const char[] szBatch, int iClient, const char[] szLabel)
{
	char szUrl[MAX_API_URL_LENGTH];
	BuildSteamIDToolsUrl(szEndpoint, szBatch, true, szUrl, sizeof(szUrl));
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, szUrl);
	if (hRequest == INVALID_HANDLE)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] %s: Error creating HTTP request", szLabel);
		return;
	}

	Handle hPack = CreateRequestContext(iClient, szLabel);
	SteamWorks_SetHTTPRequestContextValue(hRequest, hPack);
	SteamWorks_SetHTTPCallbacks(hRequest, OnSteamIDBatchResponse);
	SteamWorks_SendHTTPRequest(hRequest);
}

public void OnSteamIDBatchResponse(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data1)
{
	Handle hPack = view_as<Handle>(data1);
	char szLabel[MAX_REQUEST_LABEL_LENGTH];
	int iClient = 0;
	bool bClientValid = ReadRequestContext(hPack, iClient, szLabel, sizeof(szLabel));
	delete hPack;

	if (!bClientValid)
	{
		return;
	}

	int bodySize = 0;
	if (bFailure || !bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] %s: Online batch conversion failed", szLabel);
		return;
	}
	if (SteamWorks_GetHTTPResponseBodySize(hRequest, bodySize) && bodySize > 0)
	{
		char[] szResponse = new char[bodySize + 1];
		for (int i = 0; i <= bodySize; i++)
			szResponse[i] = '\0';
		SteamWorks_GetHTTPResponseBodyData(hRequest, szResponse, bodySize);
		szResponse[bodySize] = '\0';
		TrimString(szResponse);
		PrintToConsole(iClient, "[STEAMIDTOOLS] Batch KeyValue Response:\n%s", szResponse);
	}
	else
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] %s: Empty response", szLabel);
	}
}
