#!/usr/bin/env python3
"""Read local capabilities; execute only explicit radio/backlight UI actions."""
import json
import os
from pathlib import Path
import subprocess
import sys


def run(args):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE, timeout=3)


def backlight():
    return next(iter(sorted(Path('/sys/class/backlight').iterdir())), None)


def session_path():
    sessions = json.loads(run(['loginctl', 'list-sessions', '--json=short']))
    for session in sessions:
        if session.get('uid') == os.getuid():
            sid = str(session['session'])
            props = run(['loginctl', 'show-session', sid, '-p', 'Active', '-p', 'Type'])
            if 'Active=yes' in props and ('Type=wayland' in props or 'Type=x11' in props):
                # Ask logind to encode the session ID into an object path.
                return run(['busctl', '--system', 'call', 'org.freedesktop.login1',
                            '/org/freedesktop/login1', 'org.freedesktop.login1.Manager',
                            'GetSession', 's', sid]).split('"')[1]
    raise RuntimeError('No active graphical session')


def status():
    wifi = False
    for p in Path('/sys/class/net').iterdir():
        try:
            if (p / 'wireless').exists() and (p / 'carrier').read_text().strip() == '1':
                wifi = True
        except OSError:
            pass
    radios = json.loads(run(['rfkill', '--json']))['rfkilldevices']
    wlan = [r for r in radios if r['type'] == 'wlan']
    device = backlight()
    return dict(wifi=wifi, wifiPresent=bool(wlan),
                wifiBlocked=bool(wlan) and all(r['soft'] == 'blocked' for r in wlan),
                wifiHardBlocked=any(r['hard'] == 'blocked' for r in wlan),
                radioWritable=os.access('/dev/rfkill', os.W_OK),
                brightness=round(int((device / 'brightness').read_text()) * 100 /
                                 int((device / 'max_brightness').read_text())) if device else -1)

try:
    action = sys.argv[1] if len(sys.argv) > 1 else 'status'
    if action == 'wifi':
        if sys.argv[2] not in ('on', 'off'):
            raise ValueError('Invalid radio state')
        run(['rfkill', 'unblock' if sys.argv[2] == 'on' else 'block', 'wlan'])
    elif action == 'brightness':
        device = backlight()
        if device is None:
            raise RuntimeError('No laptop backlight')
        percent = max(5, min(100, float(sys.argv[2])))
        level = max(1, round(int((device / 'max_brightness').read_text()) * percent / 100))
        run(['busctl', '--system', 'call', 'org.freedesktop.login1', session_path(),
             'org.freedesktop.login1.Session', 'SetBrightness', 'ssu',
             'backlight', device.name, str(level)])
    elif action != 'status':
        raise ValueError('Unknown action')
    print(json.dumps({'ok': True, **status()}))
except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
    print(json.dumps({'ok': False, 'error': str(error)}))
    sys.exit(1)
