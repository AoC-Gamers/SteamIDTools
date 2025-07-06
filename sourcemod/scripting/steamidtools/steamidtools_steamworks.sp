/**
 * Performs various online SteamID conversions using the SteamWorks extension.
 *
 * This function checks if the SteamWorks extension is loaded, and if so,
 * initiates multiple SteamID conversion requests for the provided client and SteamID formats.
 * It sends conversion requests for AccountID, SteamID2, SteamID3, and SteamID64 formats,
 * and replies to the client with the results.
 *
 * @param iClient      The client index to reply to.
 * @param iAccountId   The numeric AccountID to convert.
 * @param szSteamId2   The SteamID2 string to convert.
 * @param szSteamId3   The SteamID3 string to convert.
 * @param szSteamId64  The SteamID64 string to convert.
 */
void OnlineConversions_SteamWorks(int iClient, int iAccountId, const char[] szSteamId2, const char[] szSteamId3, const char[] szSteamId64)
{
	if (!g_bSteamWorksLoaded)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] SteamWorks extension not found");
		return;
	}
	ReplyToCommand(iClient, "[STEAMIDTOOLS] Online Conversion (SteamWorks)");
	char szAccountId[32];
	IntToString(iAccountId, szAccountId, sizeof(szAccountId));
	RequestSteamIDConversion(API_AIDtoSID64, szAccountId, iClient, "AccountID -> SteamID64");
	RequestSteamIDConversion(API_SID2toSID64, szSteamId2, iClient, "SteamID2 -> SteamID64");
	RequestSteamIDConversion(API_SID3toSID64, szSteamId3, iClient, "SteamID3 -> SteamID64");
	ReplyToCommand(iClient, "");
	RequestSteamIDConversion(API_SID64toAID, szSteamId64, iClient, "SteamID64 -> AccountID");
	RequestSteamIDConversion(API_SID64toSID2, szSteamId64, iClient, "SteamID64 -> SteamID2");
	RequestSteamIDConversion(API_SID64toSID3, szSteamId64, iClient, "SteamID64 -> SteamID3");
}

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
void RequestSteamIDConversion(const char[] szEndpoint, const char[] szParam, int iClient, const char[] szLabel)
{
    char szUrl[256];
    char szBaseUrl[192];
    g_hApiBaseUrl.GetString(szBaseUrl, sizeof(szBaseUrl));
    Format(szUrl, sizeof(szUrl), "%s%s?steamid=%s&nullterm=1", szBaseUrl, szEndpoint, szParam);
    Handle hPack = CreateDataPack();
    WritePackCell(hPack, iClient);
    WritePackString(hPack, szLabel);
    Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, szUrl);
    if (hRequest == INVALID_HANDLE)
    {
        CloseHandle(hPack);
        ReplyToCommand(iClient, "[STEAMIDTOOLS] %s: Error creando HTTP request", szLabel);
        return;
    }
    SteamWorks_SetHTTPRequestContextValue(hRequest, hPack);
    SteamWorks_SetHTTPCallbacks(hRequest, OnSteamIDConversionResponse);
    SteamWorks_SendHTTPRequest(hRequest);
}

public void OnSteamIDConversionResponse(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data1)
{
    Handle hPack = view_as<Handle>(data1);
    ResetPack(hPack);
    int iClient = ReadPackCell(hPack);
    char szLabel[64];
    ReadPackString(hPack, szLabel, sizeof(szLabel));
    delete hPack;
    int bodySize = 0;
    if (bFailure || !bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
    {
        ReplyToCommand(iClient, "[STEAMIDTOOLS] %s: Error en conversión online", szLabel);
        return;
    }
    if (SteamWorks_GetHTTPResponseBodySize(hRequest, bodySize) && bodySize > 0)
    {
        char[] szResponse = new char[bodySize + 1];
        for (int i = 0; i <= bodySize; i++) szResponse[i] = '\0';
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
        ReplyToCommand(iClient, "[STEAMIDTOOLS] %s: Respuesta vacía", szLabel);
    }
}

/**
 * Performs a batch test for SteamID conversion using the SteamWorks extension.
 *
 * This function checks if the SteamWorks extension is loaded. If not, it notifies the client.
 * Otherwise, it retrieves the client's SteamID64, formats a batch string with the SteamID64 and
 * a predefined constant (ISGABENEWEL), and requests a batch conversion from SteamID64 to another
 * authentication ID format via the SteamIDTools API.
 *
 * @param iClient The client index to perform the batch test for.
 */
void Batch_SteamWorks(int iClient)
{
	if (!g_bSteamWorksLoaded)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] SteamWorks extension not found");
		return;
	}

	char szSteamId64[MAX_AUTHID_LENGTH];
	GetClientAuthId(iClient, AuthId_SteamID64, szSteamId64, sizeof(szSteamId64));
	char szBatch[256];
	Format(szBatch, sizeof(szBatch), "%s,%s", szSteamId64, ISGABENEWEL);
	RequestSteamIDBatchConversion(API_SID64toAID, szBatch, iClient);
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
void RequestSteamIDBatchConversion(const char[] szEndpoint, const char[] szBatch, int iClient)
{
	char szUrl[256];
	char szBaseUrl[192];
	g_hApiBaseUrl.GetString(szBaseUrl, sizeof(szBaseUrl));
	Format(szUrl, sizeof(szUrl), "%s%s?steamid=%s&nullterm=1", szBaseUrl, szEndpoint, szBatch);
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, szUrl);
	if (hRequest == INVALID_HANDLE)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] Batch: Error creating HTTP request");
		return;
	}
	SteamWorks_SetHTTPRequestContextValue(hRequest, iClient);
	SteamWorks_SetHTTPCallbacks(hRequest, OnSteamIDBatchResponse);
	SteamWorks_SendHTTPRequest(hRequest);
}

public void OnSteamIDBatchResponse(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data1)
{
	int iClient	 = data1;
	int bodySize = 0;
	if (bFailure || !bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] Batch: Error in online batch conversion");
		return;
	}
	if (SteamWorks_GetHTTPResponseBodySize(hRequest, bodySize) && bodySize > 0)
	{
		char[] szResponse = new char[bodySize + 1];
		for (int i = 0; i <= bodySize; i++)
			szResponse[i] = '\0';
		SteamWorks_GetHTTPResponseBodyData(hRequest, szResponse, bodySize);
		szResponse[bodySize] = '\0';
		PrintToConsole(iClient, "[STEAMIDTOOLS] Batch KeyValue Response:\n%s", szResponse);
	}
	else
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] Batch: Empty response");
	}
}