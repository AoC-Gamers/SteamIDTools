#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${SOURCEMOD_ARTIFACT_DIR:-$ROOT_DIR/dist/sourcemod/artifact}"
python3 - "$ROOT_DIR" "$ARTIFACT_DIR" <<'CHECK'
import json
import sys
from pathlib import Path

root, artifact = map(Path, sys.argv[1:])
manifest = json.loads((root / "plugin-package-map.json").read_text())
names = manifest["artifact"]["addons"]["sourcemod"]["scripting"]["include"]["files"]
expected = {Path("addons/sourcemod/scripting/include") / name for name in names}
actual = {p.relative_to(artifact) for p in (artifact / "addons").rglob("*") if p.is_file()}
if actual != expected:
    raise SystemExit(f"Unexpected/missing toolkit files: {actual ^ expected}")
for relative in expected:
    if (root / relative).read_bytes() != (artifact / relative).read_bytes():
        raise SystemExit(f"Packaged include differs from source: {relative}")
for relative in ("README.md", "plugin-package-map.json", "docs/index.md", "CHANGELOG.md", "build.log"):
    if not (artifact / relative).is_file():
        raise SystemExit(f"Missing packaged project asset: {relative}")
for name in ("plugins", "extensions"):
    if (artifact / "addons/sourcemod" / name).exists():
        raise SystemExit(f"Forbidden artifact directory: {name}")
print("ARTIFACT_VALIDATION_OK")
CHECK
