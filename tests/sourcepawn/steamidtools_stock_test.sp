#pragma semicolon 1
#pragma newdecls required

#include <steamidtools_stock>
#include <stock_cases>

int g_Checks;
int g_Failures;
int g_PrintedFailures;
int g_FailedTo64;
#if defined ACCOUNTID_UINT32_MAX_STRING
int g_FailedFrom64;
#endif

#if defined STEAMIDTOOLS_TEST_SERVER
#define printf TestPrint

public Plugin myinfo =
{
	name = "SteamIDTools Stock Test",
	author = "lechuga",
	description = "Tests offline stocks against an independent conversion corpus",
	version = STEAMIDTOOLS_VERSION
};

bool g_Running;
int g_NextCase;
float g_StartedAt;
char g_LogPath[PLATFORM_MAX_PATH];

void TestPrint(const char[] format, any ...)
{
	char message[512];
	VFormat(message, sizeof(message), format, 2);
	TrimString(message);
	PrintToServer("[SteamIDToolsStockTest] %s", message);
	LogToFileEx(g_LogPath, "%s", message);
}

public void OnPluginStart()
{
	BuildPath(Path_SM, g_LogPath, sizeof(g_LogPath), "logs/steamidtools_stock_test.log");
	RegServerCmd("sm_steamidtools_stock_test", Command_RunTests,
		"Run the offline stock regression suite using SourceMod natives");
	RegServerCmd("sm_steamidtools_stock_convert", Command_ConvertAccountID,
		"Convert one unsigned decimal AccountID using the offline stocks");
}

public Action Command_ConvertAccountID(int args)
{
	if (args != 1)
	{
		PrintToServer("Usage: sm_steamidtools_stock_convert <AccountID>");
		return Plugin_Handled;
	}
	char input[32];
	GetCmdArg(1, input, sizeof(input));
	int accountId;
	if (!SteamIDTools_TryParseAccountID(input, accountId))
	{
		PrintToServer("[SteamIDToolsStockTest] Invalid AccountID: expected 1..4294967295");
		return Plugin_Handled;
	}
	char account[16], steamId64[32], steamId2[32], steamId3[32];
	bool success = SteamIDTools_FormatAccountID(accountId, account, sizeof(account))
		&& SteamIDTools_AccountIDToSteamID64(accountId, steamId64, sizeof(steamId64))
		&& AccountIDToSteamID2(accountId, steamId2, sizeof(steamId2))
		&& AccountIDToSteamID3(accountId, steamId3, sizeof(steamId3));
	int inverse;
	bool roundtrip = success && SteamIDTools_SteamID64ToAccountID(steamId64, inverse)
		&& inverse == accountId && SteamID2ToAccountID(steamId2) == accountId
		&& SteamID3ToAccountID(steamId3) == accountId;
	printf("CONVERT AccountID=%s SteamID64=%s SteamID2=%s SteamID3=%s success=%d roundtrip=%d",
		account, steamId64, steamId2, steamId3, success, roundtrip);
	return Plugin_Handled;
}

public Action Command_RunTests(int args)
{
	if (g_Running)
	{
		PrintToServer("[SteamIDToolsStockTest] A run is already in progress");
		return Plugin_Handled;
	}
	ResetStockTests();
	g_Running = true;
	g_NextCase = 0;
	g_StartedAt = GetEngineTime();
	printf("BEGIN version=%s cases=%d", STEAMIDTOOLS_VERSION, sizeof(g_Accounts));
	if (!CheckHostPrimitives())
	{
		printf("RESULT checks=%d failed=%d", g_Checks, g_Failures);
		g_Running = false;
		return Plugin_Handled;
	}
	RequestFrame(RunConversionBatch);
	return Plugin_Handled;
}

public void RunConversionBatch(any data)
{
	CheckConversions(g_NextCase, 64);
	g_NextCase += 64;
	if (g_NextCase < sizeof(g_Accounts))
	{
		RequestFrame(RunConversionBatch);
		return;
	}
	FinishStockTests();
	printf("END elapsed=%.3f seconds", GetEngineTime() - g_StartedAt);
	g_Running = false;
}
#else
// Supplied by AlliedModders' standalone SourcePawn shell.
native void printf(const char[] format, any ...);
#endif

void ResetStockTests()
{
	g_Checks = 0;
	g_Failures = 0;
	g_PrintedFailures = 0;
	g_FailedTo64 = 0;
#if defined ACCOUNTID_UINT32_MAX_STRING
	g_FailedFrom64 = 0;
#endif
}

void Check(bool passed, const char[] operation, int index = -1)
{
	g_Checks++;
	if (passed)
		return;
	g_Failures++;
	if (g_PrintedFailures++ < 30)
		printf("FAIL %s case=%d\n", operation, index);
}

void CheckConversions(int start = 0, int count = sizeof(g_Accounts))
{
	char output[64];
	int end = start + count;
	if (end > sizeof(g_Accounts))
		end = sizeof(g_Accounts);
	for (int i = start; i < end; i++)
	{
		int accountId = g_Accounts[i];
		output[0] = '\0';
		bool success = SteamIDTools_AccountIDToSteamID64(accountId, output, sizeof(output));
		if (i < 12)
		{
			char account[16];
			Format(account, sizeof(account), "%u", accountId);
			printf("CASE AccountID=%s SteamID64=%s success=%d expected=%s\n",
				account, output, success, g_SteamId64[i]);
		}
		Check(success && StrEqual(output, g_SteamId64[i]), "AccountID -> SteamID64", i);
		if (!success || !StrEqual(output, g_SteamId64[i]))
			g_FailedTo64++;
		output[0] = '\0';
		success = AccountIDToSteamID2(accountId, output, sizeof(output));
		Check(success && StrEqual(output, g_SteamId2[i]), "AccountID -> SteamID2", i);
		output[0] = '\0';
		success = AccountIDToSteamID3(accountId, output, sizeof(output));
		Check(success && StrEqual(output, g_SteamId3[i]), "AccountID -> SteamID3", i);
		Check(SteamID2ToAccountID(g_SteamId2[i]) == accountId, "SteamID2 -> AccountID", i);
		Check(SteamID3ToAccountID(g_SteamId3[i]) == accountId, "SteamID3 -> AccountID", i);
		output[0] = '\0';
		success = SteamID2ToSteamID3(g_SteamId2[i], output, sizeof(output));
		Check(success && StrEqual(output, g_SteamId3[i]), "SteamID2 -> SteamID3", i);
		output[0] = '\0';
		success = SteamID3ToSteamID2(g_SteamId3[i], output, sizeof(output));
		Check(success && StrEqual(output, g_SteamId2[i]), "SteamID3 -> SteamID2", i);
		Check(IsValidSteamID64(g_SteamId64[i]), "valid SteamID64", i);
		Check(IsValidSteamID2(g_SteamId2[i]), "valid SteamID2", i);
		Check(IsValidSteamID3(g_SteamId3[i]), "valid SteamID3", i);
		char decimal[16];
		Format(decimal, sizeof(decimal), "%u", accountId);
		Check(DetectSteamIDFormat(decimal) == STEAMID_FORMAT_ACCOUNTID, "detect AccountID", i);
#if defined ACCOUNTID_UINT32_MAX_STRING
		int inverse;
		success = SteamIDTools_SteamID64ToAccountID(g_SteamId64[i], inverse);
		Check(success && inverse == accountId, "SteamID64 -> AccountID", i);
		if (!success || inverse != accountId)
			g_FailedFrom64++;
		Check(SteamIDTools_TryParseAccountID(decimal, inverse) && inverse == accountId,
			"parse uint32 AccountID", i);
#endif
	}
	if (end != sizeof(g_Accounts))
		return;
	printf("ACCOUNTID_TO_STEAMID64 cases=%d failed=%d\n", sizeof(g_Accounts), g_FailedTo64);
#if defined ACCOUNTID_UINT32_MAX_STRING
	printf("STEAMID64_TO_ACCOUNTID cases=%d failed=%d\n", sizeof(g_Accounts), g_FailedFrom64);
#endif
}

void CheckInvalidInputs()
{
	static const char invalid2[][] = {
		"", "STEAM_1:2:1", "STEAM_1:0:abc",
		"STEAM_1:1:2147483648", "STEAM_1:1:12junk", "STEAM_2:1:123",
		"STEAM_1:1:12:3", "STEAM_1:-1:123", "STEAM_1:01:123",
		"STEAM_1:1:0000000000000000000000000000001junk"
	};
	static const char invalid3[][] = {
		"", "[U:1:0]", "[U:1:abc]", "[U:1:4294967296]",
		"[U:1:123junk]", "[U:2:123]", "[U:1:-123]", "[U:1:123]:junk",
		"[U:1:]", "[U:1:+1]", "[U:1: 1]", "[U:1:1 ]",
		"[U:1:0000000000000000000000000000001junk]"
	};
	static const char invalid64[][] = {
		"", "76561197960265728", "76561202255233024",
		"7656119796026572", "765611979602657290", "7656119796026572x"
	};
	for (int i = 0; i < sizeof(invalid2); i++)
	{
		Check(!IsValidSteamID2(invalid2[i]), "reject invalid SteamID2", i);
		Check(SteamID2ToAccountID(invalid2[i]) == 0, "reject invalid SteamID2 conversion", i);
	}
	for (int i = 0; i < sizeof(invalid3); i++)
	{
		Check(!IsValidSteamID3(invalid3[i]), "reject invalid SteamID3", i);
		Check(SteamID3ToAccountID(invalid3[i]) == 0, "reject invalid SteamID3 conversion", i);
	}
	for (int i = 0; i < sizeof(invalid64); i++)
	{
		Check(!IsValidSteamID64(invalid64[i]), "reject invalid SteamID64", i);
#if defined ACCOUNTID_UINT32_MAX_STRING
		int inverse = 123;
		Check(!SteamIDTools_SteamID64ToAccountID(invalid64[i], inverse),
			"reject invalid SteamID64 conversion", i);
#endif
	}
	char output[32];
	Check(!SteamIDTools_AccountIDToSteamID64(0, output, sizeof(output)), "reject zero AccountID");
	Check(!AccountIDToSteamID2(0, output, sizeof(output)), "reject zero AccountID -> SteamID2");
	Check(!AccountIDToSteamID3(0, output, sizeof(output)), "reject zero AccountID -> SteamID3");
}

void CheckBuffers()
{
	static const int capacities[] = {0, 1, 2, 16, 17, 18, 32};
	char output[64];
	for (int i = 0; i < sizeof(capacities); i++)
	{
		int capacity = capacities[i];
		for (int position = 0; position < sizeof(output); position++)
			output[position] = '~';
		bool success = SteamIDTools_AccountIDToSteamID64(1, output, capacity);
		Check(success == (capacity >= 18), "SteamID64 buffer return", capacity);
		Check(output[capacity] == '~', "SteamID64 buffer sentinel", capacity);
		if (success)
			Check(StrEqual(output, "76561197960265729"), "SteamID64 buffer content", capacity);
	}
}

#if defined ACCOUNTID_UINT32_MAX_STRING
void CheckUInt32Helpers()
{
	static const char invalid[][] = {
		"", "-1", "+1", " 1", "1 ", "1x", "4294967296", "9999999999",
		"0000004294967296", "00000000000000001"
	};
	for (int i = 0; i < sizeof(invalid); i++)
	{
		int parsed = 123;
		Check(!SteamIDTools_TryParseUInt32(invalid[i], parsed) && parsed == 0,
			"reject invalid uint32 and clear output", i);
		parsed = 123;
		Check(!SteamIDTools_TryParseAccountID(invalid[i], parsed) && parsed == 0,
			"reject invalid AccountID and clear output", i);
		Check(DetectSteamIDFormat(invalid[i]) == STEAMID_FORMAT_UNKNOWN,
			"reject invalid detected AccountID", i);
	}
	int parsed;
	Check(SteamIDTools_TryParseUInt32("0", parsed) && parsed == 0, "parse uint32 zero");
	Check(!SteamIDTools_TryParseAccountID("0", parsed), "reject AccountID zero");
	Check(SteamIDTools_TryParseAccountID("0000004294967295", parsed) && parsed == -1,
		"parse leading zero uint32 maximum");
	Check(SteamIDTools_TryParseAccountID("0000000000000001", parsed) && parsed == 1,
		"parse leading zero AccountID one");
	for (int i = 1; i <= 9; i++)
	{
		char steamId3[16];
		Format(steamId3, sizeof(steamId3), "[U:1:%d]", i);
		Check(IsValidSteamID3(steamId3) && SteamID3ToAccountID(steamId3) == i,
			"one digit SteamID3", i);
	}
	Check(SteamID2ToAccountID("steam_0:1:0000000000000001") == 3,
		"SteamID2 universe zero and leading zeroes");
	Check(SteamID3ToAccountID("[u:1:0000000000000001]") == 1,
		"SteamID3 leading zeroes and case compatibility");
	Check(SteamID2ToAccountID("STEAM_1:1:2147483647") == -1,
		"SteamID2 maximum AccountID");
	char result[64];
	Check(SteamIDTools_AddDecimalStrings("99999999999999999", "1", result, sizeof(result))
		&& StrEqual(result, "100000000000000000"), "decimal carry");
	Check(SteamIDTools_AddDecimalStringInt("76561197960265728", 2147483647,
		result, sizeof(result)) && StrEqual(result, "76561200107749375"), "legacy decimal addition");
	Check(SteamIDTools_AddDecimalStringInt("123", 0, result, sizeof(result))
		&& StrEqual(result, "123"), "legacy decimal addition zero");
	Check(!SteamIDTools_AddDecimalStringInt("123", -1, result, sizeof(result)),
		"reject negative signed addend");
	Check(!SteamIDTools_AddDecimalStrings("", "1", result, sizeof(result)), "reject empty decimal");
	Check(!SteamIDTools_AddDecimalStrings("1x", "1", result, sizeof(result)), "reject invalid base");
	Check(!SteamIDTools_AddDecimalStrings("1", "-1", result, sizeof(result)), "reject invalid addend");
	Check(!SteamIDTools_AddDecimalStrings("999", "1", result, 4), "reject short sum buffer");
	for (int identity = 0; identity < 2; identity++)
	{
		int accountId = identity == 0 ? 1 : -1;
		for (int operation = 0; operation < 4; operation++)
		{
			char expected[32];
			switch (operation)
			{
				case 0: SteamIDTools_AccountIDToSteamID64(accountId, expected, sizeof(expected));
				case 1: AccountIDToSteamID2(accountId, expected, sizeof(expected));
				case 2: AccountIDToSteamID3(accountId, expected, sizeof(expected));
				case 3: SteamIDTools_FormatAccountID(accountId, expected, sizeof(expected));
			}
			for (int capacity = 0; capacity <= strlen(expected) + 1; capacity++)
			{
				for (int i = 0; i < sizeof(result); i++)
					result[i] = '~';
				bool success;
				switch (operation)
				{
					case 0: success = SteamIDTools_AccountIDToSteamID64(accountId, result, capacity);
					case 1: success = AccountIDToSteamID2(accountId, result, capacity);
					case 2: success = AccountIDToSteamID3(accountId, result, capacity);
					case 3: success = SteamIDTools_FormatAccountID(accountId, result, capacity);
				}
				Check(success == (capacity > strlen(expected)), "conversion buffer capacity", operation);
				bool unchanged = true;
				for (int i = success ? capacity : 0; i < sizeof(result); i++)
					unchanged = unchanged && result[i] == '~';
				Check(unchanged, "buffer guard or unchanged failure", operation);
				if (success)
					Check(StrEqual(result, expected), "exact buffer result", operation);
			}
		}
	}
}
#endif

bool CheckHostPrimitives()
{
	// Validate the test host's primitives before exercising the include.
	char probe[64];
	Format(probe, sizeof(probe), "%s:%d:%u", "test", -1, -1);
	Check(StrEqual(probe, "test:-1:4294967295"), "host format");
	Check(StringToInt("123") == 123 && StringToInt("-123") == -123, "host parsing");
	Check(StringToInt("4294967295") == -1 && StringToInt("4294967296") == -1,
		"host Linux 32-bit unsigned long overflow");
	Check(StrContains("AbCd", "bc", false) == 1, "host substring");
	return g_Failures == 0;
}

int FinishStockTests()
{
	printf("CONVERSIONS checks=%d failed=%d\n", g_Checks, g_Failures);
	int priorFailures = g_Failures;
	g_PrintedFailures = 0;
	CheckInvalidInputs();
	printf("INVALID_INPUTS failed=%d\n", g_Failures - priorFailures);
	priorFailures = g_Failures;
	g_PrintedFailures = 0;
	CheckBuffers();
	printf("BUFFERS failed=%d\n", g_Failures - priorFailures);
#if defined ACCOUNTID_UINT32_MAX_STRING
	priorFailures = g_Failures;
	g_PrintedFailures = 0;
	CheckUInt32Helpers();
	printf("UINT32_HELPERS failed=%d\n", g_Failures - priorFailures);
#endif
	printf("RESULT checks=%d failed=%d\n", g_Checks, g_Failures);
	return g_Failures == 0 ? 0 : 1;
}

#if !defined STEAMIDTOOLS_TEST_SERVER
public int main()
{
	ResetStockTests();
	if (!CheckHostPrimitives())
		return 1;
	CheckConversions();
	return FinishStockTests();
}
#endif
