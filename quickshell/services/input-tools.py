#!/usr/bin/env python3
"""Clipboard history and insertion into the window focused before Wizarch opened."""
import json
import re
from pathlib import Path
import subprocess
import sys
import time

FOCUS = Path.home() / '.cache' / 'wizarch' / 'previous-window'


def paste(data):
    subprocess.run(['wl-copy'], input=data, check=True, timeout=3)
    try:
        address = FOCUS.read_text().strip()
        if re.fullmatch(r'0x[0-9a-fA-F]+', address):
            selector = 'address:' + address
            subprocess.run(['hyprctl', 'dispatch', f'hl.dsp.focus({{ window = "{selector}" }})'],
                           check=False, capture_output=True, timeout=3)
            time.sleep(.12)
            subprocess.run(['hyprctl', 'dispatch', f'hl.dsp.send_shortcut({{ mods = "CTRL", key = "V", window = "{selector}" }})'],
                           check=False, capture_output=True, timeout=3)
    except OSError:
        pass


try:
    action = sys.argv[1]
    if action == 'list':
        output = subprocess.check_output(['cliphist', 'list'], text=True, timeout=3)
        entries = [dict(id=line.split('\t', 1)[0], preview=line.split('\t', 1)[-1])
                   for line in output.splitlines() if '\t' in line]
        print(json.dumps({'ok': True, 'entries': entries}))
    elif action == 'paste' and len(sys.argv) == 3:
        data = subprocess.check_output(['cliphist', 'decode', sys.argv[2]], timeout=3)
        paste(data)
        print(json.dumps({'ok': True}))
    elif action == 'emoji' and len(sys.argv) == 3:
        paste(sys.argv[2].encode())
        print(json.dumps({'ok': True}))
    elif action == 'delete' and len(sys.argv) == 3:
        subprocess.run(['cliphist', 'delete', sys.argv[2]], check=True, timeout=3)
        print(json.dumps({'ok': True}))
    elif action == 'clear':
        subprocess.run(['cliphist', 'wipe'], check=True, timeout=3)
        print(json.dumps({'ok': True}))
    else:
        raise ValueError('Unknown input action')
except (OSError, ValueError, IndexError, subprocess.SubprocessError) as error:
    print(json.dumps({'ok': False, 'error': str(error)}))
    sys.exit(1)
