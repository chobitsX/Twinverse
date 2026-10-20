#!/usr/bin/env python3
"""Launch one bounded preview; reuse an existing project instance by refusing duplicates."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import sys
import time

from project_runtime_guard import BUSY_EXIT, ProjectBusy, project_processes, project_slot

ROOT = Path(__file__).resolve().parents[1]


def preview_resolution(screen):
    script = 'ObjC.import("AppKit"); var screens=$.NSScreen.screens; var list=[]; for(var i=0;i<Number(screens.count);i++){var s=screens.objectAtIndex(i); list.push({scale:Number(s.backingScaleFactor),width:Number(s.visibleFrame.size.width),height:Number(s.visibleFrame.size.height)});} JSON.stringify(list);'
    result = subprocess.run(['/usr/bin/osascript', '-l', 'JavaScript', '-e', script],
                            capture_output=True, text=True, check=True, timeout=5)
    displays = json.loads(result.stdout)
    display = displays[screen]
    width = min(1280, int(display['width']) - 48)
    height = min(800, int(display['height']) - 72)
    # Godot uses the maximum display density for all macOS window coordinates.
    density = max(item['scale'] for item in displays)
    return f"{round(width * density)}x{round(height * density)}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--screen', type=int, required=True,
                        help='Godot display index, after checking current monitor arrangement')
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--knowledge', action='store_true', help='Open the current observation knowledge card')
    parser.add_argument('--scale', choices=['earth','solar_system','galaxy','universe','night_sky'], default='universe',
                        help='Initial no-save observation scale')
    args = parser.parse_args()
    local = ROOT / '.local/preview'
    local.mkdir(parents=True, exist_ok=True)
    with project_slot(ROOT):
        app = ROOT / 'builds/macos/current/3DWorld.app'
        if not app.is_dir():
            app = ROOT / 'builds/macos/3DWorld.app'
        app = app.resolve(strict=True)
        command = ['open', '-W', '-n', str(app), '--args', '--screen', str(args.screen),
                   '--resolution', preview_resolution(args.screen), '--windowed', '--max-fps', '30',
                   '--', f'--scale={args.scale}', '--no-save', '--experience-preset']
        if args.knowledge:
            command.append('--show-knowledge')
        if args.dry_run:
            print(json.dumps(command, ensure_ascii=False))
            return
        logs = Path(tempfile.mkdtemp(prefix='twinverse-user-preview-'))
        command[4:4] = ['--stdin', '/dev/null', '--stdout', str(logs / 'stdout.log'),
                        '--stderr', str(logs / 'stderr.log')]
        launcher = subprocess.Popen(command)
        priority = []
        deadline = time.monotonic() + 10
        while launcher.poll() is None and time.monotonic() < deadline:
            processes = [item for item in project_processes(ROOT)
                         if item['executable'] == str(app / 'Contents/MacOS/3DWorld')]
            if processes:
                for item in processes:
                    result = subprocess.run(['renice', '10', '-p', str(item['pid'])],
                                            capture_output=True, text=True)
                    priority.append({'pid': item['pid'], 'exit': result.returncode})
                break
            time.sleep(0.2)
        (local / 'last-launch.json').write_text(json.dumps(
            {'app': str(app), 'argv': command, 'logs': str(logs), 'priority': priority},
            ensure_ascii=False, indent=2) + '\n')
        print('已请求打开单个限帧预览；关闭预览后释放运行锁。日志：' + str(logs), flush=True)
        if not priority or any(item['exit'] != 0 for item in priority):
            print('未确认应用降优先级；限帧和单实例锁仍生效，请查看启动记录。', flush=True)
        return launcher.wait()


if __name__ == '__main__':
    try:
        sys.exit(main())
    except ProjectBusy as error:
        print(error, file=sys.stderr)
        sys.exit(BUSY_EXIT)
