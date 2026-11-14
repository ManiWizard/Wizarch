#!/usr/bin/env python3
"""Read which monitors have ordinary windows on their currently visible workspaces."""
import json
import subprocess
import sys

def occupied(monitors, clients):
    result = {}
    for monitor in monitors:
        visible = {monitor['activeWorkspace']['id']}
        special = monitor.get('specialWorkspace', {}).get('id', 0)
        if special:
            visible.add(special)
        result[monitor['name']] = any(
            c.get('monitor') == monitor['id'] and c.get('mapped', True)
            and not c.get('hidden', False)
            and (c.get('class') != 'org.quickshell' or c.get('title') == 'Wizarch Settings')
            and c.get('workspace', {}).get('id') in visible
            for c in clients)
    return result

if __name__ == '__main__':
    try:
        def query(name):
            return json.loads(subprocess.check_output(['hyprctl', name, '-j'], text=True, timeout=3))
        monitors, clients = query('monitors'), query('clients')
        occupancy = occupied(monitors, clients)
        if '--snapshot' in sys.argv:
            print(json.dumps({'occupiedMonitors': occupancy, 'trayWindows': [c for c in clients if c.get('workspace', {}).get('name') == 'special:wizarch-tray']}))
        else:
            print(json.dumps(occupancy))
    except (OSError, ValueError, KeyError, subprocess.SubprocessError):
        # Empty/unknown monitors should stay visible rather than disappear.
        print('{}')
        sys.exit(1 if '--snapshot' in sys.argv else 0)
