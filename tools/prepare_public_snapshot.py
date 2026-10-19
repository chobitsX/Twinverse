#!/usr/bin/env python3
"""Create a separate, reviewable source snapshot. Never publish or rewrite Git."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import platform
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
TEXT_RESOURCES = {".gd", ".gdshader", ".gdshaderinc", ".tscn", ".tres", ".cfg", ".import", ".json"}
ROOT_FILES = ["README.md", "README.zh-CN.md", "README.en.md", "CONTRIBUTING.md", "CODE_OF_CONDUCT.md",
              "SECURITY.md", "ROADMAP.md", "LICENSE", "LICENSING.md", "THIRD_PARTY_NOTICES.md",
              "project.godot", "export_presets.cfg", ".godot-version", ".gitattributes",
              "tests/tools/test_public_snapshot.py", "tests/tools/test_localization.py",
              "tests/core/test_app_language.gd", "tests/core/test_language_restart.gd",
              "tests/core/test_localized_content.gd", "tests/integration/i18n_smoke.gd",
              "tests/integration/i18n_visual.gd", "docs/LOCALIZATION.md", "localization/exclusions.json"]
TOOL_FILES = ["godot.sh", "export_macos.sh", "project_runtime_guard.py", "sync_export_resources.py",
              "check_reef_placements.gd", "asset_cost_report.py", "check_community.py", "check_localization.py",
              "prepare_public_snapshot.py", "public_snapshot.gitignore"]


def sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def resource_files(root: Path) -> set[str]:
    """Retain all scene/script/test entry points and their actual resource paths."""
    root = root.resolve()
    names = {str(p.relative_to(root)) for folder in ["scripts", "shaders", "scenes"]
             for p in (root / folder).rglob("*") if p.suffix in TEXT_RESOURCES | {".uid"}}
    names.update(["project.godot", "export_presets.cfg", "tools/check_reef_placements.gd", "tests/core/test_world_store.gd", "tests/core/test_reef_export_inputs.gd"])
    # Manifest-driven resources and import callbacks are first-class dependencies.
    for folder in ["assets/data", "data/environment"]:
        names.update(str(p.relative_to(root)) for p in (root / folder).rglob("*")
                     if p.is_file() and p.suffix in {".bin", ".json", ".res"})
    pending = list(names)
    while pending:
        name = pending.pop()
        path = root / name
        for suffix in [".import", ".uid"]:
            sidecar = name + suffix
            if (root / sidecar).is_file() and sidecar not in names:
                names.add(sidecar); pending.append(sidecar)
        if path.suffix not in TEXT_RESOURCES:
            continue
        for ref in re.findall(r"[\"']res://([^\"'\s]+)[\"']", path.read_text()):
            if ref.startswith(("docs/", ".local/")) or "%" in ref:
                continue
            if ref.startswith((".git/", "builds/")):
                raise ValueError("Private/generated resource reference: " + name)
            if ref.startswith(".godot/"):
                if path.suffix != ".import":
                    raise ValueError("Generated-cache reference outside import metadata: " + name)
                continue
            target = root / ref
            if Path(ref).is_absolute() or ".." in Path(ref).parts or not target.resolve().is_relative_to(root):
                raise ValueError("Resource reference escapes project: " + name)
            if target.is_file() and ref not in names:
                names.add(ref); pending.append(ref)
    return names


def manifest(root: Path) -> dict[str, str]:
    root = root.resolve()
    mapping = {name: name for name in resource_files(root)}
    mapping.update({name: name for name in ROOT_FILES})
    mapping.update({"tools/" + name: "tools/" + name for name in TOOL_FILES})
    for folder in [".github", "LICENSES", "docs/community", "docs/media", "assets/licenses"]:
        mapping.update({str(p.relative_to(root)): str(p.relative_to(root))
                        for p in (root / folder).rglob("*") if p.is_file() and p.name != ".DS_Store"})
    mapping["assets/LICENSE.md"] = "assets/LICENSE.md"
    # Keep nearby origin records without raw source TIFFs, downloads or logs.
    for p in (root / "assets/textures").rglob("*"):
        if p.name in {"SOURCES.json", "source.json", "earth_source.json", "cloud-source.json",
                      "moon-source.json", "cloud_shape_v1.source.json"}:
            mapping[str(p.relative_to(root))] = str(p.relative_to(root))
    mapping[".gitignore"] = "tools/public_snapshot.gitignore"
    return dict(sorted(mapping.items()))


def validate_mapping(root: Path, mapping: dict[str, str]) -> None:
    root = root.resolve()
    for target, source in mapping.items():
        path = root / source
        if Path(target).is_absolute() or ".." in Path(target).parts or Path(target).parts[0] in {".git", ".godot", ".local", "builds"}:
            raise ValueError("Unsafe destination: " + target)
        if not path.is_file() or path.is_symlink() or not path.resolve().is_relative_to(root):
            raise ValueError("Missing or unsafe source: " + source)
        if path.stat().st_size >= 100 * 1024 * 1024:
            raise ValueError("Over GitHub regular-file limit: " + source)
        if path.suffix in TEXT_RESOURCES | {".json", ".py", ".sh", ".md", ".txt", ".yml", ".yaml"}:
            text = path.read_text()
            if re.search(r'(?<![A-Za-z0-9._-])/(?:Users|home)/[^/\s"\']+/', text):
                raise ValueError("Personal absolute path needs review: " + source)
            if re.search(r'(?:sk-[A-Za-z0-9_-]{25,}|ghp_[A-Za-z0-9]{25,}|github_pat_[A-Za-z0-9_]{30,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)', text):
                raise ValueError("Credential-like text needs review: " + source)
    inventory = json.loads((root / "docs/community/ASSET_INVENTORY.json").read_text())
    licensed = {item["path"]: item for item in inventory["assets"]}
    for name in mapping:
        if name.startswith(("assets/models/", "assets/textures/", "assets/data/", "data/environment/")) and Path(name).suffix in {".glb", ".png", ".jpg", ".jpeg", ".webp", ".bin", ".res"}:
            if name not in licensed or licensed[name]["sha256"] != sha(root / mapping[name]):
                raise ValueError("Asset missing reviewed license/hash: " + name)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="New directory; existing directories are never overwritten")
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    mapping = manifest(ROOT)
    validate_mapping(ROOT, mapping)
    target = args.output.resolve() if args.output else None
    if target:
        if target.exists() or target == ROOT or target in ROOT.parents:
            raise ValueError("Output must be a new separate directory")
        target.mkdir(parents=True)
    records = []
    for destination, source in mapping.items():
        path = ROOT / source
        digest = sha(path)
        records.append({"path": destination, "source": source, "bytes": path.stat().st_size, "sha256": digest})
        if target:
            output = target / destination
            output.parent.mkdir(parents=True, exist_ok=True)
            cloned = False
            if platform.system() == "Darwin" and path.stat().st_size > 1048576:
                cloned = subprocess.run(["cp", "-c", str(path), str(output)], capture_output=True).returncode == 0
            if not cloned:
                shutil.copy2(path, output)
            if sha(output) != digest:
                raise RuntimeError("Copied content mismatch: " + destination)
    report = {"status": "copied" if target else "manifest_only", "files": records,
              "file_count": len(records), "bytes": sum(r["bytes"] for r in records),
              "git_history_included": False, "local_assets_deleted": False, "published": False,
              "limitations": "Selected current text and asset hashes checked; not a full historical/binary security audit or a legal warranty."}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k != "files"}, ensure_ascii=False))


if __name__ == "__main__":
    main()
