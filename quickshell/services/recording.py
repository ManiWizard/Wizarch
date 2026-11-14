#!/usr/bin/env python3
"""Start or stop an explicit fullscreen recording."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
from datetime import datetime

PID_FILE = Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp')) / 'wizarch-recording.pid'


def pid():
    try:
        number = int(PID_FILE.read_text())
        os.kill(number, 0)
        return number
    except (OSError, ValueError, ProcessLookupError):
        return None


action = sys.argv[1] if len(sys.argv) > 1 else 'status'
current = pid()
if action == 'toggle':
    if current:
        os.kill(current, signal.SIGINT)
        PID_FILE.unlink(missing_ok=True)
        current = None
    elif shutil.which('wf-recorder'):
        videos = Path.home() / 'Videos'
        videos.mkdir(parents=True, exist_ok=True)
        output = videos / ('Wizarch-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '.mp4')
        process = subprocess.Popen(['wf-recorder', '-f', str(output)],
                                   stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                   stderr=subprocess.DEVNULL, start_new_session=True)
        PID_FILE.write_text(str(process.pid))
        current = process.pid
    else:
        print(json.dumps({'ok': False, 'error': 'Install wf-recorder'}))
        raise SystemExit(1)
elif action != 'status':
    raise SystemExit('Unknown recording action')
print(json.dumps({'ok': True, 'recording': bool(current)}))
