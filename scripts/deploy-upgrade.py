#!/usr/bin/env python3
"""Prepare, apply or restore an explicit, hash-checked file deployment.

prepare MANIFEST --mapping JSON (a list of {source,target} absolute paths)
apply MANIFEST / restore MANIFEST. No commands, reloads or whole-directory copies run.
"""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import stat
import tempfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def sync_directory(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try: os.fsync(fd)
    finally: os.close(fd)


def atomic(path, data, mode):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.' + path.name + '.', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fchmod(stream.fileno(), mode)
            os.fsync(stream.fileno())
        os.replace(name, path)
        sync_directory(path.parent)
    finally:
        if os.path.exists(name): os.unlink(name)


def current(path):
    if path.is_symlink(): raise ValueError(f'Refusing symlink target: {path}')
    if not path.exists(): return None
    if not path.is_file(): raise ValueError(f'Not a regular file: {path}')
    return {'sha256': digest(path.read_bytes()), 'mode': stat.S_IMODE(path.stat().st_mode)}


def save(path, manifest):
    atomic(path, (json.dumps(manifest, indent=2) + '\n').encode(), 0o600)


def prepare(path, mapping):
    if path.exists(): raise ValueError('Manifest already exists')
    entries = []
    seen = set()
    for index, item in enumerate(mapping):
        source, target = Path(item['source']), Path(item['target'])
        if not source.is_absolute() or not target.is_absolute(): raise ValueError('Paths must be absolute')
        if target in seen: raise ValueError('Duplicate target')
        seen.add(target)
        previous = current(target)
        candidate = source.read_bytes()
        after = {'sha256': digest(candidate), 'mode': stat.S_IMODE(source.stat().st_mode)}
        entry = {'target': str(target), 'before': previous, 'after': after}
        for label, data in [('after', candidate), ('before', target.read_bytes() if previous else None)]:
            if data is not None:
                payload = path.parent / (path.name + '.files') / f'{index}.{label}'
                atomic(payload, data, 0o600)
                entry[label]['payload'] = str(payload)
        entries.append(entry)
    save(path, {'version': 1, 'state': 'prepared', 'entries': entries})


def signature(record):
    return {k: record[k] for k in ('sha256', 'mode')} if record else None


def execute(path, restore=False):
    manifest = json.loads(path.read_text())
    if manifest['version'] != 1: raise ValueError('Unsupported manifest')
    if not restore and manifest['state'] not in ('prepared', 'restored'):
        raise ValueError('Deployment already applied or interrupted; restore first')
    destination = 'before' if restore else 'after'
    # Validate every target and payload before writing the first file.
    for entry in manifest['entries']:
        actual = current(Path(entry['target']))
        allowed = [signature(entry['before'])]
        if restore: allowed.append(signature(entry['after']))
        if actual not in allowed: raise ValueError(f'Changed since snapshot: {entry["target"]}')
        record = entry[destination]
        if record and digest(Path(record['payload']).read_bytes()) != record['sha256']:
            raise ValueError(f'Corrupt payload: {entry["target"]}')
    manifest['state'] = 'restoring' if restore else 'applying'
    save(path, manifest)
    entries = reversed(manifest['entries']) if restore else manifest['entries']
    for entry in entries:
        target, record = Path(entry['target']), entry[destination]
        # Recheck immediately before replacing; never overwrite an intervening user edit.
        actual = current(target)
        if actual not in ([signature(entry['before']), signature(entry['after'])] if restore else [signature(entry['before'])]):
            raise ValueError(f'Changed during deployment: {target}')
        if record:
            atomic(target, Path(record['payload']).read_bytes(), record['mode'])
        elif target.exists():
            target.unlink()
            sync_directory(target.parent)
        if current(target) != signature(record): raise ValueError(f'Verification failed: {target}')
    manifest['state'] = 'restored' if restore else 'applied'
    save(path, manifest)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['prepare', 'apply', 'restore'])
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--mapping', type=Path)
    args = parser.parse_args()
    if args.action == 'prepare':
        if not args.mapping: parser.error('prepare requires --mapping')
        prepare(args.manifest.resolve(), json.loads(args.mapping.read_text()))
    else:
        with args.manifest.with_suffix(args.manifest.suffix + '.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            execute(args.manifest.resolve(), args.action == 'restore')
    print(json.dumps({'ok': True, 'action': args.action, 'manifest': str(args.manifest)}))


if __name__ == '__main__':
    try: main()
    except (OSError, ValueError, KeyError) as error:
        raise SystemExit(str(error))
