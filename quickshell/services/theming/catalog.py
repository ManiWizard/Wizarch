import hashlib, json
from pathlib import Path
from .color import check_schemes, resolve
from .migration import legacy
from .storage import read_json, atomic, MAX_JSON
from .validation import asset, contained, validate, bounded_files

class Catalog:
    def __init__(self, paths): self.paths=paths; self.memo={}
    def registry(self, strict=True):
        path=self.paths.data/'registry.json'
        records=read_json(path) if path.exists() else {}
        if strict: self.validate_registry(records)
        else:
            if not isinstance(records,dict) or len(records)>128: raise ValueError('registry: exceeds 128 sources or is not an object')
            valid={}
            for source,revision in records.items():
                try: self.validate_registry({source:revision}); valid[source]=revision
                except ValueError: pass
            records=valid
        return records
    @staticmethod
    def validate_registry(records):
        import re
        if not isinstance(records,dict) or len(records)>128: raise ValueError('registry: exceeds 128 sources or is not an object')
        for source,revision in records.items():
            if not re.fullmatch('local-[a-f0-9]{16}',source) or not isinstance(revision,str) or not re.fullmatch('[a-f0-9]{64}',revision): raise ValueError('registry: invalid identity/revision')
    def roots(self):
        result=[('bundled',self.paths.base/'themes')]
        for source,revision in sorted(self.registry(strict=False).items()): result.append((source,self.paths.data/source/revision/'themes'))
        return result
    def load(self, folder, source='bundled'):
        root=folder.resolve()
        if not root.is_relative_to(folder.parent.resolve()): raise ValueError('pack: symlink escapes collection')
        files=bounded_files(root)
        if source!='bundled' and any(p.suffix.lower() in ('.qml','.lua','.py','.sh','.js','.so') or p.stat().st_mode & 0o111 for p in files): raise ValueError('pack: executable content/hooks are forbidden')
        if len(files)>128: raise ValueError('pack: exceeds 128 files')
        fingerprint=tuple((str(p.relative_to(root)),p.stat().st_size,p.stat().st_mtime_ns,p.stat().st_ctime_ns,p.stat().st_ino,p.resolve().as_posix()) for p in files)
        key=(str(root),source)
        disk_key=hashlib.sha256(json.dumps([2,key,fingerprint],sort_keys=True).encode()).hexdigest()
        disk=self.paths.cache/'packs'/(disk_key+'.json')
        if disk.exists():
            try:
                record=read_json(disk); cached=record['pack']
                if hashlib.sha256(json.dumps(cached,sort_keys=True).encode()).hexdigest()!=record['digest']: raise ValueError('cache integrity mismatch')
                manifest=validate('pack',read_json(contained(root,'theme.json')))
                validate('palette',{'schemaVersion':1,'schemes':cached['schemes']}); check_schemes(cached['schemes'])
                if any(cached.get(k)!=v for k,v in manifest.items() if k not in ('logo','preview','wallpapers')): raise ValueError('cache metadata mismatch')
                if cached['identity']!=source+':'+manifest['id']: raise ValueError('cache identity mismatch')
                if [{k:v for k,v in w.items() if k!='url'} for w in cached['wallpapers']]!=manifest['wallpapers']: raise ValueError('cache wallpaper mismatch')
                for wallpaper in cached['wallpapers']:
                    if contained(root,wallpaper['path']).as_uri()!=wallpaper['url']: raise ValueError('cache containment mismatch')
                return cached
            except (OSError,ValueError,KeyError): disk.unlink(missing_ok=True)
        if key in self.memo and self.memo[key][0]==fingerprint: return self.memo[key][1]
        data=read_json(contained(root,'theme.json'))
        migrated='schemaVersion' not in data
        if migrated: manifest,palette=legacy(data); check_schemes(palette['schemes'])
        else: manifest=validate('pack',data); palette=resolve(manifest,root,self.paths.cache)
        if manifest['id']!=folder.name: raise ValueError('pack.id: must match directory name')
        if manifest['defaultMode'] not in manifest['modes']: raise ValueError('pack.defaultMode: not a supported mode')
        ids=[w['id'] for w in manifest['wallpapers']]
        if len(set(ids))!=len(ids): raise ValueError('pack.wallpapers.id: duplicate IDs')
        if manifest['defaultWallpaper'] not in ids: raise ValueError('pack.defaultWallpaper: not a wallpaper ID')
        # SVG compatibility is restricted to shell-owned bundled assets, never new imports.
        svg = source=='bundled'
        declared_size=sum(contained(root,w['path']).stat().st_size for w in manifest['wallpapers'])
        if declared_size>256*1024*1024: raise ValueError('pack.wallpapers: exceeds 256 MiB content budget')
        wallpapers=[{**w,'url':asset(root,w['path'],svg)} for w in manifest['wallpapers']]
        optional={}; warnings=[]
        for kind in ('preview','logo'):
            optional[kind]=''
            if manifest.get(kind):
                try: optional[kind]=asset(root,manifest[kind],svg)
                except (OSError,ValueError) as e: warnings.append(kind+': '+str(e))
        declared={'theme.json'} | {w['path'] for w in manifest['wallpapers']}
        if not migrated and manifest['color']['type']=='roles': declared.add(manifest['color']['path'])
        declared |= {manifest[k] for k in ('logo','preview') if manifest.get(k) and optional[k]}
        hashed={relative:hashlib.sha256(contained(root,relative).read_bytes()).hexdigest() for relative in sorted(declared)}
        revision=hashlib.sha256(json.dumps({'files':hashed,'schemes':palette['schemes']},sort_keys=True).encode()).hexdigest()
        result={**manifest,**optional,'identity':source+':'+manifest['id'],'source':source,'schemes':palette['schemes'],'colors':palette['schemes'][manifest['defaultMode']],'wallpapers':wallpapers,'wallpaper':next(w['url'] for w in wallpapers if w['id']==manifest['defaultWallpaper']),'revision':revision,'valid':True,'diagnostics':warnings,'migrated':migrated,'generator':palette.get('generator')}
        record={"pack":result,"digest":hashlib.sha256(json.dumps(result,sort_keys=True).encode()).hexdigest()}
        # Runtime URLs/roles can expand an otherwise bounded portable manifest.
        if len((json.dumps(record,sort_keys=True,indent=2)+"\n").encode())<=MAX_JSON:atomic(disk,record)
        cached_files=sorted(disk.parent.glob("*.json"),key=lambda p:p.stat().st_mtime)
        for p in cached_files[:-128]: p.unlink(missing_ok=True)
        self.memo[key]=(fingerprint,result)
        if len(self.memo)>128: self.memo.pop(next(iter(self.memo)))
        return result
    @staticmethod
    def diagnostic(source,error):
        return {'id':'unavailable','identity':source+':unavailable','name':source,'description':'Unavailable theme source','valid':False,'diagnostics':[str(error)],'wallpapers':[],'wallpaper':'','logo':'','colors':{},'modes':[]}
    def list(self, registry=None, source_roots=None, strict=False, presentation=True):
        entries=[]
        registry_error=None; invalid_sources=[]
        try:
            path=self.paths.data/'registry.json'
            records=(read_json(path) if path.exists() else {}) if registry is None else registry
            if strict: self.validate_registry(records)
            else:
                if not isinstance(records,dict) or len(records)>128: raise ValueError('registry: exceeds 128 sources or is not an object')
                valid={}
                for source,revision in records.items():
                    try: self.validate_registry({source:revision}); valid[source]=revision
                    except ValueError as e: invalid_sources.append(self.diagnostic('registry-'+hashlib.sha256(source.encode()).hexdigest()[:16],str(e)+': '+source))
                records=valid
        except (OSError,ValueError) as e:
            if strict: raise
            records={}; registry_error=e
        roots=[('bundled',self.paths.base/'themes')]+[(source,(source_roots or {}).get(source,self.paths.data/source/revision/'themes')) for source,revision in sorted(records.items())]
        for source,root in roots:
            expected_hash={}; source_entries=[]
            try:
                if source=='bundled': folders=sorted(root.glob('*/theme.json'))
                else:
                    collection=validate('catalog',read_json(root.parent/'catalog.json'))
                    if any(p['path']!='themes/'+p['id']+'/theme.json' for p in collection['packs']): raise ValueError('catalog.packs.path: expected themes/<id>/theme.json')
                    folders=[root.parent/p['path'] for p in collection['packs']]
                    expected_hash={p['id']:p.get('manifestSha256') for p in collection['packs']}
                if len(folders)>128 or len(entries)+len(folders)>128: raise ValueError('catalog: exceeds 128 registered packs')
            except (OSError,ValueError) as e:
                if strict and 'exceeds 128' in str(e): raise
                if strict and len(entries)>=128: raise ValueError('catalog: exceeds 128 registered packs including diagnostics') from e
                diagnostic=self.diagnostic(source,e)
                if len(entries)<128: entries.append(diagnostic)
                elif entries: entries[0]={**entries[0],'diagnostics':entries[0]['diagnostics']+[source+': '+str(e)]}
                continue
            for path in folders:
                try:
                    expected=expected_hash.get(path.parent.name)
                    if expected and hashlib.sha256(path.read_bytes()).hexdigest()!=expected: raise ValueError('catalog.manifestSha256: installed manifest changed; re-import source')
                    source_entries.append(self.load(path.parent,source))
                except Exception as e:
                    diagnostic=self.diagnostic(source,e); diagnostic.update(id=path.parent.name,identity=source+':'+path.parent.name,name=path.parent.name); source_entries.append(diagnostic)
            entries.extend(source_entries)
        if registry_error is not None:
            if len(entries)<128: entries.append(self.diagnostic('registry',registry_error))
            elif entries: entries[0]={**entries[0],'diagnostics':entries[0]['diagnostics']+[str(registry_error)]}
        for diagnostic in invalid_sources:
            if len(entries)<128: entries.append(diagnostic)
            elif entries: entries[0]={**entries[0],'diagnostics':entries[0]['diagnostics']+diagnostic['diagnostics']}
        identities=[p['identity'] for p in entries]
        if len(identities)!=len(set(identities)): raise ValueError('catalog: duplicate identities')
        if presentation: entries=self.presentation(entries)
        return entries
    def presentation(self, entries):
        path=self.paths.config/'theme-overrides.json'
        if not path.exists(): return entries
        try: overrides=validate('overrides',read_json(path))['packs']
        except (OSError,ValueError) as e:
            if len(entries)<128: return entries+[self.diagnostic('overrides',e)]
            return [{**p,'diagnostics':p['diagnostics']+[str(e)]} for p in entries]
        result=[]
        for p in entries:
            override=overrides.get(p['identity'],{})
            if not p['valid'] or not override: result.append(p); continue
            try:
                check_schemes(override.get('schemes',{}))
                schemes={**p['schemes'],**override.get('schemes',{})}
                result.append({**p,'previewSchemes':schemes,'overrideMode':override.get('mode',''),'overrideWallpaper':override.get('wallpaperId','')})
            except ValueError as e: result.append({**p,'valid':False,'diagnostics':p['diagnostics']+[str(e)]})
        return result
    def get(self, identity):
        matches=[p for p in self.list() if p['identity']==identity or (':' not in identity and p['identity']=='bundled:'+identity)]
        if not matches: raise ValueError('selection.identity: theme is unavailable: '+identity)
        if not matches[0]['valid']: raise ValueError('; '.join(matches[0]['diagnostics']))
        return matches[0]
