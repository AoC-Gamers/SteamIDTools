#!/usr/bin/env python3
"""Compile the real stock include and execute it in SourcePawn's standalone VM."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import subprocess


ROOT = Path(__file__).resolve().parents[1]
SP_REVISION = "11b22edb634b9764d19fd28699e03289cfd18520"
AMBUILD_REVISION = "01212cb57c96561f664b6dfb2ee10e66de6f81e4"
SEED = 550


def run(arguments, **kwargs):
    return subprocess.run([str(value) for value in arguments], check=True, **kwargs)


def prepare_vm():
    deps = ROOT / "deps"
    deps.mkdir(exist_ok=True)
    for name, revision in (("sourcepawn", SP_REVISION), ("ambuild", AMBUILD_REVISION)):
        checkout = deps / name
        if not checkout.exists():
            run(["git", "init", checkout])
            run(["git", "-C", checkout, "remote", "add", "origin",
                 f"https://github.com/alliedmodders/{name}.git"])
            run(["git", "-C", checkout, "fetch", "--depth=1", "origin", revision])
            run(["git", "-C", checkout, "checkout", "--detach", "FETCH_HEAD"])
        actual = subprocess.check_output(
            ["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip()
        if actual != revision:
            raise SystemExit(f"Unexpected {name} revision: {actual}; expected {revision}")
    source = deps / "sourcepawn"
    run(["git", "submodule", "update", "--init", "--recursive", "--depth=1"], cwd=source)
    # This upstream revision has GCC 13 warnings. Keep them in the build log
    # without making them fatal, only for the standalone test tooling.
    for relative in ("AMBuildScript", "third_party/amtl/AMBuildScript"):
        path = source / relative
        contents = path.read_text()
        contents = contents.replace("'-Werror'", "'-Wno-error'")
        path.write_text(contents)
    shell = source / "vm/shell/shell.cpp"
    contents = shell.read_text()
    include = f'#include "{ROOT / "tests/sourcepawn/string-natives.h"}"'
    if include not in contents:
        contents = contents.replace("static int Execute(const char* file)",
                                    include + "\n\nstatic int Execute(const char* file)")
    if "  BindOfflineStringNatives(rt);" not in contents:
        binding = '  BindNative(rt, "add_test_structs", AddTestStructs);'
        contents = contents.replace(binding, binding + "\n  BindOfflineStringNatives(rt);")
    shell.write_text(contents)
    environment = dict(os.environ, PYTHONPATH=str(deps / "ambuild"))
    run(["python3", "configure.py", "--targets=x86_64", "--enable-optimize"],
        cwd=source, env=environment)
    with (deps / "sourcepawn-build.log").open("w") as log:
        run(["python3", "-c", "from ambuild2.run import cli_run; cli_run()",
             "objdir", "-j", "2"], cwd=source, env=environment,
            stdout=log, stderr=subprocess.STDOUT)


def generate_cases(directory):
    accounts = [1, 2, 9, 10, 22202, 66138017, 2147483646, 2147483647,
                2147483648, 2147483649, 4294967294, 4294967295]
    generator = random.Random(SEED)
    accounts += [generator.randrange(1, 2**32) for _ in range(2048)]
    # Python integers are arbitrary precision: this oracle does not reuse any
    # SourcePawn conversion algorithm or signed 32-bit arithmetic.
    lines = ["// Generated independent oracle; seed=550, random cases=2048.",
             "int g_Accounts[] = {",
             ",\n".join(f"0x{account:08X}" for account in accounts), "};"]
    for name, values in (
        ("g_SteamId64", [str(76561197960265728 + aid) for aid in accounts]),
        ("g_SteamId2", [f"STEAM_1:{aid & 1}:{aid // 2}" for aid in accounts]),
        ("g_SteamId3", [f"[U:1:{aid}]" for aid in accounts]),
    ):
        lines += [f"char {name}[][] = {{",
                  ",\n".join(json.dumps(value) for value in values), "};"]
    (directory / "stock_cases.inc").write_text("\n".join(lines) + "\n")
    return len(accounts)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepare-vm", action="store_true",
                        help="Fetch pinned upstream tools and build the Linux x86_64 VM")
    parser.add_argument("--server-plugin", action="store_true",
                        help="Build a server-command harness using real SourceMod natives; do not run the VM")
    parser.add_argument("--stock-include", type=Path,
                        default=ROOT / "sourcemod/scripting/include/steamidtools_stock.inc")
    options = parser.parse_args()
    if options.prepare_vm:
        prepare_vm()
    stock = options.stock_include.resolve()
    compiler = ROOT / "deps/sourcemod-linux/addons/sourcemod/scripting/spcomp"
    shells = list((ROOT / "deps/sourcepawn/objdir").glob("spshell/**/spshell"))
    if not compiler.is_file() or (not options.server_plugin and len(shells) != 1):
        raise SystemExit("Run make deps-smx, then this script with --prepare-vm")
    digest = hashlib.sha256(stock.read_bytes()).hexdigest()
    build = ROOT / ".build/stock-tests" / digest[:12]
    build.mkdir(parents=True, exist_ok=True)
    cases = generate_cases(build)
    binary = build / ("steamidtools_stock_test.smx" if options.server_plugin else "stock-test.smx")
    print(f"Include: {stock}\nSHA256: {digest}\nCases: {cases}; seed: {SEED}", flush=True)
    defines = ["STEAMIDTOOLS_TEST_SERVER=1"] if options.server_plugin else []
    run([compiler, *defines, ROOT / "tests/sourcepawn/steamidtools_stock_test.sp",
         f"-i{stock.parent}", f"-i{build}", f"-i{compiler.parent / 'include'}", f"-o{binary}"])
    if options.server_plugin:
        print(f"Server plugin: {binary}", flush=True)
        return 0
    failed = False
    for name, flags in (("JIT", []), ("Interpreter", ["--disable-jit"])):
        print(f"--- {name} ---", flush=True)
        environment = dict(os.environ)
        environment.pop("DISABLE_JIT", None)
        result = subprocess.run([str(shells[0]), *flags, str(binary)], env=environment)
        failed |= result.returncode != 0
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
