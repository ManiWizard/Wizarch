"""Review R1–R4 regressions: tiny public fixtures, sparse quotas, fake boundaries; no live/network writes."""
import copy,hashlib,json,os,shutil,subprocess,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'quickshell/services'))
from theming.paths import Paths
from theming.storage import atomic,encoded,read_json,MAX_JSON
from theming.catalog import Catalog
from theming.providers import LocalProvider,tree_size,MANAGED_LIMIT,COLLECTION_LIMIT
from theming.color import resolve
from theming.activation import Engine as RealEngine
from theming.appearance import NoAppearance
from functools import partial
Engine = partial(RealEngine, appearance=NoAppearance())
from PIL import Image

class Review(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name)
  self.paths=Paths(base=self.root/'shell',config=self.root/'config',state=self.root/'state',cache=self.root/'cache',data=self.root/'data',hypr=self.root/'hypr/colors.lua')
  self.palette=read_json(ROOT/'quickshell/themes/wizarch/colors.json')
  for name in ['wizarch','eclipse']:self.pack(self.paths.base/'themes'/name,name)
  self.provider=LocalProvider(self.paths)
 def pack(self,folder,name):
  folder.mkdir(parents=True,exist_ok=True);Image.new('RGB',(2,2),(18,18,18)).save(folder/'wall.png');atomic(folder/'colors.json',self.palette)
  atomic(folder/'theme.json',{'schemaVersion':1,'id':name,'name':name,'version':'1.0.0','modes':['light','dark'],'defaultMode':'dark','color':{'type':'roles','path':'colors.json'},'wallpapers':[{'id':'wall','name':'Wallpaper','path':'wall.png'}],'defaultWallpaper':'wall'})
 def collection(self,name='collection',count=1,seed=False):
  root=self.root/name;entries=[]
  for n in range(count):
   ident='pack-'+str(n);folder=root/'themes'/ident;self.pack(folder,ident)
   if seed:
    d=read_json(folder/'theme.json');d['color']={'type':'keys','keys':{'primary':'#6750a4','secondary':'#625b71','tertiary':'#7d5260'},'contrast':.5};atomic(folder/'theme.json',d);(folder/'colors.json').unlink()
   entries.append({'id':ident,'path':'themes/'+ident+'/theme.json'})
  atomic(root/'catalog.json',{'schemaVersion':1,'id':name,'name':name,'packs':entries});return root
 def test_r1_exact_boundary_replacement_and_overflow(self):
  root=self.collection(count=126);result=self.provider.install(root);registry=self.paths.data/'registry.json'
  self.assertEqual(len(Catalog(self.paths).list()),128)
  d=read_json(root/'themes/pack-0/theme.json');d['name']='New name';atomic(root/'themes/pack-0/theme.json',d)
  newer=self.provider.install(root);self.assertNotEqual(result['revision'],newer['revision']);self.assertEqual(len(Catalog(self.paths).list()),128)
  previous=registry.read_bytes();bad=self.collection('overflow',1)
  with self.assertRaisesRegex(ValueError,'128 registered'):self.provider.install(bad)
  self.assertEqual(registry.read_bytes(),previous);self.assertTrue(Catalog(self.paths).get('wizarch')['valid']);self.assertEqual(Catalog(self.paths).get(newer['source']+':pack-0')['name'],'New name')
  self.pack(root/'themes/pack-126','pack-126');catalog=read_json(root/'catalog.json');catalog['packs'].append({'id':'pack-126','path':'themes/pack-126/theme.json'});atomic(root/'catalog.json',catalog)
  with self.assertRaisesRegex(ValueError,'128 registered'):self.provider.install(root)
  self.assertEqual(registry.read_bytes(),previous);self.assertTrue(Catalog(self.paths).get(newer['source']+':pack-0')['valid'])
  # Replacement counts only the new source revision, never the retained old one.
  catalog=read_json(root/'catalog.json');catalog['packs']=catalog['packs'][:125];atomic(root/'catalog.json',catalog)
  self.provider.install(root);self.assertEqual(len(Catalog(self.paths).list()),127)
 def test_r1_127_pack_first_import_rejected_without_registration(self):
  root=self.collection(count=127)
  with self.assertRaisesRegex(ValueError,'128 registered'):self.provider.install(root)
  self.assertFalse((self.paths.data/'registry.json').exists());self.assertTrue(Catalog(self.paths).get('wizarch')['valid'])
 def test_r1_source_bounds_and_corrupt_source_isolation(self):
  root=self.collection();installed=self.provider.install(root);reg=self.paths.data/'registry.json';records=read_json(reg)
  bad='local-'+'a'*16;records[bad]='b'*64;atomic(reg,records)
  entries=Catalog(self.paths).list();self.assertTrue(Catalog(self.paths).get('wizarch')['valid']);self.assertTrue(Catalog(self.paths).get(installed['installed'][0])['valid']);self.assertTrue(any(p['identity']==bad+':unavailable' and not p['valid'] for p in entries))
  records[bad]='invalid-revision';atomic(reg,records);self.assertTrue(Catalog(self.paths).get(installed['installed'][0])['valid']);self.assertTrue(any(not p['valid'] and 'registry' in p['identity'] for p in Catalog(self.paths).list()))
  bad_catalog=self.paths.data/installed['source']/installed['revision']/'catalog.json';bad_catalog.write_text('{broken')
  self.assertTrue(Catalog(self.paths).get('eclipse')['valid'])
  records={'local-'+f'{n:016x}':'b'*64 for n in range(128)};atomic(reg,records);before=reg.read_bytes()
  with self.assertRaisesRegex(ValueError,'128 sources'):self.provider.install(self.collection('new-source'))
  self.assertEqual(reg.read_bytes(),before);self.assertTrue(Catalog(self.paths).get('wizarch')['valid'])
  reg.write_text('{broken');self.assertTrue(Catalog(self.paths).get('wizarch')['valid']);self.assertTrue(any(p['identity']=='registry:unavailable' for p in Catalog(self.paths).list()))
 def test_r2_bounded_read_and_growth_after_open(self):
  path=self.root/'large.json';path.write_bytes(b'x'*(1024*1024));original=os.read;consumed=[]
  def tracked(fd,n):
   raw=original(fd,n);consumed.append(len(raw));return raw
  with patch('theming.storage.os.read',side_effect=tracked):
   with self.assertRaisesRegex(ValueError,'size limit'):read_json(path)
  self.assertEqual(sum(consumed),MAX_JSON+1)
  path.write_bytes(b'{}');consumed=[];first=True
  def growing(fd,n):
   nonlocal first
   if first:
    first=False
    with path.open('ab') as f:f.write(b' '*(MAX_JSON*2))
   return tracked(fd,min(n,10000))
  with patch('theming.storage.os.read',side_effect=growing):
   with self.assertRaisesRegex(ValueError,'size limit'):read_json(path)
  self.assertEqual(sum(consumed),MAX_JSON+1)
 def test_r2_special_files_and_strict_parser(self):
  fifo=self.root/'catalog.json';os.mkfifo(fifo)
  with self.assertRaisesRegex(ValueError,'regular JSON'):read_json(fifo)
  with self.assertRaisesRegex(ValueError,'regular JSON'):self.provider.discover(self.root)
  with self.assertRaisesRegex(ValueError,'regular JSON'):read_json(self.root)
  for raw in ['{"x":1,"x":2}','{"x":1e309}','{"x":NaN}']:
   path=self.root/'invalid.json';path.write_text(raw)
   with self.assertRaises(ValueError):read_json(path)
 def test_r3_corrupt_generated_cache_variants_rebuilt(self):
  folder=self.collection(seed=True)/'themes/pack-0';manifest=read_json(folder/'theme.json');cache=self.paths.cache
  approved=resolve(manifest,folder,cache);path=next(cache.glob('*.json'))
  def wrong_generator(d):d['generator']['version']='wrong'
  def wrong_keys(d):d['generator']['keys']['primary']='#000000'
  def wrong_contrast(d):d['schemes']['dark']['onSurface']=d['schemes']['dark']['surface']
  def wrong_level(d):d['generator']['contrast']=1
  def wrong_modes(d):del d['schemes']['light']
  variants=['{broken','x'*(MAX_JSON+1),{'schemaVersion':2},wrong_generator,wrong_keys,wrong_level,wrong_modes,wrong_contrast]
  for variant in variants:
   bad=copy.deepcopy(approved)
   if callable(variant):variant(bad)
   else:bad=variant
   atomic(path,bad);self.assertEqual(resolve(manifest,folder,cache),approved);self.assertEqual(read_json(path),approved)
 def test_r3_unavailable_generation_preserves_commit_exports_not_disposable(self):
  engine=Engine(self.paths);engine.apply('wizarch',live=False);before=engine.capture()
  folder=self.collection(seed=True)/'themes/pack-0';manifest=read_json(folder/'theme.json');resolve(manifest,folder,self.paths.cache);path=next(self.paths.cache.glob('*.json'));path.write_text('{broken')
  with patch('theming.color.generate',side_effect=ImportError('MCU absent')):
   with self.assertRaisesRegex(ValueError,'generation unavailable'):resolve(manifest,folder,self.paths.cache)
  self.assertFalse(path.exists());self.assertEqual(engine.capture(),before)
  roles=read_json(self.paths.base/'themes/wizarch/theme.json');export=self.paths.base/'themes/wizarch/colors.json';export.write_text('{broken')
  with self.assertRaises(ValueError):resolve(roles,export.parent,self.paths.cache)
  self.assertEqual(export.read_text(),'{broken')
 def test_pack_cache_corruption_still_recovers(self):
  approved=Catalog(self.paths).get('wizarch');paths=list((self.paths.cache/'packs').glob('*.json'))
  for p in paths:p.write_text('{broken')
  self.assertEqual(Catalog(self.paths).get('wizarch'),approved)
 def test_r4_final_compiled_quota_seed_export_and_idempotence(self):
  for seed in [False,True]:
   with self.subTest(seed=seed):
    paths=Paths(base=self.paths.base,config=self.paths.config,state=self.root/('quota-state-'+str(seed)),cache=self.root/('quota-cache-'+str(seed)),data=self.root/('quota-data-'+str(seed)),hypr=self.paths.hypr)
    provider=LocalProvider(paths);root=self.collection('quota-'+str(seed).lower(),seed=seed);result=provider.install(root)
    footprint=tree_size(paths.data);sentinel=paths.data/'retained-sparse';sentinel.touch()
    with sentinel.open('r+b') as f:f.truncate(MANAGED_LIMIT-footprint)
    before=(paths.data/'registry.json').read_bytes();self.assertEqual(tree_size(paths.data),MANAGED_LIMIT)
    self.assertTrue(provider.install(root)['unchanged']);self.assertEqual(tree_size(paths.data),MANAGED_LIMIT)
    manifest=root/'themes/pack-0/theme.json';value=read_json(manifest);value['name']='New revision';atomic(manifest,value)
    with self.assertRaisesRegex(ValueError,'final managed'):provider.install(root)
    self.assertEqual((paths.data/'registry.json').read_bytes(),before);self.assertTrue(Catalog(paths).get(result['installed'][0])['valid']);self.assertEqual(tree_size(paths.data),MANAGED_LIMIT)
    # A fresh destination one byte above the exact final compiled+registry footprint fails.
    shutil.rmtree(paths.data);paths.data.mkdir();sentinel=paths.data/'retained-sparse';sentinel.touch()
    with sentinel.open('r+b') as f:f.truncate(MANAGED_LIMIT-footprint+1)
    atomic(manifest,{**value,'name':'pack-0'})
    with self.assertRaisesRegex(ValueError,'final managed'):provider.install(root)
    self.assertFalse((paths.data/'registry.json').exists());self.assertEqual(tree_size(paths.data),MANAGED_LIMIT-footprint+1)
 def test_r4_compiled_collection_bound_and_directory_durability(self):
  root=self.collection(seed=True);syncs=[]
  from theming import providers
  original=providers.sync_dir
  with patch('theming.providers.sync_dir',side_effect=lambda p:(syncs.append(Path(p)),original(p))[1]):result=self.provider.install(root)
  source=self.paths.data/result['source'];destination=source/result['revision']
  self.assertIn(self.paths.data,syncs);self.assertIn(source,syncs)
  self.assertIn(self.paths.data.parent,syncs)
  staged=[p for p in syncs if '.stage-' in str(p)];self.assertTrue(any(p.name=='pack-0' for p in staged));self.assertLess(next(i for i,p in enumerate(staged) if p.name=='pack-0'),len(staged)-1)
  fresh=self.collection('compiled-too-large',seed=True)
  with patch('theming.providers.COLLECTION_LIMIT',tree_size(fresh)+100):
   before=(self.paths.data/'registry.json').read_bytes()
   with self.assertRaisesRegex(ValueError,'compiled collection'):self.provider.install(fresh)
   self.assertEqual((self.paths.data/'registry.json').read_bytes(),before)
 def test_explicit_runtime_wins_before_imports_and_partial_caller(self):
  executable=self.root/'configured-python';executable.write_text('#!/bin/sh\nprintf \'{"configured":true}\\n\'\n');executable.chmod(0o755)
  # Caller already has jsonschema/Pillow; explicit interpreter selection must still run.
  env=dict(os.environ,WIZARCH_THEME_PYTHON=str(executable));result=subprocess.run([sys.executable,str(ROOT/'quickshell/services/themes.py'),'generate','unused'],env=env,capture_output=True,text=True,timeout=5)
  self.assertEqual(result.returncode,0);self.assertTrue(json.loads(result.stdout)['configured'])
  env['WIZARCH_THEME_PYTHON']=str(self.root/'missing');result=subprocess.run([sys.executable,str(ROOT/'quickshell/services/themes.py'),'list'],env=env,capture_output=True,text=True,timeout=5);self.assertNotEqual(result.returncode,0);self.assertIn('WIZARCH_THEME_PYTHON',result.stdout)
 def test_generation_with_simulated_partial_caller_and_complete_runtime(self):
  root=self.collection('partial-caller',seed=True);manifest=root/'themes/pack-0/theme.json'
  interpreter=self.root/'complete-runtime';interpreter.write_text('#!'+sys.executable+'\nimport os,sys\nos.environ.pop("WIZARCH_THEME_PYTHON",None)\nos.execv('+repr(sys.executable)+',['+repr(sys.executable)+',*sys.argv[1:]])\n');interpreter.chmod(0o755)
  caller='''import builtins,jsonschema,PIL,runpy,sys
original=builtins.__import__
def partial(name,*args,**kwargs):
 if name=="material_color_utilities":raise ImportError("simulated partial interpreter")
 return original(name,*args,**kwargs)
builtins.__import__=partial
sys.argv=[sys.argv[1],"generate",sys.argv[2]]
runpy.run_path(sys.argv[0],run_name="__main__")
'''
  result=subprocess.run([sys.executable,'-c',caller,str(ROOT/'quickshell/services/themes.py'),str(manifest)],env=dict(os.environ,WIZARCH_THEME_PYTHON=str(interpreter)),capture_output=True,text=True,timeout=10)
  self.assertEqual(result.returncode,0,result.stdout+result.stderr);self.assertTrue(json.loads(result.stdout)['ok']);self.assertEqual(read_json(manifest.parent/'colors.json')['generator']['version'],'0.2.6')
 def test_preview_override_palette_matches_activation_and_refresh(self):
  override=read_json(ROOT/'quickshell/themes/eclipse/colors.json')['schemes'];atomic(self.paths.config/'theme-overrides.json',{'schemaVersion':1,'packs':{'bundled:eclipse':{'schemes':override,'mode':'light','wallpaperId':'wall'}}})
  engine=Engine(self.paths);engine.apply('wizarch',live=False);pack=Catalog(self.paths).get('eclipse');snapshot=engine.snapshot('eclipse')
  self.assertEqual(pack['previewSchemes']['light'],snapshot['colors']);self.assertEqual(pack['overrideMode'],snapshot['mode']);self.assertEqual(pack['overrideWallpaper'],snapshot['wallpaperId']);self.assertEqual(engine.current()['identity'],'bundled:wizarch')
  engine.apply('eclipse',live=False);self.assertEqual(engine.current()['colors'],pack['previewSchemes']['light'])

if __name__=='__main__':unittest.main(verbosity=2)
