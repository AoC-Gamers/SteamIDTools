#include <sourcemod>
#include <steamidtools>
#include <SteamWorks>
#include <system2>

#define ISGABENEWEL "76561197960287930"
#define MAX_API_BASE_URL_LENGTH 192
#define MAX_API_URL_LENGTH 1024
#define MAX_REQUEST_LABEL_LENGTH 64
#define MAX_HTTP_RESPONSE_LENGTH 256
#define MAX_HTTP_BATCH_RESPONSE_LENGTH 4096

ConVar g_hApiBaseUrl;

bool
    g_bLateLoad,
    g_bSteamWorksLoaded,
    g_bSystem2Loaded;

enum SteamIDToolsProvider
{
	SteamIDToolsProvider_Unknown = 0,
	SteamIDToolsProvider_SteamWorks,
	SteamIDToolsProvider_System2
}

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

static const char g_szHexChars[] = "0123456789ABCDEF";

void GetApiBaseUrl(char[] szBaseUrl, int iMaxLen)
{
	g_hApiBaseUrl.GetString(szBaseUrl, iMaxLen);
	TrimString(szBaseUrl);

	int iLen = strlen(szBaseUrl);
	if (iLen > 0 && szBaseUrl[iLen - 1] == '/')
	{
		szBaseUrl[iLen - 1] = '\0';
	}
}

bool IsUrlUnreservedChar(int iChar)
{
	return ((iChar >= 'A' && iChar <= 'Z')
		|| (iChar >= 'a' && iChar <= 'z')
		|| (iChar >= '0' && iChar <= '9')
		|| iChar == '-'
		|| iChar == '_'
		|| iChar == '.'
		|| iChar == '~');
}

void UrlEncodeComponent(const char[] szInput, char[] szOutput, int iMaxLen)
{
	int iPos = 0;

	for (int i = 0; szInput[i] != '\0' && iPos < iMaxLen - 1; i++)
	{
		int iChar = szInput[i] & 0xFF;
		if (IsUrlUnreservedChar(iChar))
		{
			szOutput[iPos++] = view_as<char>(iChar);
			continue;
		}

		if (iPos + 3 >= iMaxLen)
		{
			break;
		}

		szOutput[iPos++] = '%';
		szOutput[iPos++] = g_szHexChars[(iChar >> 4) & 0x0F];
		szOutput[iPos++] = g_szHexChars[iChar & 0x0F];
	}

	szOutput[iPos] = '\0';
}

void BuildSteamIDToolsUrl(const char[] szEndpoint, const char[] szParam, bool bNullTerm, char[] szUrl, int iMaxLen)
{
	char szBaseUrl[MAX_API_BASE_URL_LENGTH];
	char szEncodedParam[MAX_API_URL_LENGTH];

	GetApiBaseUrl(szBaseUrl, sizeof(szBaseUrl));
	UrlEncodeComponent(szParam, szEncodedParam, sizeof(szEncodedParam));
	Format(szUrl, iMaxLen, "%s%s?steamid=%s%s", szBaseUrl, szEndpoint, szEncodedParam, bNullTerm ? "&nullterm=1" : "");
}

Handle CreateRequestContext(int iClient, const char[] szLabel)
{
	Handle hPack = CreateDataPack();
	WritePackCell(hPack, GetClientUserId(iClient));
	WritePackString(hPack, szLabel);
	return hPack;
}

bool ReadRequestContext(Handle hPack, int &iClient, char[] szLabel, int iLabelLen)
{
	ResetPack(hPack);
	int iUserId = ReadPackCell(hPack);
	ReadPackString(hPack, szLabel, iLabelLen);

	iClient = GetClientOfUserId(iUserId);
	return IsValidClient(iClient);
}

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

bool IsProviderLoaded(SteamIDToolsProvider provider)
{
	switch (provider)
	{
		case SteamIDToolsProvider_SteamWorks:
		{
			return g_bSteamWorksLoaded;
		}
		case SteamIDToolsProvider_System2:
		{
			return g_bSystem2Loaded;
		}
	}

	return false;
}

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

void ReplyProviderUnavailable(int iClient, SteamIDToolsProvider provider)
{
	switch (provider)
	{
		case SteamIDToolsProvider_SteamWorks:
		{
			ReplyToCommand(iClient, "[STEAMIDTOOLS] SteamWorks extension not found");
		}
		case SteamIDToolsProvider_System2:
		{
			ReplyToCommand(iClient, "[STEAMIDTOOLS] system2 extension not found");
		}
	}
}

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

void SendProviderConversionRequest(SteamIDToolsProvider provider, const char[] szEndpoint, const char[] szParam, int iClient, const char[] szLabel)
{
	switch (provider)
	{
		case SteamIDToolsProvider_SteamWorks:
		{
			SendSteamWorksConversionRequest(szEndpoint, szParam, iClient, szLabel);
		}
		case SteamIDToolsProvider_System2:
		{
			SendSystem2ConversionRequest(szEndpoint, szParam, iClient, szLabel);
		}
	}
}

void SendProviderBatchRequest(SteamIDToolsProvider provider, const char[] szEndpoint, const char[] szBatch, int iClient, const char[] szLabel)
{
	switch (provider)
	{
		case SteamIDToolsProvider_SteamWorks:
		{
			SendSteamWorksBatchRequest(szEndpoint, szBatch, iClient, szLabel);
		}
		case SteamIDToolsProvider_System2:
		{
			SendSystem2BatchRequest(szEndpoint, szBatch, iClient, szLabel);
		}
	}
}

#include "steamidtools/steamidtools_steamworks.sp"
#include "steamidtools/steamidtools_system2.sp"

public Plugin myinfo =
{
	name		= "SteamID Tools",
	author		= "lechuga",
	description = "SteamIDTools plugin supporting SteamWorks and system2",
	version		= "2.1.0",
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
	g_hApiBaseUrl = CreateConVar("steamidtools_api_base_url", "http://localhost:80", "Base URL for SteamIDTools HTTP requests", FCVAR_NONE);

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

	SteamIDToolsProvider provider;
	if (TryParseProvider(szArg, provider))
	{
		Batch_Online(provider, iClient);
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

	SteamIDToolsProvider provider;
	if (TryParseProvider(szArg, provider))
	{
		OnlineConversions(provider, iClient, iAccountId, szSteamId2, szSteamId3, szSteamId64);
	}
	else
	{
		ReplyToCommand(iClient, "[STEAMIDTOOLS] Use: sm_steamidtools <offline|steamworks|system2>");
	}
	return Plugin_Handled;
}

void OnlineConversions(SteamIDToolsProvider provider, int iClient, int iAccountId, const char[] szSteamId2, const char[] szSteamId3, const char[] szSteamId64)
{
	if (!IsProviderLoaded(provider))
	{
		ReplyProviderUnavailable(iClient, provider);
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
		SendProviderConversionRequest(provider, g_szOnlineConversionEndpoints[i], szParam, iClient, g_szOnlineConversionLabels[i]);

		if (i == 2)
		{
			ReplyToCommand(iClient, "");
		}
	}
}

void Batch_Online(SteamIDToolsProvider provider, int iClient)
{
	if (!IsProviderLoaded(provider))
	{
		ReplyProviderUnavailable(iClient, provider);
		return;
	}

	char szSteamId64[MAX_AUTHID_LENGTH];
	char szBatch[256];

	GetClientAuthId(iClient, AuthId_SteamID64, szSteamId64, sizeof(szSteamId64));
	Format(szBatch, sizeof(szBatch), "%s,%s", szSteamId64, ISGABENEWEL);
	SendProviderBatchRequest(provider, API_SID64toAID, szBatch, iClient, "Batch");
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
