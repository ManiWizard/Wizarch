#!/usr/bin/env python3
"""Match the frame's inner radius to the actual outer window radius."""
import json, math, re, subprocess

def query(name):
    return json.loads(subprocess.check_output(['hyprctl', 'getoption', name, '-j'], text=True, timeout=3))

if __name__ == '__main__':
    try:
        rounding = query('decoration:rounding')['int']
        border = query('general:border_size')['int']
        power = query('decoration:rounding_power')['float']
        gaps = query('general:gaps_out')
        values = [float(n) for n in re.findall(r'\d+(?:\.\d+)?', gaps.get('css', str(gaps.get('int', 0))))]
        correction = border * (math.sqrt(2) - 1) * max(2 - power, 0)
        # Same outer-rounding correction used by Hyprland 0.56.2's border decoration.
        outer_radius = rounding + border - correction
        print(json.dumps({'radius': max(0, outer_radius), 'rounding': rounding, 'border': border, 'gaps': values}))
    except (OSError, ValueError, KeyError, subprocess.SubprocessError):
        print('{}')
