#!/usr/bin/env python3
"""Prepare the declared offline includes; no compiler or runtime plugin is needed."""
import argparse
import json
import shutil
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--output-root", default=".build/smx")
    parser.add_argument("--build-log", required=True)
    args = parser.parse_args()
    root = Path(args.root).resolve()
    output = (root / args.output_root).resolve()
    log = (root / args.build_log).resolve()
    manifest = json.loads((root / "plugin-package-map.json").read_text())
    names = manifest["artifact"]["addons"]["sourcemod"]["scripting"]["include"]["files"]
    source = root / "addons/sourcemod/scripting/include"
    # Validate all inputs before replacing a previous generated build.
    if not names or len(set(names)) != len(names):
        raise ValueError("The toolkit requires a nonempty, unique include list")
    for name in names:
        if Path(name).is_absolute() or ".." in Path(name).parts or not name.endswith(".inc"):
            raise ValueError(f"Invalid include name: {name}")
        if not (source / name).is_file():
            raise FileNotFoundError(source / name)
    if output == root or source.is_relative_to(output):
        raise ValueError("Build output cannot replace source directories")
    if output.exists():
        shutil.rmtree(output)
    target = output / "addons/sourcemod/scripting/include"
    target.mkdir(parents=True)
    for name in names:
        (target / name).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / name, target / name)
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text("Offline includes prepared (no production SMX).\n" + "\n".join(names) + "\n")
    print(f"Prepared {len(names)} includes in {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
