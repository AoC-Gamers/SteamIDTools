#include <sourcemod>
#include <steamidtools>
#include <SteamWorks>
#include <system2>

#define ISGABENEWEL "76561197960287930"

ConVar	  g_hApiBaseUrl;
StringMap g_hTrieLabel;

bool
    g_bLateLoad,
    g_bSteamWorksLoaded,
    g_bSystem2Loaded;

#include "steamidtools/steamidtools_steamworks.sp"
#include "steamidtools/steamidtools_system2.sp"

public Plugin myinfo =
{
	name		= "SteamID Tools",
	author		= "lechuga",
	description = "SteamIDTools plugin supporting SteamWorks and system2",
	version		= "2.0.0",
	url			= "https://github.com/AoC-Gamers/SteamIDTools"
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErr_max)
{
	g_bLateLoad = bLate;
	return APLRes_Success;
}


public void OnAllPluginsLoaded()
{
	g_bSteamWorksLoaded = LibraryExists("SteamWorks");
	g_bSystem2Loaded	= LibraryExists("system2");
}

public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, "SteamWorks"))
		g_bSteamWorksLoaded = false;
	else if (StrEqual(sName, "system2"))
		g_bSystem2Loaded = false;
}

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "SteamWorks"))
		g_bSteamWorksLoaded = true;
	else if (StrEqual(sName, "system2"))
		g_bSystem2Loaded = true;
}

public void OnPluginStart()
{
	if (g_hTrieLabel == null)
		g_hTrieLabel = CreateTrie();

	g_hApiBaseUrl = CreateConVar("steamidtools_api_base_url", "http://localhost:81", "Base URL for SteamIDTools HTTP requests", FCVAR_NONE);

	RegConsoleCmd("sm_steamidtools", Command_Test, "Show available SteamID conversion methods");
	RegConsoleCmd("sm_steamidtools_batch", Command_Batch, "Test batch conversion with explicit extension argument");

    if (!g_bLateLoad)
        return;
    
	g_bSteamWorksLoaded = LibraryExists("SteamWorks");
	g_bSystem2Loaded	= LibraryExists("system2");
}

public Action Command_Batch(int iClient, int iArgs)
{
	if (!IsValidClient(iClient))
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] Invalid client");
		return Plugin_Handled;
	}

	if (iArgs < 1 || iArgs == 0)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] Use: sm_steamidtools_batch <steamworks|system2>");
		return Plugin_Handled;
	}

	char szArg[32] = "";
	GetCmdArg(1, szArg, sizeof(szArg));

	if (StrEqual(szArg, "steamworks", false))
	{
		Batch_SteamWorks(iClient);
	}
	else if (StrEqual(szArg, "system2", false))
	{
		Batch_System2(iClient);
	}
	else
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] Use: sm_steamidtools_batch <steamworks|system2>");
	}
	return Plugin_Handled;
}

public Action Command_Test(int iClient, int iArgs)
{
	if (!IsValidClient(iClient))
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] Invalid client");
		return Plugin_Handled;
	}

	if (iArgs < 1 || iArgs == 0)
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] Use: sm_steamidtools <offline|steamworks|system2>");
		return Plugin_Handled;
	}

	char szArg[32] = "";
	GetCmdArg(1, szArg, sizeof(szArg));

	if (StrEqual(szArg, "offline", false))
	{
		SteamIDTools_OfflineConversions(iClient);
		return Plugin_Handled;
	}

	char
		szSteamId2[MAX_AUTHID_LENGTH],
		szSteamId3[MAX_AUTHID_LENGTH],
		szSteamId64[MAX_AUTHID_LENGTH];
	int iAccountId = GetClientAccountID(iClient);

	GetClientAuthId(iClient, AuthId_Steam2, szSteamId2, sizeof(szSteamId2));
	GetClientAuthId(iClient, AuthId_Steam3, szSteamId3, sizeof(szSteamId3));
	GetClientAuthId(iClient, AuthId_SteamID64, szSteamId64, sizeof(szSteamId64));

	if (StrEqual(szArg, "steamworks", false))
	{
		OnlineConversions_SteamWorks(iClient, iAccountId, szSteamId2, szSteamId3, szSteamId64);
	}
	else if (StrEqual(szArg, "system2", false))
	{
		OnlineConversions_System2(iClient, iAccountId, szSteamId2, szSteamId3, szSteamId64);
	}
	else
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] Use: sm_steamidtools <offline|steamworks|system2>");
	}
	return Plugin_Handled;
}

/**
 * Performs various offline SteamID conversions for a given client and outputs the results.
 *
 * This function retrieves the client's Steam2, Steam3, and SteamID64 identifiers,
 * then performs conversions between AccountID, SteamID2, and SteamID3 formats.
 * The results of each conversion (or failure) are sent to the client via ReplyToCommand.
 *
 * @param iClient The client index to perform conversions for.
 *
 * Output:
 * - AccountID to SteamID2 and SteamID3 conversions.
 * - SteamID2 to AccountID and SteamID3 conversions.
 * - SteamID3 to AccountID and SteamID2 conversions.
 * - Each conversion result is reported to the client.
 */
void SteamIDTools_OfflineConversions(int iClient)
{
	char szSteamId2[MAX_AUTHID_LENGTH], szSteamId3[MAX_AUTHID_LENGTH], szSteamId64[MAX_AUTHID_LENGTH];
	int	 iAccountId = GetClientAccountID(iClient);

	GetClientAuthId(iClient, AuthId_Steam2, szSteamId2, sizeof(szSteamId2));
	GetClientAuthId(iClient, AuthId_Steam3, szSteamId3, sizeof(szSteamId3));
	GetClientAuthId(iClient, AuthId_SteamID64, szSteamId64, sizeof(szSteamId64));
	ReplyToCommand(iClient, "[STEAMIDTOOLS] Offline Conversion");

	char
		szConvertedSteamId2[MAX_AUTHID_LENGTH],
		szConvertedSteamId3[MAX_AUTHID_LENGTH],
		szAccountId[32];
	IntToString(iAccountId, szAccountId, sizeof(szAccountId));

	// AccountID -> SteamID2
	bool ok = AccountIDToSteamID2(iAccountId, szConvertedSteamId2, sizeof(szConvertedSteamId2));
	PrintConversionResult(iClient, "AccountID", szAccountId, szConvertedSteamId2, ok);

	// AccountID -> SteamID3
	ok = AccountIDToSteamID3(iAccountId, szConvertedSteamId3, sizeof(szConvertedSteamId3));
	PrintConversionResult(iClient, "AccountID", szAccountId, szConvertedSteamId3, ok);

	ReplyToCommand(iClient, "");

	// SteamID2 -> AccountID
	int iConvertedAccountId = SteamID2ToAccountID(szSteamId2);
	IntToString(iConvertedAccountId, szAccountId, sizeof(szAccountId));
	PrintConversionResult(iClient, "SteamID2", szSteamId2, szAccountId, iConvertedAccountId > 0);

	// SteamID2 -> SteamID3
	ok = SteamID2ToSteamID3(szSteamId2, szConvertedSteamId3, sizeof(szConvertedSteamId3));
	PrintConversionResult(iClient, "SteamID2", szSteamId2, szConvertedSteamId3, ok);

	ReplyToCommand(iClient, "");

	// SteamID3 -> AccountID
	iConvertedAccountId = SteamID3ToAccountID(szSteamId3);
	IntToString(iConvertedAccountId, szAccountId, sizeof(szAccountId));
	PrintConversionResult(iClient, "SteamID3", szSteamId3, szAccountId, iConvertedAccountId > 0);

	// SteamID3 -> SteamID2
	ok = SteamID3ToSteamID2(szSteamId3, szConvertedSteamId2, sizeof(szConvertedSteamId2));
	PrintConversionResult(iClient, "SteamID3", szSteamId3, szConvertedSteamId2, ok);

	ReplyToCommand(iClient, "");
}

/**
 * Prints the result of a SteamID conversion to the specified client.
 *
 * @param iClient   The client index to send the message to.
 * @param label     A label describing the type of conversion.
 * @param from      The original value before conversion.
 * @param to        The converted value (ignored if conversion failed).
 * @param success   True if the conversion was successful, false otherwise.
 */
void PrintConversionResult(int iClient, const char[] label, const char[] from, const char[] to, bool success)
{
	if (success)
		ReplyToCommand(iClient, "[STEAMIDTOOLS] %s[%s] -> %s", label, from, to);
	else
		ReplyToCommand(iClient, "[STEAMIDTOOLS] %s[%s] -> [Conversion Failed]", label, from);
}

/**
 * Checks if the given client index represents a valid, connected, and real player.
 *
 * @param iClient      The client index to validate.
 * @return             True if the client index is valid, the client is in-game, and not a fake client (bot); false otherwise.
 */
bool IsValidClient(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && !IsFakeClient(iClient));
}