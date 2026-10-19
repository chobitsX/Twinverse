#!/bin/bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_version="$(cat "$project_root/.godot-version")"
template_version="${godot_version%%.official.*}"
template_dir="$HOME/Library/Application Support/Godot/export_templates/$template_version"

if [[ ! -f "$template_dir/version.txt" || ! -f "$template_dir/macos.zip" ]]; then
  echo "Matching macOS export template missing: $template_dir" >&2
  exit 1
fi
installed_template_version="$(tr -d '\r\n' < "$template_dir/version.txt")"
if [[ "$installed_template_version" != "$template_version" ]]; then
  echo "Template version mismatch: expected $template_version, got $installed_template_version." >&2
  exit 1
fi

python3 "$project_root/tools/sync_export_resources.py" --check
"$project_root/tools/godot.sh" --headless --script res://tools/check_reef_placements.gd

mkdir -p "$project_root/builds/macos"
touch "$project_root/builds/.gdignore"
exec "$project_root/tools/godot.sh" --headless --export-release "macOS M5" \
  "$project_root/builds/macos/3DWorld.app" "$@"
