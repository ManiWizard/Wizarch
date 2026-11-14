"""Provider boundary: discover, validate, stage, install; remote checks are deferred."""
import hashlib, json, os, shutil, tempfile
from pathlib import Path
from urllib.parse import urlsplit
from .catalog import Catalog
from .storage import atomic, encoded, lock, read_json, sync_dir, MAX_JSON
from .validation import contained, validate

COLLECTION_LIMIT=256*1024*1024
MANAGED_LIMIT=512*1024*1024

def tree_size(root, exclude=None):
    return sum(p.stat().st_size for p in root.rglob('*') if p.is_file() and (exclude is None or not p.is_relative_to(exclude)))

def sync_tree(root):
    # Each copied file is already fsynced; persist all nested names bottom-up.
    for directory,_,_ in os.walk(root,topdown=False): sync_dir(Path(directory))

def durable_mkdir(path):
    missing=[]; parent=path
    while not parent.exists(): missing.append(parent); parent=parent.parent
    for directory in reversed(missing):
        directory.mkdir(exist_ok=True); sync_dir(directory); sync_dir(directory.parent)

class LocalProvider:
    def __init__(self, paths): self.paths=paths
    def discover(self, root):
        root=Path(root).resolve(strict=True)
        data=validate('catalog',read_json(root/'catalog.json'))
        ids=[p['id'] for p in data['packs']]
        if len(ids)!=len(set(ids)): raise ValueError('catalog.packs.id: duplicate IDs')
        packs=[]
        for p in data['packs']:
            if p['path']!='themes/'+p['id']+'/theme.json': raise ValueError('catalog.packs.path: use themes/<id>/theme.json')
            path=contained(root,p['path'])
            if p.get('manifestSha256') and hashlib.sha256(path.read_bytes()).hexdigest()!=p['manifestSha256']: raise ValueError('catalog.manifestSha256: mismatch')
            packs.append(path.parent)
        return root,data,packs
    def install(self, root):
        root,collection,folders=self.discover(root)
        source='local-'+hashlib.sha256(str(root).encode()).hexdigest()[:16]
        with lock(self.paths.state/'operation.lock'):
            catalog=Catalog(self.paths); packs=[catalog.load(folder,source) for folder in folders]
            if any(p['migrated'] for p in packs): raise ValueError('import: export legacy packs to schemaVersion 1 first')
            durable_mkdir(self.paths.data)
            registry=self.paths.data/'registry.json'; records=catalog.registry()
            with tempfile.TemporaryDirectory(prefix='.stage-',dir=self.paths.data) as tmp:
                stage=Path(tmp); atomic(stage/'catalog.json',collection)
                size=0
                for folder,pack in zip(folders,packs):
                    declared={'theme.json'}|{w['path'] for w in pack['wallpapers']}
                    declared |= {pack[k] for k in ('preview','logo') if pack.get(k) and not pack[k].startswith('file:')}
                    manifest=read_json(folder/'theme.json')
                    declared |= {manifest[k] for k in ('preview','logo') if manifest.get(k) and pack.get(k)}
                    if manifest['color']['type']=='roles': declared.add(manifest['color']['path'])
                    for relative in declared:
                        path=contained(folder,relative); size+=path.stat().st_size
                        if size>COLLECTION_LIMIT: raise ValueError('import: input collection exceeds 256 MiB staging budget')
                        target=stage/'themes'/pack['id']/relative; target.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(path,target)
                        with target.open('rb') as f: os.fsync(f.fileno())
                # Revalidate the staged copy, closing read/copy races and resolving seeds into offline exports.
                staged=[]
                for pack in packs:
                    folder=stage/'themes'/pack['id']; staged_pack=Catalog(self.paths).load(folder,source); staged.append(staged_pack)
                    if staged_pack['revision']!=pack['revision']: raise ValueError('import: content changed during staging; retry')
                    if pack['color']['type']=='keys':
                        manifest=read_json(folder/'theme.json'); atomic(folder/'colors.json',{'schemaVersion':1,'generator':pack['generator'],'schemes':pack['schemes']}); manifest['color']={'type':'roles','path':'colors.json'}; atomic(folder/'theme.json',manifest)
                # The installed collection is canonical compiled content, with hashes of its actual manifests.
                for entry in collection['packs']:
                    entry['manifestSha256']=hashlib.sha256((stage/entry['path']).read_bytes()).hexdigest()
                atomic(stage/'catalog.json',collection)
                compiled=[Catalog(self.paths).load(stage/'themes'/pack['id'],source) for pack in packs]
                revision=hashlib.sha256(json.dumps([p['revision'] for p in compiled],sort_keys=True).encode()).hexdigest()
                prospective={**records,source:revision}
                # Count bundled, diagnostic and replacement entries before changing registration.
                catalog.list(registry=prospective,source_roots={source:stage/'themes'},strict=True,presentation=False)
                registration=encoded(prospective)
                if len(registration)>MAX_JSON: raise ValueError('registry: exceeds JSON size limit')
                compiled_size=tree_size(stage)
                if compiled_size>COLLECTION_LIMIT: raise ValueError('import: compiled collection exceeds 256 MiB storage budget')
                destination=self.paths.data/source/revision; reuse=destination.exists()
                if reuse:
                    # Never trust/rewrite an existing immutable revision solely by directory name.
                    existing=[Catalog(self.paths).load(destination/'themes'/p['id'],source) for p in compiled]
                    if [p['revision'] for p in existing]!=[p['revision'] for p in compiled] or read_json(destination/'catalog.json')!=collection:
                        raise ValueError('import: installed immutable revision is damaged; retain it and repair explicitly')
                final_size=tree_size(self.paths.data,exclude=stage)-(registry.stat().st_size if registry.exists() else 0)+len(registration)+(0 if reuse else compiled_size)
                if final_size>MANAGED_LIMIT: raise ValueError('import: final managed storage exceeds 512 MiB budget')
                if not reuse:
                    sync_tree(stage)
                    durable_mkdir(destination.parent)
                    os.replace(stage,destination); sync_dir(destination.parent); sync_dir(self.paths.data)
                if records!=prospective: atomic(registry,registration)
                return {'ok':True,'source':source,'installed':[source+':'+p['id'] for p in packs],'revision':revision,'unchanged':reuse and records==prospective}

class GitHubProvider:
    operational=False
    def __getattr__(self, name): raise NotImplementedError('GitHub theme sources are deferred; no network transport is enabled')

def canonical_github_url(value):
    """Pure future contract parser; never downloads or registers a source."""
    import re
    u=urlsplit(value)
    if u.scheme!='https' or u.netloc!='github.com' or u.query or u.fragment or u.username or u.password: raise ValueError('source.url: public https://github.com only')
    if '//' in u.path: raise ValueError('source.url: ambiguous empty path component')
    parts=u.path.strip('/').split('/')
    if len(parts)!=2 or any(not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,99}',p) or p in ('.','..') for p in parts): raise ValueError('source.url: expected owner/repository, without extra paths')
    owner,repo=parts; repo=repo.removesuffix('.git')
    if not repo: raise ValueError('source.url: missing repository')
    url='https://github.com/'+owner.lower()+'/'+repo.lower()
    return url,'github-'+hashlib.sha256(url.encode()).hexdigest()[:16]
