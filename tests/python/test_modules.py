"""Execute the productive modules in SourcePawn with modeled engine/console inputs."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Modules(unittest.TestCase):
    def run_vm(self, source):
        (ROOT/'tmp').mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT/'tmp') as tmp:
            sp, smx = Path(tmp)/'module.sp', Path(tmp)/'module.smx'
            sp.write_text(source)
            compiler = ROOT/'deps/sourcemod-linux/addons/sourcemod/scripting/spcomp'
            result = subprocess.run([str(compiler), str(sp), '-i'+str(ROOT/'addons/sourcemod/scripting/include'), '-i'+str(compiler.parent/'include'), '-o'+str(smx)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
            shell, = (ROOT/'deps/sourcepawn/objdir').glob('spshell/**/spshell')
            for flags in ([], ['--disable-jit']):
                result = subprocess.run([str(shell), *flags, str(smx)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout+result.stderr)

    def test_clients_preserve_uint32_invalid_and_not_found_returns(self):
        self.run_vm(r'''
#include <steamidtools>
#define MaxClients 3
#define IsClientInGame TestIsClientInGame
#define GetSteamAccountID TestGetSteamAccountID
#include <steamidtools/clients>
#include <steamidtools/clients>
#undef MaxClients
#undef IsClientInGame
#undef GetSteamAccountID
stock bool TestIsClientInGame(int client) { return client == 1 || client == 3; }
stock int TestGetSteamAccountID(int client) { return client == 1 ? -1 : 48030081; }
public int main() {
    if (GetClientAccountID(0) != 0 || GetClientAccountID(4) != 0 || GetClientAccountID(2) != 0) return 1;
    if (GetClientAccountID(1) != -1 || GetClientAccountID(3) != 48030081) return 2;
    if (FindClientByAccountID(0) != 0 || FindClientByAccountID(-1) != 1 || FindClientByAccountID(99) != -1) return 3;
    if (FindClientBySteamID2("STEAM_1:1:2147483647") != 1 || FindClientBySteamID3("[U:1:4294967295]") != 1) return 4;
    if (FindClientBySteamID2("invalid") != 0 || FindClientBySteamID3("[U:1:99]") != -1) return 5;
    if (!IsValidClientIndex(2) || IsValidClientIndex(-1) || IsValidClientIndex(4)) return 6;
    return 0;
}
''')

    def test_commands_keep_normalization_consumption_and_fallback(self):
        self.run_vm(r'''
#include <steamidtools>
#define GetCmdArg TestGetCmdArg
#define TrimString TestTrimString
#define StripQuotes TestStripQuotes
#include <steamidtools/commands>
#include <steamidtools/commands>
#undef GetCmdArg
#undef TrimString
#undef StripQuotes
char g_Args[8][128];
stock int TestGetCmdArg(int index, char[] output, int maxlen) { return strcopy(output, maxlen, g_Args[index]); }
stock int TestTrimString(char[] value) {
    int start, end = strlen(value);
    while (value[start] == ' ' || value[start] == '\t') start++;
    while (end > start && (value[end-1] == ' ' || value[end-1] == '\t')) end--;
    value[end] = '\0';
    return strcopy(value, end-start+1, value[start]);
}
stock bool TestStripQuotes(char[] value) {
    int len = strlen(value);
    if (len < 2 || value[0] != '"' || value[len-1] != '"') return false;
    value[len-1] = '\0'; strcopy(value, len, value[1]); return true;
}
public int main() {
    char output[128]; int next;
    strcopy(g_Args[1], 128, "  \"alpha\"  "); strcopy(g_Args[2], 128, " beta ");
    if (!SteamIDTools_GetCmdArgNormalized(1, 2, output, sizeof(output)) || !StrEqual(output, "alpha")) return 1;
    if (SteamIDTools_GetCmdArgNormalized(0, 2, output, sizeof(output)) || output[0]) return 2;
    SteamIDTools_JoinCmdArgs(1, 2, output, sizeof(output), "|");
    if (!StrEqual(output, "alpha|beta")) return 3;
    if (!SteamIDTools_IsNumericString("0009") || SteamIDTools_IsNumericString("") || SteamIDTools_IsNumericString("-1")) return 4;
    strcopy(g_Args[1], 128, "STEAM_1"); strcopy(g_Args[2], 128, ":"); strcopy(g_Args[3], 128, "1");
    strcopy(g_Args[4], 128, ":"); strcopy(g_Args[5], 128, "24015040");
    if (!SteamIDTools_TryGetIdentityFromCmdArgs(1, 6, output, sizeof(output), next) || next != 6 || !StrEqual(output, "STEAM_1:1:24015040")) return 5;
    if (SteamIDTools_TryGetIdentityFromCmdArgs(1, 6, output, sizeof(output), next, 3) || next != 2 || !StrEqual(output, "STEAM_1")) return 6;
    strcopy(g_Args[1], 128, "BOT");
    if (SteamIDTools_TryGetIdentityFromCmdArgs(1, 1, output, sizeof(output), next) || next != 2 || !StrEqual(output, "BOT")) return 7;
    if (SteamIDTools_TryGetIdentityFromCmdArgs(0, 1, output, sizeof(output), next) || next != 1 || output[0]) return 8;
    return 0;
}
''')
