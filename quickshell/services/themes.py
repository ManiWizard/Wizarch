#!/usr/bin/env python3
"""Wizard local theme CLI; all consumers use this boundary. No remote I/O."""
import os, sys
from pathlib import Path
# An explicitly configured interpreter wins, even in a partially provisioned caller.
configured=os.environ.get('WIZARCH_THEME_PYTHON')
runtime=Path(configured or str(Path(os.environ.get('XDG_DATA_HOME',str(Path.home()/'.local/share')))/'wizarch/theme-runtime/bin/python'))
if configured and (not runtime.is_absolute() or not runtime.is_file() or not os.access(runtime,os.X_OK)):
    print('{"ok":false,"error":"WIZARCH_THEME_PYTHON must name an existing executable absolute interpreter path."}');sys.exit(1)
if (configured or sys.prefix==sys.base_prefix) and runtime.is_file() and os.path.abspath(runtime)!=os.path.abspath(sys.executable):
    os.execv(str(runtime),[str(runtime),__file__,*sys.argv[1:]])
# Generation is never installed/downloaded by this command.
try:
    import jsonschema, PIL
except ImportError:
    if runtime.is_file() and str(runtime)!=sys.executable: os.execv(str(runtime),[str(runtime),__file__,*sys.argv[1:]])
    print('{"ok":false,"error":"Theme runtime unavailable. Install requirements-theme.txt in the documented local virtualenv; built-in QML fallback remains available."}')
    sys.exit(1)
import argparse, json
from theming.paths import Paths
from theming.catalog import Catalog
from theming.activation import Engine
from theming.color import generate
from theming.providers import LocalProvider
from theming.storage import atomic, read_json
from theming.watch import watch

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['list','refresh','watch','apply','init','bootstrap','recover','rollback','import','generate','import-palette','paths'])
    parser.add_argument('target',nargs='?'); parser.add_argument('--output'); parser.add_argument('--mode',choices=['light','dark']); parser.add_argument('--wallpaper'); parser.add_argument('--no-compositor',action='store_true')
    a=parser.parse_args(); paths=Paths(); engine=Engine(paths); live=not a.no_compositor
    if a.command=='paths': return {'ok':True,'active':str(paths.active),'selection':str(paths.selection)}
    if a.command in ('list','refresh'): return Catalog(paths).list()
    if a.command=='watch': watch(paths); return
    if a.command in ('apply','init'): return engine.apply(a.target,a.mode,a.wallpaper,live and a.command!='init')
    if a.command=='bootstrap': return engine.bootstrap(live)
    if a.command=='recover': return engine.recover(live)
    if a.command=='rollback': return engine.rollback(live)
    if a.command=='import': return LocalProvider(paths).install(a.target)
    if a.command=='import-palette':
        from theming.color import import_export
        if not a.output: raise ValueError('import-palette: --output is required')
        atomic(Path(a.output),import_export(read_json(Path(a.target))))
        return {'ok':True,'output':a.output,'compatibility':'background/onBackground/surfaceVariant were discarded; canonical surface/onSurface/surfaceContainerHighest are authoritative'}
    if a.command=='generate':
        manifest=read_json(Path(a.target)); from theming.validation import validate
        validate('pack',manifest)
        if manifest['color']['type']!='keys': raise ValueError('color.type: generation requires keys, not approved exports')
        color=manifest['color']; result=generate(color['keys'],color.get('contrast',0),color.get('variant')=='monochrome')
        result={**result,'schemes':{mode:result['schemes'][mode] for mode in manifest['modes']}}
        atomic(Path(a.target).parent/'colors.json',result); return {'ok':True,'output':str(Path(a.target).parent/'colors.json')}

if __name__=='__main__':
    try:
        result=main()
        if result is not None: print(json.dumps(result))
    except Exception as e:
        print(json.dumps({'ok':False,'error':str(e)[:2048]})); sys.exit(1)
