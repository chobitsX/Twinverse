#!/usr/bin/env python3
"""Serialize project engine launches without stopping another user's work."""
from contextlib import contextmanager
import fcntl
import os
from pathlib import Path
import signal
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BUSY_EXIT = 75


class ProjectBusy(RuntimeError):
    pass


def belongs_to_project(executable, arguments, cwd, root=ROOT):
    if Path(executable).name not in ('Godot', '3DWorld', 'Blender'):
        return False
    if str(root) + '/' in arguments or str(root) in arguments.split():
        return True
    return cwd is not None and (cwd == root or root in cwd.parents)


def project_processes(root=ROOT):
    """Only inspect known engine executables; shell text is not a running engine."""
    snapshot = subprocess.check_output(['ps', '-axo', 'pid=,comm='], text=True)
    found = []
    for line in snapshot.splitlines():
        fields = line.strip().split(None, 1)
        if len(fields) != 2 or Path(fields[1]).name not in ('Godot', '3DWorld', 'Blender'):
            continue
        pid, executable = int(fields[0]), fields[1]
        result = subprocess.run(['ps', '-p', str(pid), '-o', 'args='], capture_output=True, text=True)
        if result.returncode != 0:  # Process ended since snapshot.
            continue
        arguments = result.stdout.strip()
        cwd = None
        if not belongs_to_project(executable, arguments, None, root):
            # Relative --path/--python arguments still belong to the current checkout.
            location = subprocess.run(['lsof', '-a', '-p', str(pid), '-d', 'cwd', '-Fn'],
                                      capture_output=True, text=True)
            for item in location.stdout.splitlines():
                if item.startswith('n'):
                    cwd = Path(item[1:])
        if belongs_to_project(executable, arguments, cwd, root):
            found.append({'pid': pid, 'executable': executable, 'arguments': arguments})
    return found


@contextmanager
def project_slot(root=ROOT):
    directory = root / '.local/runtime'
    directory.mkdir(parents=True, exist_ok=True)
    # Keep the inode: unlinking a lock file can create two independent locks.
    with (directory / 'launch.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise ProjectBusy('已有本项目启动或运行作业；本次不叠开，请等其退出。') from error
        try:
            existing = project_processes(root)
            if existing:
                ids = ', '.join(str(item['pid']) for item in existing)
                raise ProjectBusy(f'已有本项目引擎/资产作业（PID {ids}）；本次不叠开。')
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def run_engine(command):
    """Hold the caller's slot until the child really exits, including cancellation."""
    child = subprocess.Popen(['nice', '-n', '10', *command], start_new_session=True)
    previous = {}

    def forward(signum, _frame):
        try:
            os.killpg(child.pid, signum)
        except ProcessLookupError:
            pass

    try:
        for signum in (signal.SIGINT, signal.SIGTERM):
            previous[signum] = signal.signal(signum, forward)
        code = child.wait()
        return code if code >= 0 else 128 - code
    finally:
        for signum, handler in previous.items():
            signal.signal(signum, handler)


def main():
    # godot.sh supplies the validated path and pinned version, then engine args.
    executable, expected, *arguments = sys.argv[1:]
    try:
        with project_slot():
            result = subprocess.run(['nice', '-n', '10', executable, '--version'],
                                    capture_output=True, text=True, check=True)
            actual = result.stdout.strip()
            if actual != expected:
                print(f'Godot version mismatch: expected {expected}, got {actual}.', file=sys.stderr)
                return 1
            return run_engine([executable, '--path', str(ROOT), *arguments])
    except ProjectBusy as error:
        print(error, file=sys.stderr)
        return BUSY_EXIT


if __name__ == '__main__':
    sys.exit(main())
