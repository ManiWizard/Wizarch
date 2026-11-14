#!/usr/bin/env python3
"""Supplement Quickshell's app model with desktop-specific visibility rules only."""
import configparser
import json
import os
from pathlib import Path
import shutil


def exclusions(env=os.environ):
    desktop = set(env.get('XDG_CURRENT_DESKTOP', '').split(':')) - {''}
    roots = [env.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))]
    roots += env.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':')
    seen, excluded = set(), {}
    for root in roots:
        folder = Path(root) / 'applications'
        for file in sorted(folder.rglob('*.desktop')):
            identity = str(file.relative_to(folder)).replace('/', '-')[:-8]
            if identity in seen:
                continue
            seen.add(identity)
            parser = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                parser.read(file, encoding='utf-8')
                entry = parser['Desktop Entry']
            except (OSError, UnicodeError, configparser.Error, KeyError):
                continue  # Broken metadata is not an intentional visibility instruction.
            only = set(entry.get('OnlyShowIn', '').split(';')) - {''}
            never = set(entry.get('NotShowIn', '').split(';')) - {''}
            reason = ''
            if entry.get('Hidden', '').lower() == 'true':
                reason = 'Hidden'
            elif entry.get('NoDisplay', '').lower() == 'true':
                reason = 'NoDisplay'
            elif only and not only.intersection(desktop):
                reason = 'OnlyShowIn'
            elif never.intersection(desktop):
                reason = 'NotShowIn'
            elif entry.get('TryExec') and not shutil.which(entry['TryExec'], path=env.get('PATH')):
                reason = 'TryExec'
            if reason:
                excluded[identity] = reason
    return excluded


if __name__ == '__main__':
    print(json.dumps(exclusions()))
