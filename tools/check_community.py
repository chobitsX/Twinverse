#!/usr/bin/env python3
"""Offline checks for the public entry points, issue forms and reviewed asset hashes."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    errors = []
    required = ["AGENTS.md", "CLAUDE.md", "README.md", "README.zh-CN.md", "README.en.md", "CONTRIBUTING.md", "CODE_OF_CONDUCT.md", "SECURITY.md",
                "ROADMAP.md", "LICENSE", "LICENSING.md", "THIRD_PARTY_NOTICES.md",
                "LICENSES/CC-BY-4.0.txt", "LICENSES/GODOT-MIT.txt", "LICENSES/GODOT-NOTICES.txt", "docs/community/ASSET_INVENTORY.json"]
    for name in required:
        if not (ROOT / name).is_file():
            errors.append("Missing required file: " + name)
    claude = ROOT / 'CLAUDE.md'
    if claude.is_file() and not re.search(r'^@AGENTS\.md\s*$', claude.read_text(), re.M):
        errors.append('CLAUDE.md must import the shared AGENTS.md instructions')
    documents = [ROOT / n for n in required if n.endswith(".md")]
    documents += list((ROOT / "docs/community").rglob("*.md"))
    links = 0
    for path in documents:
        if not path.is_file():
            continue
        text = path.read_text()
        for link in re.findall(r'\]\(([^\s)]+)', text):
            if "://" in link or link.startswith(("#", "mailto:")):
                continue
            target = (path.parent / link.split("#")[0]).resolve()
            links += 1
            if not target.is_relative_to(ROOT) or not target.exists():
                errors.append(f"Broken local link in {path.relative_to(ROOT)}: {link}")
        if re.search(r'(?<![A-Za-z0-9._-])/(?:Users|home)/[^/\s"\']+/', text):
            errors.append("Personal path in public documentation: " + str(path.relative_to(ROOT)))
    forms = 0
    for path in (ROOT / ".github/ISSUE_TEMPLATE").glob("*.yml"):
        if path.name == "config.yml":
            continue
        try:
            form = json.loads(path.read_text())  # JSON is valid YAML, with no extra parser dependency.
            assert form.get("name") and form.get("description") and isinstance(form.get("body"), list)
            ids = set()
            for item in form["body"]:
                assert item["type"] in ["markdown", "input", "textarea", "dropdown", "checkboxes"]
                if item["type"] == "markdown":
                    assert item["attributes"]["value"]
                    continue
                assert item["id"] not in ids and re.fullmatch(r"[a-z0-9_-]+", item["id"])
                ids.add(item["id"])
                assert item["attributes"]["label"]
                if item["type"] == "dropdown":
                    assert item["attributes"]["options"]
            forms += 1
        except (AssertionError, KeyError, ValueError) as exc:
            errors.append("Invalid issue form: " + str(path.relative_to(ROOT)) + " " + str(exc))
    inventory_path = ROOT / "docs/community/ASSET_INVENTORY.json"
    asset_bytes = 0
    asset_count = 0
    if inventory_path.exists():
        inventory = json.loads(inventory_path.read_text())
        seen = set()
        for item in inventory["assets"]:
            name = item["path"]
            path = ROOT / name
            if name in seen or not path.is_file() or not path.resolve().is_relative_to(ROOT):
                errors.append("Missing/duplicate/unsafe asset: " + name)
                continue
            seen.add(name)
            if not item.get("license") or not item.get("credit"):
                errors.append("Missing asset license/credit: " + name)
            with path.open("rb") as stream:
                digest = hashlib.file_digest(stream, "sha256").hexdigest()
            if digest != item["sha256"] or path.stat().st_size != item["bytes"]:
                errors.append("Asset changed; review provenance and update hash: " + name)
            asset_bytes += path.stat().st_size
            asset_count += 1
        version = re.search(r'config/version="([^"]+)"', (ROOT / "project.godot").read_text())[1]
        if inventory["application_version"] != version:
            errors.append("Asset inventory application version needs review")
    workflow = (ROOT / ".github/workflows/community.yml").read_text()
    if "contents: read" not in workflow or "persist-credentials: false" not in workflow or "pull_request_target" in workflow:
        errors.append("Community workflow permissions changed; review before publication")
    if not re.search(r"actions/checkout@[0-9a-f]{40}\b", workflow):
        errors.append("Checkout action must use a verified commit SHA")
    print(json.dumps({"status": "failed" if errors else "passed", "local_links": links, "issue_forms": forms,
                      "asset_count": asset_count, "asset_bytes": asset_bytes, "errors": errors,
                      "scope": "Offline public-document/form/asset checks, not engine rendering, all historical tests or legal certification."}, ensure_ascii=False))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
