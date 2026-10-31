#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <steamidtools>
#include <steamidtools_helpers>

public Plugin myinfo =
{
    name = "SteamIDTools Offline Example",
    author = "lechuga",
    description = "Convert Steam identities locally",
    version = STEAMIDTOOLS_VERSION,
    url = "https://github.com/AoC-Gamers/SteamIDTools"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_steamidtools_convert", Command_Convert, "sm_steamidtools_convert <identity>");
}

public Action Command_Convert(int client, int args)
{
    char input[MAX_AUTHID_LENGTH];
    int nextArg;
    if (!SteamIDTools_TryGetIdentityFromCmdArgs(1, args, input, sizeof(input), nextArg) || nextArg <= args)
    {
        ReplyToCommand(client, "sm_steamidtools_convert <identity>");
        return Plugin_Handled;
    }
    int accountId;
    switch (DetectSteamIDFormat(input))
    {
        case STEAMID_FORMAT_ACCOUNTID: SteamIDTools_TryParseAccountID(input, accountId);
        case STEAMID_FORMAT_STEAMID2: accountId = SteamID2ToAccountID(input);
        case STEAMID_FORMAT_STEAMID3: accountId = SteamID3ToAccountID(input);
        case STEAMID_FORMAT_STEAMID64: SteamIDTools_SteamID64ToAccountID(input, accountId);
    }
    char account[ACCOUNTID_LENGTH], sid2[MAX_AUTHID_LENGTH], sid3[MAX_AUTHID_LENGTH], sid64[MAX_AUTHID_LENGTH];
    if (accountId == 0 || !SteamIDTools_FormatAccountID(accountId, account, sizeof(account))
        || !AccountIDToSteamID2(accountId, sid2, sizeof(sid2))
        || !AccountIDToSteamID3(accountId, sid3, sizeof(sid3))
        || !SteamIDTools_AccountIDToSteamID64(accountId, sid64, sizeof(sid64)))
    {
        ReplyToCommand(client, "Invalid Steam identity");
        return Plugin_Handled;
    }
    ReplyToCommand(client, "AccountID=%s SteamID2=%s SteamID3=%s SteamID64=%s", account, sid2, sid3, sid64);
    return Plugin_Handled;
}
