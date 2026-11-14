#!/usr/bin/env python3
"""Outputs whose native Scrolling windows need the screen frame protected."""
import json
import subprocess
import sys


def protected(monitors, workspaces):
    by_id = {w['id']: w for w in workspaces}
    return {m['name']: True for m in monitors
            if (by_id.get(m.get('activeWorkspace', {}).get('id'), {}).get('tiledLayout') == 'scrolling'
                and not by_id.get(m.get('activeWorkspace', {}).get('id'), {}).get('hasfullscreen')
                and not m.get('specialWorkspace', {}).get('id', 0))}


if __name__ == '__main__':
    try:
        def query(name):
            return json.loads(subprocess.check_output(['hyprctl', name, '-j'], text=True, timeout=2))
        print(json.dumps(protected(query('monitors'), query('workspaces'))))
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        print('{}')
        sys.exit(1 if '--snapshot' in sys.argv else 0)
