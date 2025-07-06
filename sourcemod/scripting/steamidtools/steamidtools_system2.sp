int	 g_iLabelId = 0;

/**
 * Performs various online SteamID conversions using the system2 extension.
 *
 * This function checks if the system2 extension is loaded, then sends a series of
 * conversion requests for the provided SteamID formats (AccountID, SteamID2, SteamID3, SteamID64).
 * The results are sent back to the client via command replies.
 *
 * @param iClient      The client index to reply to.
 * @param iAccountId   The numeric AccountID to convert.
 * @param szSteamId2   The SteamID2 string to convert (e.g., "STEAM_0:X:XXXXXX").
 * @param szSteamId3   The SteamID3 string to convert (e.g., "[U:1:XXXXXX]").
 * @param szSteamId64  The SteamID64 string to convert (e.g., "7656119XXXXXXXXXX").
 */
void OnlineConversions_System2(int iClient, int iAccountId, const char[] szSteamId2, const char[] szSteamId3, const char[] szSteamId64)
{
	if (!g_bSystem2Loaded)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] system2 extension not found");
		return;
	}

	char szAccountId[32];
	ReplyToCommand(iClient, "[STEAMIDTOOLS] Online Conversion (system2)");
	IntToString(iAccountId, szAccountId, sizeof(szAccountId));

	RequestSteamIDConversionSystem2("/AIDtoSID64", szAccountId, iClient, "AccountID -> SteamID64");
	RequestSteamIDConversionSystem2("/SID2toSID64", szSteamId2, iClient, "SteamID2 -> SteamID64");
	RequestSteamIDConversionSystem2("/SID3toSID64", szSteamId3, iClient, "SteamID3 -> SteamID64");
	ReplyToCommand(iClient, "");
	RequestSteamIDConversionSystem2("/SID64toAID", szSteamId64, iClient, "SteamID64 -> AccountID");
	RequestSteamIDConversionSystem2("/SID64toSID2", szSteamId64, iClient, "SteamID64 -> SteamID2");
	RequestSteamIDConversionSystem2("/SID64toSID3", szSteamId64, iClient, "SteamID64 -> SteamID3");
}

/**
 * Sends an HTTP GET request to convert a SteamID using the System2 extension.
 *
 * Constructs the request URL using the provided endpoint and parameter, logs the request,
 * stores the label in a trie for later reference, and packs client and label information
 * for use in the callback. The request is sent asynchronously.
 *
 * @param szEndpoint   The API endpoint to append to the base URL.
 * @param szParam      The SteamID or parameter to include in the request.
 * @param iClient      The client index associated with this request.
 * @param szLabel      A label to identify this request, stored for callback reference.
 */
void RequestSteamIDConversionSystem2(const char[] szEndpoint, const char[] szParam, int iClient, const char[] szLabel)
{
	char szUrl[256];
	char szBaseUrl[192];
	g_hApiBaseUrl.GetString(szBaseUrl, sizeof(szBaseUrl));
	Format(szUrl, sizeof(szUrl), "%s%s?steamid=%s", szBaseUrl, szEndpoint, szParam);

	LogMessage("[STEAMIDTOOLS] [system2] Sending request: %s (Label: %s)", szUrl, szLabel);

	int	 labelId = ++g_iLabelId;
	char szKey[32];
	IntToString(labelId, szKey, sizeof(szKey));
	SetTrieString(g_hTrieLabel, szKey, szLabel);

	Handle hPack = CreateDataPack();
	WritePackCell(hPack, iClient);
	WritePackCell(hPack, labelId);

	System2HTTPRequest req = new System2HTTPRequest(System2_Callback, szUrl);
	req.Any				   = hPack;
	req.GET();
}

public void System2_Callback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	Handle hPack = view_as<Handle>(request.Any);
	ResetPack(hPack);
	int iClient = ReadPackCell(hPack);
	int labelId = ReadPackCell(hPack);
	CloseHandle(hPack);

	char szLabel[64];
	char szKey[32];
	IntToString(labelId, szKey, sizeof(szKey));
	if (!GetTrieString(g_hTrieLabel, szKey, szLabel, sizeof(szLabel)))
		strcopy(szLabel, sizeof(szLabel), "Conversion");

	RemoveFromTrie(g_hTrieLabel, szKey);

	if (!success || response == null)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] %s: Error: %s", szLabel, error);
		return;
	}

	char szResponse[128];
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
 * Performs a batch test for SteamID conversion using the system2 extension.
 *
 * This function checks if the system2 extension is loaded. If not, it notifies the client.
 * Otherwise, it retrieves the client's SteamID64, formats a batch string with the SteamID64
 * and a predefined constant (ISGABENEWEL), and sends a batch conversion request.
 *
 * @param iClient The client index to perform the batch test for.
 */
void Batch_System2(int iClient)
{
	if (!g_bSystem2Loaded)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] system2 extension not found");
		return;
	}
	char szSteamId64[MAX_AUTHID_LENGTH];
	GetClientAuthId(iClient, AuthId_SteamID64, szSteamId64, sizeof(szSteamId64));
	char szBatch[256];
	Format(szBatch, sizeof(szBatch), "%s,%s", szSteamId64, ISGABENEWEL);
	RequestSteamIDBatchConversionSystem2("/SID64toAID", szBatch, iClient);
}

/**
 * Sends a batch SteamID conversion request using the System2 HTTP library.
 *
 * Constructs a URL using the provided endpoint and batch of SteamIDs, then sends a GET request.
 * The client index is packed and passed along for use in the callback.
 *
 * @param szEndpoint   The API endpoint to append to the base URL.
 * @param szBatch      A string containing the batch of SteamIDs to convert.
 * @param iClient      The client index associated with this request.
 */
void RequestSteamIDBatchConversionSystem2(const char[] szEndpoint, const char[] szBatch, int iClient)
{
	char szUrl[256];
	char szBaseUrl[192];
	g_hApiBaseUrl.GetString(szBaseUrl, sizeof(szBaseUrl));
	Format(szUrl, sizeof(szUrl), "%s%s?steamid=%s", szBaseUrl, szEndpoint, szBatch);

	Handle hPack = CreateDataPack();
	WritePackCell(hPack, iClient);

	System2HTTPRequest req = new System2HTTPRequest(System2_BatchCallback, szUrl);
	req.Any				   = hPack;
	req.GET();
}

public void System2_BatchCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	Handle hPack = view_as<Handle>(request.Any);
	ResetPack(hPack);
	int iClient = ReadPackCell(hPack);
	CloseHandle(hPack);

	if (!success || response == null)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] Batch error: %s", error);
		return;
	}

	char szResponse[512];
	response.GetContent(szResponse, sizeof(szResponse));
	TrimString(szResponse);

	ReplyToCommand(iClient, "[STEAMIDTOOLS] Batch KeyValue Response:\n%s", szResponse);
}