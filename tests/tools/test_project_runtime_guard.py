"""Concurrency/cancellation checks using sleeping Python children, never a 3D engine."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch, Mock

TOOLS = Path(__file__).resolve().parents[2] / 'tools'
sys.path.insert(0, str(TOOLS))
import project_runtime_guard as guard
import preview_macos as preview


class RuntimeGuardTests(unittest.TestCase):
    def test_preview_size_uses_native_points_on_mixed_density_displays(self):
        displays = [{'scale': 1, 'width': 2560, 'height': 1410},
                    {'scale': 2, 'width': 1470, 'height': 924}]
        with patch.object(preview.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, json.dumps(displays))):
            self.assertEqual(preview.preview_resolution(0), '2560x1600')
            self.assertEqual(preview.preview_resolution(1), '2560x1600')

    def test_preview_size_stays_within_single_standard_density_display(self):
        displays = [{'scale': 1, 'width': 1024, 'height': 768}]
        with patch.object(preview.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, json.dumps(displays))):
            self.assertEqual(preview.preview_resolution(0), '976x696')

    def test_project_identity_excludes_shells_and_other_checkouts(self):
        root = Path('/projects/Twinverse')
        self.assertTrue(guard.belongs_to_project('/Applications/Godot', '--path /projects/Twinverse', None, root))
        self.assertTrue(guard.belongs_to_project('/Applications/Blender', '--python tools/art/a.py', root, root))
        self.assertTrue(guard.belongs_to_project('/Applications/Godot', '--path .', root / 'tools', root))
        self.assertFalse(guard.belongs_to_project('/bin/zsh', 'Godot --path /projects/Twinverse', root, root))
        self.assertFalse(guard.belongs_to_project('/Applications/Godot', '--path /projects/Twinverse-other', Path('/other'), root))

    def test_process_snapshot_checks_relative_project_path(self):
        root = Path('/projects/Twinverse')
        def run(command, **_kwargs):
            output = '--path .\n' if command[0] == 'ps' else 'p42\nn/projects/Twinverse\n'
            return subprocess.CompletedProcess(command, 0, output, '')
        with patch.object(guard.subprocess, 'check_output', return_value='42 /Applications/Godot.app/Contents/MacOS/Godot\n43 /bin/zsh\n'), patch.object(guard.subprocess, 'run', side_effect=run):
            self.assertEqual([item['pid'] for item in guard.project_processes(root)], [42])

    def test_busy_process_refused_without_killing_it(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(guard, 'project_processes', return_value=[{'pid': 123}]):
            with self.assertRaisesRegex(guard.ProjectBusy, '123'):
                with guard.project_slot(Path(folder)):
                    self.fail('must not launch')

    def test_lock_releases_after_exception_and_old_file_is_safe(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(guard, 'project_processes', return_value=[]):
            root = Path(folder)
            with self.assertRaises(ValueError):
                with guard.project_slot(root):
                    with self.assertRaises(guard.ProjectBusy):
                        with guard.project_slot(root):
                            self.fail('two owners')
                    raise ValueError('launch failed')
            self.assertTrue((root / '.local/runtime/launch.lock').exists())
            with guard.project_slot(root):
                pass

    def test_real_child_cancellation_and_competing_launcher(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            ready = root / 'ready.json'
            child_code = ('import os,time,json;from pathlib import Path;'
                          f'Path({str(ready)!r}).write_text(json.dumps({{"pid":os.getpid(),"nice":os.getpriority(os.PRIO_PROCESS,0)}}));'
                          'time.sleep(30)')
            owner_code = (f'import sys;sys.path.insert(0,{str(TOOLS)!r});'
                          'import project_runtime_guard as g;from pathlib import Path;'
                          'g.project_processes=lambda root:[]\n'
                          f'with g.project_slot(Path({folder!r})):\n'
                          f' sys.exit(g.run_engine({[sys.executable, "-c", child_code]!r}))\n')
            owner = subprocess.Popen([sys.executable, '-c', owner_code])
            try:
                deadline = time.monotonic() + 5
                while not ready.exists() and time.monotonic() < deadline:
                    time.sleep(0.02)
                self.assertTrue(ready.exists(), 'child did not start')
                child = json.loads(ready.read_text())
                self.assertGreaterEqual(child['nice'], 10)
                with patch.object(guard, 'project_processes', return_value=[]):
                    with self.assertRaises(guard.ProjectBusy):
                        with guard.project_slot(root):
                            self.fail('competing launcher passed')
                owner.send_signal(signal.SIGTERM)
                self.assertEqual(owner.wait(timeout=5), 143)
                with self.assertRaises(ProcessLookupError):
                    os.kill(child['pid'], 0)
                with patch.object(guard, 'project_processes', return_value=[]):
                    with guard.project_slot(root):
                        pass
            finally:
                if owner.poll() is None:
                    owner.terminate()
                    owner.wait(timeout=5)

    def test_engine_exit_status_preserved(self):
        self.assertEqual(guard.run_engine([sys.executable, '-c', 'raise SystemExit(7)']), 7)

    def test_godot_shell_uses_guard_and_preserves_arguments(self):
        with tempfile.TemporaryDirectory() as folder:
            executable = Path(folder) / 'fake engine'
            version = (TOOLS.parent / '.godot-version').read_text().strip()
            executable.write_text('#!/usr/bin/env python3\nimport sys,os,json\n'
                                  f'if sys.argv[1:]==["--version"]: print({version!r})\n'
                                  'else:\n print(json.dumps({"args":sys.argv[1:],"nice":os.getpriority(os.PRIO_PROCESS,0)}))\n sys.exit(7)\n')
            executable.chmod(0o755)
            result = subprocess.run([str(TOOLS / 'godot.sh'), '--headless', '--', 'label with spaces'],
                                    env={**os.environ, 'GODOT_BIN': str(executable)},
                                    capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 7, result.stderr)
            value = json.loads(result.stdout)
            self.assertEqual(value['args'], ['--path', str(TOOLS.parent), '--headless', '--', 'label with spaces'])
            self.assertGreaterEqual(value['nice'], 10)

    def test_preview_holds_shared_slot_until_open_wait_finishes(self):
        for relative in ['builds/macos/current/3DWorld.app', 'builds/macos/3DWorld.app']:
            with self.subTest(export=relative), tempfile.TemporaryDirectory() as folder:
                root = Path(folder).resolve()
                app = root / relative
                app.mkdir(parents=True)
                launcher = Mock()
                launcher.poll.return_value = None
                def wait():
                    with self.assertRaises(guard.ProjectBusy):
                        with guard.project_slot(root):
                            self.fail('preview released slot before exit')
                    return 0
                launcher.wait.side_effect = wait
                engine = {'pid': 123, 'executable': str(app / 'Contents/MacOS/3DWorld')}
                with patch.object(preview, 'preview_resolution', return_value='2560x1600') as resolution, patch.object(preview, 'ROOT', root), patch.object(guard, 'project_processes', return_value=[]), patch.object(preview, 'project_processes', return_value=[engine]), patch.object(preview.subprocess, 'Popen', return_value=launcher) as start, patch.object(preview.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as run, patch.object(preview.tempfile, 'mkdtemp', return_value=folder), patch.object(sys, 'argv', ['preview_macos.py', '--screen', '1']):
                    self.assertEqual(preview.main(), 0)
                    resolution.assert_called_once_with(1)
                    command = start.call_args.args[0]
                    self.assertEqual(command[:4], ['open', '-W', '-n', str(app)])
                    run.assert_called_once_with(['renice', '10', '-p', '123'], capture_output=True, text=True)
                    with guard.project_slot(root):
                        pass


if __name__ == '__main__':
    unittest.main(verbosity=2)
