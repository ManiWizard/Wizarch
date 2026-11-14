#!/usr/bin/env python3
"""Launcher-owned recent app IDs; bounded, atomic, and shared safely across monitors."""
import fcntl
import json
import os
from pathlib import Path
import sys


def history_path():
    return Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state'))) / 'wizarch/launcher/recent.json'


def update(identity=None):
    path = history_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.with_suffix('.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            data = json.loads(path.read_text())
        except (OSError, ValueError):
            data = []
        values = list(dict.fromkeys(item for item in data if isinstance(item, str) and item)) if isinstance(data, list) else []
        if identity:
            values = [identity] + [item for item in values if item != identity]
            temporary = path.with_suffix('.tmp')
            temporary.write_text(json.dumps(values[:24])+'\n')
            os.replace(temporary, path)
        return values[:24]


if __name__ == '__main__':
    if len(sys.argv) == 1:
        print(json.dumps(update()))
    elif len(sys.argv) == 3 and sys.argv[1] == 'record' and sys.argv[2]:
        print(json.dumps(update(sys.argv[2])))
    else:
        raise SystemExit('usage: launcher-history.py [record DESKTOP_ID]')
