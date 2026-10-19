"""Regression for literal newlines missed by the first localization audit."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('localization_check', ROOT / 'tools/check_localization.py')
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)

class SourceAuditTest(unittest.TestCase):
    def test_multiline_literals_and_comments(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'scripts').mkdir()
            (root / 'scripts/example.gd').write_text('# "注释不应进入目录"\nvar hint = "第一行\n第二行"\nvar escaped = "实际\\n换行"\nvar english = "kept-as-id"\n')
            (root / 'assets/data/satellites273').mkdir(parents=True)
            (root / 'assets/data/satellites273/catalogue.json').write_text('{"groups":{}}')
            with patch.object(check, 'ROOT', root):
                messages = check.source_messages()
            self.assertEqual(set(messages), {'第一行\n第二行', '实际\n换行'})

if __name__ == '__main__':
    unittest.main()
