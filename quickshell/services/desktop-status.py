#!/usr/bin/env python3
"""Read local capabilities; execute only explicit radio/backlight UI actions."""
import json
import os
import shutil
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
    ethernet = False
    for p in Path('/sys/class/net').iterdir():
        try:
            if (p / 'carrier').read_text().strip() == '1':
                if (p / 'wireless').exists():
                    wifi = True
                elif p.name != 'lo' and not (p / 'device' / 'driver').resolve().name.startswith(('tun', 'veth')):
                    ethernet = True
        except OSError:
            pass
    radios = json.loads(run(['rfkill', '--json']))['rfkilldevices']
    wlan = [r for r in radios if r['type'] == 'wlan']
    device = backlight()
    try:
        location = run(['gsettings', 'get', 'org.gnome.system.location', 'enabled']).strip() == 'true'
        location_available = True
    except (OSError, subprocess.SubprocessError):
        location = False
        location_available = False
    try:
        camera_access = run(['gsettings', 'get', 'org.gnome.desktop.privacy', 'disable-camera']).strip() == 'false'
        microphone_access = run(['gsettings', 'get', 'org.gnome.desktop.privacy', 'disable-microphone']).strip() == 'false'
        privacy_available = True
    except (OSError, subprocess.SubprocessError):
        camera_access = microphone_access = False
        privacy_available = False
    try:
        profile = run(['powerprofilesctl', 'get']).strip()
    except (OSError, subprocess.SubprocessError):
        profile = ''
    if shutil.which('nmcli'):
        try:
            hotspot = any(line.startswith('Hotspot:') for line in
                          run(['nmcli', '-t', '-f', 'NAME,TYPE', 'connection', 'show', '--active']).splitlines())
        except (OSError, subprocess.SubprocessError):
            hotspot = False
    else:
        hotspot = False
    try:
        resume = Path('/sys/power/resume').read_text().strip()
        hibernate = 'disk' in Path('/sys/power/state').read_text().split() and resume != '0:0' and bool(run(['swapon', '--noheadings', '--show=NAME']).strip())
    except (OSError, subprocess.SubprocessError):
        hibernate = False
    try:
        os.kill(int((Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp')) / 'wizarch-recording.pid').read_text()), 0)
        recording = True
    except (OSError, ValueError, ProcessLookupError):
        recording = False
    return dict(wifi=wifi, ethernet=ethernet, wifiPresent=bool(wlan),
                wifiBlocked=bool(wlan) and all(r['soft'] == 'blocked' for r in wlan),
                wifiHardBlocked=any(r['hard'] == 'blocked' for r in wlan),
                radioWritable=os.access('/dev/rfkill', os.W_OK),
                brightness=round(int((device / 'brightness').read_text()) * 100 /
                                 int((device / 'max_brightness').read_text())) if device else -1,
                airplane=bool(radios) and all(r['soft'] == 'blocked' for r in radios),
                hotspotAvailable=bool(shutil.which('nmcli')) and bool(wlan), hotspot=hotspot,
                batterySaverAvailable=bool(shutil.which('powerprofilesctl')),
                batterySaver=profile == 'power-saver',
                locationAvailable=location_available, location=location,
                privacyAvailable=privacy_available, cameraAccess=camera_access,
                microphoneAccess=microphone_access,
                recordingAvailable=bool(shutil.which('wf-recorder')), recording=recording,
                hibernateSupported=hibernate)

try:
    action = sys.argv[1] if len(sys.argv) > 1 else 'status'
    if action == 'wifi':
        if sys.argv[2] not in ('on', 'off'):
            raise ValueError('Invalid radio state')
        run(['rfkill', 'unblock' if sys.argv[2] == 'on' else 'block', 'wlan'])
    elif action == 'airplane':
        if sys.argv[2] not in ('on', 'off'):
            raise ValueError('Invalid airplane mode')
        run(['rfkill', 'block' if sys.argv[2] == 'on' else 'unblock', 'all'])
    elif action == 'battery-saver':
        if sys.argv[2] not in ('on', 'off'):
            raise ValueError('Invalid battery mode')
        run(['powerprofilesctl', 'set', 'power-saver' if sys.argv[2] == 'on' else 'balanced'])
    elif action == 'location':
        if sys.argv[2] not in ('on', 'off'):
            raise ValueError('Invalid location mode')
        run(['gsettings', 'set', 'org.gnome.system.location', 'enabled',
             'true' if sys.argv[2] == 'on' else 'false'])
    elif action in ('camera', 'microphone'):
        if sys.argv[2] not in ('on', 'off'):
            raise ValueError('Invalid privacy mode')
        run(['gsettings', 'set', 'org.gnome.desktop.privacy',
             'disable-camera' if action == 'camera' else 'disable-microphone',
             'false' if sys.argv[2] == 'on' else 'true'])
    elif action == 'hotspot':
        if sys.argv[2] not in ('on', 'off'):
            raise ValueError('Invalid hotspot mode')
        run(['nmcli', 'device', 'wifi', 'hotspot'] if sys.argv[2] == 'on'
            else ['nmcli', 'connection', 'down', 'Hotspot'])
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
