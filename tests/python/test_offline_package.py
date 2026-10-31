"""Inspect compiled dependency metadata and execute the public facade in the VM."""
from pathlib import Path
import struct
import os
import shutil
import re
import subprocess
import tempfile
import unittest
import zlib
import zipfile

ROOT = Path(__file__).resolve().parents[2]


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


class OfflinePackage(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        (ROOT/'tmp').mkdir(exist_ok=True)

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
        with tempfile.TemporaryDirectory(dir=ROOT/'tmp') as tmp:
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
            compiler = ROOT/'deps/sourcemod-linux/addons/sourcemod/scripting/spcomp'
            subprocess.run([str(compiler), str(source), '-i'+str(ROOT/'addons/sourcemod/scripting/include'), '-i'+str(compiler.parent/'include'), '-o'+str(binary)], check=True, capture_output=True)
            self.assert_offline_imports(binary)
            shell, = (ROOT/'deps/sourcepawn/objdir').glob('spshell/**/spshell')
            for flags in ([], ['--disable-jit']):
                subprocess.run([str(shell), *flags, str(binary)], check=True)

    def test_artifact_is_include_only(self):
        artifact = ROOT/'dist/sourcemod/artifact'
        subprocess.run(['bash', str(ROOT/'scripts/ci-validate-artifact.sh')], cwd=ROOT, check=True, capture_output=True)
        files = {p.relative_to(artifact).as_posix() for p in (artifact/'addons').rglob('*') if p.is_file()}
        self.assertEqual(files, {'addons/sourcemod/scripting/include/'+name for name in ('steamidtools.inc', 'steamidtools/clients.inc', 'steamidtools/commands.inc')})

    def test_version_resolver(self):
        script = ROOT/'scripts/ci-resolve-release.sh'
        self.assertEqual(subprocess.run(['bash', str(script), 'sourcemod/v4.0.0'], capture_output=True).returncode, 0)
        for tag in ('backend/v2.0.0', 'sourcemod/v3.0.0', 'invalid'):
            self.assertNotEqual(subprocess.run(['bash', str(script), tag], capture_output=True).returncode, 0)

    def test_release_zip_and_document_links(self):
        artifact = ROOT/'dist/sourcemod/artifact'
        # Validate the actual zip when running the package gate after release-smx.
        archive_path = ROOT/'dist/release/steamidtools-sourcemod-local.zip'
        if archive_path.exists():
            with zipfile.ZipFile(archive_path) as archive:
                files = {n for n in archive.namelist() if n.startswith('addons/') and not n.endswith('/')}
                self.assertEqual(files, {'addons/sourcemod/scripting/include/'+name for name in ('steamidtools.inc', 'steamidtools/clients.inc', 'steamidtools/commands.inc')})
        for path in artifact.rglob('*.md'):
            for target in re.findall(r'\]\(([^)]+)\)', path.read_text()):
                if '://' in target or target.startswith('#'):
                    continue
                self.assertTrue((path.parent/target.split('#')[0]).exists(), f'{path}: {target}')

    def test_build_only_needs_manifest_and_includes(self):
        with tempfile.TemporaryDirectory(dir=ROOT/'tmp') as tmp:
            lab = Path(tmp)
            shutil.copy2(ROOT/'plugin-package-map.json', lab/'plugin-package-map.json')
            shutil.copytree(ROOT/'addons', lab/'addons')
            command = ['python3', str(ROOT/'scripts/build-local.py'), '--root', str(lab), '--build-log', 'tmp/build.log']
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
            self.assertFalse((lab/'deps').exists())
            self.assertEqual(len(list((lab/'.build/smx').rglob('*.inc'))), 3)
            # A missing source must fail before replacing the previous valid output.
            (lab/'addons/sourcemod/scripting/include/steamidtools.inc').unlink()
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertTrue((lab/'.build/smx/addons/sourcemod/scripting/include/steamidtools.inc').exists())

    def test_validator_rejects_stale_plugins_and_modified_includes(self):
        with tempfile.TemporaryDirectory(dir=ROOT/'tmp') as tmp:
            lab = Path(tmp)/'artifact'
            shutil.copytree(ROOT/'dist/sourcemod/artifact', lab)
            env = dict(os.environ, SOURCEMOD_ARTIFACT_DIR=str(lab))
            command = ['bash', str(ROOT/'scripts/ci-validate-artifact.sh')]
            stale = lab/'addons/sourcemod/plugins/old.smx'
            stale.parent.mkdir()
            stale.write_bytes(b'old plugin')
            self.assertNotEqual(subprocess.run(command, env=env, capture_output=True).returncode, 0)
            shutil.rmtree(stale.parent)
            target = lab/'addons/sourcemod/scripting/include/steamidtools.inc'
            target.write_text('/* modified include */')
            self.assertNotEqual(subprocess.run(command, env=env, capture_output=True).returncode, 0)
