# SPDX-License-Identifier: GPL-3.0-or-later

"""Inspect compiled dependency metadata and execute the public facade in the VM."""
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
DEPS_DIR = ROOT / ".deps"
TEST_DIR = ROOT / ".build"


def section_image(path):
    raw = path.read_bytes()
    _, _, compressed, _, _, count, strings, dataoff = struct.unpack_from('<IHBIIBII', raw)
    image = raw[:dataoff] + zlib.decompress(raw[dataoff:]) if compressed else raw
    def string(pos):
        return image[pos:image.index(b'\0', pos)].decode()
    sections = {}
    for i in range(count):
        name, offset, size = struct.unpack_from('<III', image, 24+i*12)
        sections[string(strings+name)] = (offset, size)
    return image, sections, string


class PublicInclude(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        TEST_DIR.mkdir(exist_ok=True)

    def assert_offline_imports(self, binary):
        image, sections, string = section_image(binary)
        names = sections['.names'][0]
        for section in ('.pubvars', '.natives'):
            offset, size = sections[section]
            stride = 4 if section == '.natives' else 8
            for pos in range(offset, offset+size, stride):
                name = struct.unpack_from('<I', image, pos+(4 if section == '.pubvars' else 0))[0]
                symbol = string(names+name)
                self.assertNotIn('steamidtools', symbol.lower())
                self.assertNotIn('steamworks', symbol.lower())
                self.assertNotIn('system2', symbol.lower())

    def test_public_facade_executes_without_http(self):
        with tempfile.TemporaryDirectory(dir=TEST_DIR) as tmp:
            source = Path(tmp)/'facade.sp'
            binary = Path(tmp)/'facade.smx'
            source.write_text('''#include <steamidtools>
public int main() {
    int account;
    char steam[32];
    if (!SteamIDTools_TryParseAccountID("4294967295", account)) return 1;
    if (!SteamIDTools_AccountIDToSteamID64(account, steam, sizeof(steam))) return 2;
    if (!StrEqual(steam, "76561202255233023")) return 3;
    if (!SteamIDTools_SteamID64ToAccountID(steam, account) || account != -1) return 4;
    if (SteamIDTools_SteamID64ToAccountID("76561202255233024", account)) return 5;
    if (SteamIDTools_TryParseAccountID("0", account)) return 6;
    return 0;
}
''')
            compiler = DEPS_DIR / "sourcemod-linux/addons/sourcemod/scripting/spcomp64"
            subprocess.run([str(compiler), str(source), '-i'+str(ROOT/'addons/sourcemod/scripting/include'), '-i'+str(compiler.parent/'include'), '-o'+str(binary)], check=True, capture_output=True)
            self.assert_offline_imports(binary)
            shell, = (DEPS_DIR / "sourcepawn/objdir").glob('spshell/**/spshell')
            for flags in ([], ['--disable-jit']):
                subprocess.run([str(shell), *flags, str(binary)], check=True)
