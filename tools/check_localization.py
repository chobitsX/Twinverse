#!/usr/bin/env python3
"""Audit Chinese source literals and validate authored English (no network)."""
from __future__ import annotations
import argparse
import ast
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
# Consume comments as tokens so quoted prose in comments isn't UI content.
TOKEN = re.compile(r'"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27|#[^\n]*')
HAN = re.compile(r'[\u3400-\u9fff]')
PRINTF = re.compile(r'%(?:[-+0#]*\d*(?:\.\d+)?[sdifegouxXc]|%)')

def source_messages() -> dict[str, list[str]]:
    messages: dict[str, list[str]] = {}
    for path in sorted((ROOT / 'scripts').rglob('*.gd')):
        content = path.read_text()
        for match in TOKEN.finditer(content):
            token = match.group()
            if token.startswith('#') or not HAN.search(token):
                continue
            try:
                value = json.loads(token, strict=False) if token.startswith('"') else ast.literal_eval(token.replace(chr(10), r'\n'))
            except (ValueError, SyntaxError) as error:
                raise ValueError(f"Cannot decode source message at {path}:{content[:match.start()].count(chr(10))+1}") from error
            location = f'{path.relative_to(ROOT)}:{content[:match.start()].count(chr(10)) + 1}'
            messages.setdefault(value, []).append(location)
    # Scene-authored text and user-facing names from frozen scientific data.
    for path in sorted((ROOT / 'scenes').rglob('*.tscn')):
        for match in TOKEN.finditer(path.read_text()):
            if match[0].startswith('"') and HAN.search(match[0]):
                value = json.loads(match[0], strict=False)
                messages.setdefault(value, []).append(str(path.relative_to(ROOT)))
    path = ROOT / 'assets/data/satellites273/catalogue.json'
    catalog = json.loads(path.read_text())
    for host, records in catalog['groups'].items():
        for record in records:
            for field in ['display_name', 'discovery_years']:
                value = str(record.get(field, ''))
                if HAN.search(value):
                    messages.setdefault(value, []).append(f'{path.relative_to(ROOT)}#{host}/{record["key"]}/{field}')
    return messages

def validate(messages: dict, english: dict) -> dict:
    exclusions = json.loads((ROOT / 'localization/exclusions.json').read_text())
    missing = [key for key in messages if not english.get(key) and key not in exclusions]
    errors = []
    for source, target in english.items():
        if not isinstance(target, str) or not target.strip():
            errors.append({'source': source, 'error': 'empty/non-string translation'})
            continue
        if PRINTF.findall(source) != PRINTF.findall(target):
            errors.append({'source': source, 'error': 'printf placeholders differ'})
        # Preserve rich-text control markup, including URL targets.
        if re.findall(r'\[/?(?:b|i|u|url|color|font_size)(?:=[^\]]*)?\]', source) != re.findall(r'\[/?(?:b|i|u|url|color|font_size)(?:=[^\]]*)?\]', target):
            errors.append({'source': source, 'error': 'rich text markup differs'})
        if HAN.search(target):
            errors.append({'source': source, 'error': 'Chinese remains in English'})
    return {'source_messages': len(messages), 'translated_messages': sum(bool(english.get(k)) for k in messages),
            'missing': missing, 'errors': errors, 'excluded': exclusions,
            'note': 'Static inventory includes internal literals; runtime and visual checks remain required.'}

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--allow-missing', action='store_true', help='For implementation checkpoints only')
    parser.add_argument('--write-audit', action='store_true')
    args = parser.parse_args()
    messages = source_messages()
    english = json.loads((ROOT / 'localization/en.json').read_text())
    report = validate(messages, english)
    if args.write_audit:
        directory = ROOT / 'docs/evidence/I18N-001'
        directory.mkdir(parents=True, exist_ok=True)
        (directory / 'source-audit.json').write_text(json.dumps(messages, ensure_ascii=False, indent=2) + '\n')
        (directory / 'catalog-check.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v if k not in ('missing', 'errors') else len(v) for k, v in report.items()}, ensure_ascii=False))
    return int(bool(report['errors']) or (bool(report['missing']) and not args.allow_missing))

if __name__ == '__main__':
    raise SystemExit(main())
