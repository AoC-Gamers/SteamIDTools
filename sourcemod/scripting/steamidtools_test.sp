#include <sourcemod>
#include <steamidtools>

#define ISGABENEWEL "76561197960287930"

StringMap g_hRequestClients;

enum SteamIDToolsRequestSource
{
	SteamIDToolsRequestSource_AccountID = 0,
	SteamIDToolsRequestSource_SteamID2,
	SteamIDToolsRequestSource_SteamID3,
	SteamIDToolsRequestSource_SteamID64
}

static const char g_szOnlineConversionEndpoints[][] =
{
	API_AIDtoSID64,
	API_SID2toSID64,
	API_SID3toSID64,
	API_SID64toAID,
	API_SID64toSID2,
	API_SID64toSID3
};

static const char g_szOnlineConversionLabels[][] =
{
	"AccountID -> SteamID64",
	"SteamID2 -> SteamID64",
	"SteamID3 -> SteamID64",
	"SteamID64 -> AccountID",
	"SteamID64 -> SteamID2",
	"SteamID64 -> SteamID3"
};

static const int g_iOnlineConversionSources[] =
{
	SteamIDToolsRequestSource_AccountID,
	SteamIDToolsRequestSource_SteamID2,
	SteamIDToolsRequestSource_SteamID3,
	SteamIDToolsRequestSource_SteamID64,
	SteamIDToolsRequestSource_SteamID64,
	SteamIDToolsRequestSource_SteamID64
};

public Plugin myinfo =
{
	name		= "SteamID Tools Test",
	author		= "lechuga",
	description = "Test plugin for the SteamIDTools API",
	version		= "2.2.1",
	url			= "https://github.com/AoC-Gamers/SteamIDTools"
};

/**
 * Creates the request tracking map and registers the demo commands.
 */
public void OnPluginStart()
{
	g_hRequestClients = new StringMap();

	RegConsoleCmd("sm_steamidtools", Command_Test, "Show available SteamID conversion methods");
	RegConsoleCmd("sm_steamidtools_batch", Command_Batch, "Test batch conversion with explicit extension argument");
}

/**
 * Converts a command argument into the provider enum used by the API plugin.
 */
bool TryParseProvider(const char[] szArg, SteamIDToolsProvider &provider)
{
	if (StrEqual(szArg, "steamworks", false))
	{
		provider = SteamIDToolsProvider_SteamWorks;
		return true;
	}

	if (StrEqual(szArg, "system2", false))
	{
		provider = SteamIDToolsProvider_System2;
		return true;
	}

	provider = SteamIDToolsProvider_Unknown;
	return false;
}

/**
 * Restricts the demo commands to real in-game clients.
 */
bool IsValidClient(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && !IsFakeClient(iClient));
}

/**
 * Returns a readable provider name for chat output.
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
 * Associates an async API request id with the client that initiated it.
 */
void TrackRequestClient(int iRequestId, int iClient)
{
	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));
	g_hRequestClients.SetValue(szRequestId, GetClientUserId(iClient));
}

/**
 * Resolves and removes the client associated with a finished async request.
 */
bool ResolveTrackedRequestClient(int iRequestId, int &iClient)
{
	char szRequestId[16];
	IntToString(iRequestId, szRequestId, sizeof(szRequestId));

	int iUserId = 0;
	if (!g_hRequestClients.GetValue(szRequestId, iUserId))
	{
		return false;
	}

	g_hRequestClients.Remove(szRequestId);
	iClient = GetClientOfUserId(iUserId);
	return IsValidClient(iClient);
}

/**
 * Queues an online request through the API plugin and stores its owner client.
 */
bool QueueRequestForClient(int iClient, SteamIDToolsProvider provider, const char[] szEndpoint, const char[] szInput, bool bBatch, const char[] szTag)
{
	int iRequestId = bBatch
		? SteamIDTools_RequestBatch(provider, szEndpoint, szInput, szTag)
		: SteamIDTools_RequestConversion(provider, szEndpoint, szInput, szTag);

	if (iRequestId <= 0)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] %s: Failed to queue request", szTag);
		return false;
	}

	TrackRequestClient(iRequestId, iClient);
	return true;
}

/**
 * Chooses the correct request input for each demo conversion endpoint.
 */
void GetOnlineRequestParam(int iSource, const char[] szAccountId, const char[] szSteamId2, const char[] szSteamId3, const char[] szSteamId64, char[] szBuffer, int iMaxLen)
{
	switch (iSource)
	{
		case SteamIDToolsRequestSource_AccountID:
		{
			strcopy(szBuffer, iMaxLen, szAccountId);
		}
		case SteamIDToolsRequestSource_SteamID2:
		{
			strcopy(szBuffer, iMaxLen, szSteamId2);
		}
		case SteamIDToolsRequestSource_SteamID3:
		{
			strcopy(szBuffer, iMaxLen, szSteamId3);
		}
		case SteamIDToolsRequestSource_SteamID64:
		{
			strcopy(szBuffer, iMaxLen, szSteamId64);
		}
		default:
		{
			szBuffer[0] = '\0';
		}
	}
}

/**
 * Runs the demo batch command against the API plugin.
 */
public Action Command_Batch(int iClient, int iArgs)
{
	if (!IsValidClient(iClient))
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] Invalid client");
		return Plugin_Handled;
	}

	if (!SteamIDTools_IsLibraryAvailable())
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] SteamIDTools API plugin not loaded");
		return Plugin_Handled;
	}

	if (iArgs < 1)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] Use: sm_steamidtools_batch <steamworks|system2>");
		return Plugin_Handled;
	}

	char szArg[32];
	GetCmdArg(1, szArg, sizeof(szArg));

	SteamIDToolsProvider provider;
	if (!TryParseProvider(szArg, provider))
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] Use: sm_steamidtools_batch <steamworks|system2>");
		return Plugin_Handled;
	}

	Batch_Online(provider, iClient);
	return Plugin_Handled;
}

/**
 * Runs the demo online or offline conversion command.
 */
public Action Command_Test(int iClient, int iArgs)
{
	if (!IsValidClient(iClient))
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] Invalid client");
		return Plugin_Handled;
	}

	if (iArgs < 1)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] Use: sm_steamidtools <offline|steamworks|system2>");
		return Plugin_Handled;
	}

	char szArg[32];
	GetCmdArg(1, szArg, sizeof(szArg));

	if (StrEqual(szArg, "offline", false))
	{
		SteamIDTools_OfflineConversions(iClient);
		return Plugin_Handled;
	}

	if (!SteamIDTools_IsLibraryAvailable())
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] SteamIDTools API plugin not loaded");
		return Plugin_Handled;
	}

	SteamIDToolsProvider provider;
	if (!TryParseProvider(szArg, provider))
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] Use: sm_steamidtools <offline|steamworks|system2>");
		return Plugin_Handled;
	}

	char szSteamId2[MAX_AUTHID_LENGTH], szSteamId3[MAX_AUTHID_LENGTH], szSteamId64[MAX_AUTHID_LENGTH];
	int iAccountId = GetClientAccountID(iClient);

	GetClientAuthId(iClient, AuthId_Steam2, szSteamId2, sizeof(szSteamId2));
	GetClientAuthId(iClient, AuthId_Steam3, szSteamId3, sizeof(szSteamId3));
	GetClientAuthId(iClient, AuthId_SteamID64, szSteamId64, sizeof(szSteamId64));

	OnlineConversions(provider, iClient, iAccountId, szSteamId2, szSteamId3, szSteamId64);
	return Plugin_Handled;
}

/**
 * Submits the demo single-conversion matrix through the selected provider.
 */
void OnlineConversions(SteamIDToolsProvider provider, int iClient, int iAccountId, const char[] szSteamId2, const char[] szSteamId3, const char[] szSteamId64)
{
	if (!SteamIDTools_IsProviderAvailable(provider))
	{
		char szProviderName[16];
		GetProviderName(provider, szProviderName, sizeof(szProviderName));
		ReplyToCommand(iClient, "[STEAMIDTOOLS] %s extension not found", szProviderName);
		return;
	}

	char szProviderName[16];
	char szAccountId[32];
	char szParam[MAX_AUTHID_LENGTH];

	GetProviderName(provider, szProviderName, sizeof(szProviderName));
	IntToString(iAccountId, szAccountId, sizeof(szAccountId));

	ReplyToCommand(iClient, "[STEAMIDTOOLS] Online Conversion (%s)", szProviderName);

	for (int i = 0; i < sizeof(g_szOnlineConversionEndpoints); i++)
	{
		GetOnlineRequestParam(g_iOnlineConversionSources[i], szAccountId, szSteamId2, szSteamId3, szSteamId64, szParam, sizeof(szParam));
		QueueRequestForClient(iClient, provider, g_szOnlineConversionEndpoints[i], szParam, false, g_szOnlineConversionLabels[i]);

		if (i == 2)
		{
			ReplyToCommand(iClient, "");
		}
	}
}

/**
 * Submits the demo batch request through the selected provider.
 */
void Batch_Online(SteamIDToolsProvider provider, int iClient)
{
	if (!SteamIDTools_IsProviderAvailable(provider))
	{
		char szProviderName[16];
		GetProviderName(provider, szProviderName, sizeof(szProviderName));
		ReplyToCommand(iClient, "[STEAMIDTOOLS] %s extension not found", szProviderName);
		return;
	}

	char szSteamId64[MAX_AUTHID_LENGTH];
	char szBatch[256];

	GetClientAuthId(iClient, AuthId_SteamID64, szSteamId64, sizeof(szSteamId64));
	Format(szBatch, sizeof(szBatch), "%s,%s", szSteamId64, ISGABENEWEL);
	QueueRequestForClient(iClient, provider, API_SID64toAID, szBatch, true, "Batch");
}

/**
 * Receives completions from the API plugin and prints them to the originating client.
 */
public void SteamIDTools_OnRequestFinished(int iRequestId, SteamIDToolsProvider provider, bool bSuccess, bool bBatch, const char[] szEndpoint, const char[] szInput, const char[] szResult, const char[] szTag)
{
	int iClient = 0;
	if (!ResolveTrackedRequestClient(iRequestId, iClient))
	{
		return;
	}

	char szDisplayTag[STEAMIDTOOLS_MAX_TAG_LENGTH];
	if (szTag[0] != '\0')
	{
		strcopy(szDisplayTag, sizeof(szDisplayTag), szTag);
	}
	else
	{
		strcopy(szDisplayTag, sizeof(szDisplayTag), szEndpoint);
	}

	if (bSuccess)
	{
		if (bBatch)
		{
			PrintToConsole(iClient, "[STEAMIDTOOLS] %s KeyValue Response:\n%s", szDisplayTag, szResult);
		}
		else
		{
			ReplyToCommand(iClient, "[STEAMIDTOOLS] %s: %s", szDisplayTag, szResult);
		}
		return;
	}

	ReplyToCommand(iClient, "[STEAMIDTOOLS] %s: %s", szDisplayTag, szResult);
}

/**
 * Demonstrates the offline conversions available directly from the include.
 */
void SteamIDTools_OfflineConversions(int iClient)
{
	char szSteamId2[MAX_AUTHID_LENGTH], szSteamId3[MAX_AUTHID_LENGTH], szSteamId64[MAX_AUTHID_LENGTH];
	int iAccountId = GetClientAccountID(iClient);

	GetClientAuthId(iClient, AuthId_Steam2, szSteamId2, sizeof(szSteamId2));
	GetClientAuthId(iClient, AuthId_Steam3, szSteamId3, sizeof(szSteamId3));
	GetClientAuthId(iClient, AuthId_SteamID64, szSteamId64, sizeof(szSteamId64));
	ReplyToCommand(iClient, "[STEAMIDTOOLS] Offline Conversion");

	char szConvertedSteamId2[MAX_AUTHID_LENGTH], szConvertedSteamId3[MAX_AUTHID_LENGTH], szAccountId[32];
	IntToString(iAccountId, szAccountId, sizeof(szAccountId));

	bool ok = AccountIDToSteamID2(iAccountId, szConvertedSteamId2, sizeof(szConvertedSteamId2));
	PrintConversionResult(iClient, "AccountID", szAccountId, szConvertedSteamId2, ok);

	ok = AccountIDToSteamID3(iAccountId, szConvertedSteamId3, sizeof(szConvertedSteamId3));
	PrintConversionResult(iClient, "AccountID", szAccountId, szConvertedSteamId3, ok);

	ReplyToCommand(iClient, "");

	int iConvertedAccountId = SteamID2ToAccountID(szSteamId2);
	IntToString(iConvertedAccountId, szAccountId, sizeof(szAccountId));
	PrintConversionResult(iClient, "SteamID2", szSteamId2, szAccountId, iConvertedAccountId > 0);

	ok = SteamID2ToSteamID3(szSteamId2, szConvertedSteamId3, sizeof(szConvertedSteamId3));
	PrintConversionResult(iClient, "SteamID2", szSteamId2, szConvertedSteamId3, ok);

	ReplyToCommand(iClient, "");

	iConvertedAccountId = SteamID3ToAccountID(szSteamId3);
	IntToString(iConvertedAccountId, szAccountId, sizeof(szAccountId));
	PrintConversionResult(iClient, "SteamID3", szSteamId3, szAccountId, iConvertedAccountId > 0);

	ok = SteamID3ToSteamID2(szSteamId3, szConvertedSteamId2, sizeof(szConvertedSteamId2));
	PrintConversionResult(iClient, "SteamID3", szSteamId3, szConvertedSteamId2, ok);

	ReplyToCommand(iClient, "");
}

/**
 * Prints one offline conversion result in a consistent chat format.
 */
void PrintConversionResult(int iClient, const char[] szLabel, const char[] szFrom, const char[] szTo, bool bSuccess)
{
	if (bSuccess)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] %s[%s] -> %s", szLabel, szFrom, szTo);
		return;
	}

	ReplyToCommand(iClient, "[STEAMIDTOOLS] %s[%s] -> [Conversion Failed]", szLabel, szFrom);
}
