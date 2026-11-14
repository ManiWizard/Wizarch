#!/usr/bin/env python3
"""Describe neighboring columns on each visible Scrolling workspace."""
import json
import subprocess


def stacks(monitors, workspaces, clients, active):
    result = {}
    by_id = {w['id']: w for w in workspaces}
    for monitor in monitors:
        workspace = by_id.get(monitor.get('activeWorkspace', {}).get('id'), {})
        if (workspace.get('tiledLayout') != 'scrolling'
                or workspace.get('hasfullscreen')
                or monitor.get('specialWorkspace', {}).get('id', 0)):
            continue
        windows = [c for c in clients if c.get('monitor') == monitor['id']
                   and c.get('workspace', {}).get('id') == workspace.get('id')
                   and c.get('mapped', True) and not c.get('hidden', False)
                   and not c.get('floating') and not c.get('pinned')
                   and c.get('class') != 'org.quickshell']
        windows.sort(key=lambda c: (c.get('at', [0, 0])[0],
                                    c.get('at', [0, 0])[1], c['address']))
        if len(windows) < 2:
            continue
        address = (active.get('address') if active.get('monitor') == monitor['id']
                   and active.get('workspace', {}).get('id') == workspace['id']
                   else workspace.get('lastwindow'))
        index = next((i for i, c in enumerate(windows) if c['address'] == address), None)
        # Floating focus and inconsistent IPC snapshots should never reserve space.
        if index is None:
            continue
        neighbors = (windows[index + 1:] + windows[:index])[:3]
        result[monitor['name']] = {
            'workspace': workspace['name'], 'active': address, 'count': len(windows),
            # Hyprland 0.56 only completes toplevel exports intersecting the output.
            # Offscreen cards reuse their last captured frame, never move apps to
            # obtain a preview. Unvisited apps use the named page placeholder.
            'capture': [c['address'] for c in windows if c['address'] == address or (
                        c.get('at', [0, 0])[0] < monitor.get('x', 0) + monitor.get('width', 1920) / monitor.get('scale', 1)
                        and c.get('at', [0, 0])[0] + c.get('size', [1920, 1080])[0] > monitor.get('x', 0))],
            'cards': [{'address': c['address'], 'title': c.get('title', ''),
                       'app': c.get('class', '')} for c in neighbors]}
    return result


if __name__ == '__main__':
    try:
        def query(name):
            return json.loads(subprocess.check_output(['hyprctl', name, '-j'],
                                                     text=True, timeout=2))
        print(json.dumps(stacks(query('monitors'), query('workspaces'),
                               query('clients'), query('activewindow'))))
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        print('{}')
