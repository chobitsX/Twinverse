#!/bin/bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
expected_version="$(cat "$project_root/.godot-version")"

if [[ ! -x "$godot_bin" ]]; then
  echo "Godot executable not found: $godot_bin. Set GODOT_BIN to the pinned editor." >&2
  exit 1
fi
exec python3 "$project_root/tools/project_runtime_guard.py" "$godot_bin" "$expected_version" "$@"
