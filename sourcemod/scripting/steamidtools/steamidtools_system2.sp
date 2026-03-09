/**
 * Sends an HTTP GET request to convert a SteamID using the System2 extension.
 *
 * Constructs the request URL using the provided endpoint and parameter, logs the request,
 * and packs the user context and label for use in the callback. The request is sent asynchronously.
 *
 * @param szEndpoint   The API endpoint to append to the base URL.
 * @param szParam      The SteamID or parameter to include in the request.
 * @param iClient      The client index associated with this request.
 * @param szLabel      A label to identify this request, stored for callback reference.
 */
void SendSystem2ConversionRequest(const char[] szEndpoint, const char[] szParam, int iClient, const char[] szLabel)
{
	char szUrl[MAX_API_URL_LENGTH];
	BuildSteamIDToolsUrl(szEndpoint, szParam, false, szUrl, sizeof(szUrl));

	LogMessage("[STEAMIDTOOLS] [system2] Sending request: %s (Label: %s)", szUrl, szLabel);

	Handle hPack = CreateRequestContext(iClient, szLabel);

	System2HTTPRequest req = new System2HTTPRequest(System2_Callback, szUrl);
	req.Any				   = hPack;
	req.GET();
}

public void System2_Callback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	Handle hPack = view_as<Handle>(request.Any);
	char szLabel[MAX_REQUEST_LABEL_LENGTH];
	int iClient = 0;
	bool bClientValid = ReadRequestContext(hPack, iClient, szLabel, sizeof(szLabel));
	delete hPack;

	if (!bClientValid)
	{
		return;
	}

	if (!success || response == null)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] %s: Error: %s", szLabel, error);
		return;
	}

	char szResponse[MAX_HTTP_RESPONSE_LENGTH];
	response.GetContent(szResponse, sizeof(szResponse));
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

/**
 * Sends a batch SteamID conversion request using the System2 HTTP library.
 *
 * Constructs a URL using the provided endpoint and batch of SteamIDs, then sends a GET request.
 * The user context and label are packed and passed along for use in the callback.
 *
 * @param szEndpoint   The API endpoint to append to the base URL.
 * @param szBatch      A string containing the batch of SteamIDs to convert.
 * @param iClient      The client index associated with this request.
 */
void SendSystem2BatchRequest(const char[] szEndpoint, const char[] szBatch, int iClient, const char[] szLabel)
{
	char szUrl[MAX_API_URL_LENGTH];
	BuildSteamIDToolsUrl(szEndpoint, szBatch, false, szUrl, sizeof(szUrl));

	Handle hPack = CreateRequestContext(iClient, szLabel);

	System2HTTPRequest req = new System2HTTPRequest(System2_BatchCallback, szUrl);
	req.Any				   = hPack;
	req.GET();
}

public void System2_BatchCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	Handle hPack = view_as<Handle>(request.Any);
	char szLabel[MAX_REQUEST_LABEL_LENGTH];
	int iClient = 0;
	bool bClientValid = ReadRequestContext(hPack, iClient, szLabel, sizeof(szLabel));
	delete hPack;

	if (!bClientValid)
	{
		return;
	}

	if (!success || response == null)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] %s error: %s", szLabel, error);
		return;
	}

	char szResponse[MAX_HTTP_BATCH_RESPONSE_LENGTH];
	response.GetContent(szResponse, sizeof(szResponse));
	TrimString(szResponse);

	ReplyToCommand(iClient, "[STEAMIDTOOLS] %s KeyValue Response:\n%s", szLabel, szResponse);
}
