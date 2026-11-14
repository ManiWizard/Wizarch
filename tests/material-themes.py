"""No live files/compositor/network: schemas, providers and fault-injected transactions."""
import copy, json, multiprocessing, os, shutil, sys, tempfile, time, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; sys.path.insert(0,str(ROOT/'quickshell/services'))
from theming.paths import Paths
from theming.validation import ROLES, validate, asset, contained
from theming.color import generate, contrast_results
from theming.catalog import Catalog
from theming.providers import LocalProvider, canonical_github_url
from theming.activation import Engine as RealEngine, lua
from theming.appearance import NoAppearance
from functools import partial
Engine = partial(RealEngine, appearance=NoAppearance())
from theming.storage import atomic, read_json
from theming.migration import legacy

class Fake:
    def __init__(self,reject=False,rollback_reject=False): self.reloads=0; self.reject=reject; self.rollback_reject=rollback_reject
    def errors(self): return {'existing unrelated error'}
    def reload(self): self.reloads+=1
    def check(self,baseline):
        assert baseline=={'existing unrelated error'}
        if self.reject and (self.reloads==1 or self.rollback_reject): raise RuntimeError('injected compositor rejection')

class Pipeline(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup); self.root=Path(self.tmp.name)
        base=self.root/'shell'; shutil.copytree(ROOT/'quickshell/themes',base/'themes');(base/'state').mkdir();
        # A distinct public fixture exercises transactions without requiring Eclipse's private art.
        shutil.copytree(base/'themes/wizarch',base/'themes/fixture')
        fixture=read_json(base/'themes/fixture/theme.json');fixture.update(id='fixture',name='Transaction fixture');atomic(base/'themes/fixture/theme.json',fixture)
        self.paths=Paths(base=base,config=self.root/'config',state=self.root/'state',cache=self.root/'cache',data=self.root/'data',hypr=self.root/'hypr/theme.lua')
        self.engine=Engine(self.paths,Fake()); self.catalog=Catalog(self.paths)
    def first(self):return self.engine.apply('wizarch',live=False)
    def test_bundles_exact_roles_and_contrast(self):
        for p in self.catalog.list():
            if p['id']=='eclipse' and not (self.paths.base/'themes/eclipse/assets/wallpaper.jpg').exists():
                self.assertFalse(p['valid']);self.assertTrue(p['diagnostics']);continue
            self.assertTrue(p['valid'],p['diagnostics']);self.assertEqual(set(p['modes']),{'light','dark'})
            for c in p['schemes'].values():
                self.assertEqual(set(c),set(ROLES))
                for r in contrast_results(c): self.assertGreaterEqual(r['ratio']+1e-6,r['minimum'],r)
    def test_schema_bad_types_fields_versions_modes_colors(self):
        manifest=read_json(self.paths.base/'themes/wizarch/theme.json')
        for field,value in [('schemaVersion',True),('schemaVersion',1.0),('schemaVersion',2),('modes',['sepia']),('version',False),('name',[]),('colours',{})]:
            d=copy.deepcopy(manifest);d[field]=value
            with self.assertRaises(ValueError):validate('pack',d)
        colors=read_json(self.paths.base/'themes/wizarch/colors.json');del colors['schemes']['dark']['surface']
        with self.assertRaisesRegex(ValueError,'surface'):validate('palette',colors)
    def test_seed_determinism_three_keys_and_higher_contrast(self):
        keys={'primary':'#6750a4','secondary':'#625b71','tertiary':'#7d5260'}
        a=generate(keys);self.assertEqual(a,generate(keys))
        for family in keys:
            changed={**keys,family:'#147a53'}; b=generate(changed)
            self.assertNotEqual(a['schemes']['dark'][family],b['schemes']['dark'][family])
            for other in keys.keys()-{family}:
                self.assertEqual(a['schemes']['dark'][other],b['schemes']['dark'][other])
        for level in [.5,1]:generate(keys,level)
        with self.assertRaises(ValueError):generate(keys,2)
    def test_exports_preserved_no_regeneration(self):
        p=self.catalog.get('wizarch');export=read_json(self.paths.base/'themes/wizarch/colors.json')
        self.assertEqual(p['schemes'],export['schemes'])
    def test_safe_paths_symlinks_assets(self):
        root=self.paths.base/'themes/wizarch';outside=self.root/'outside.png';outside.write_bytes(b'bad');(root/'escape.png').symlink_to(outside)
        for path in ['../outside.png','/etc/passwd','escape.png','assets/../colors.json']:
            with self.assertRaises((ValueError,FileNotFoundError)):contained(root,path)
        with self.assertRaises(ValueError):asset(root,'assets/logo.svg')
        (root/'broken.png').write_bytes(b'bad')
        with self.assertRaises(Exception):asset(root,'broken.png')
        from PIL import Image
        Image.new('L',(9000,1)).save(root/'huge.png')
        with self.assertRaises(ValueError):asset(root,'huge.png')
    def test_missing_optional_and_required_are_visible(self):
        root=self.paths.base/'themes/wizarch';d=read_json(root/'theme.json');d['preview']='missing.png';atomic(root/'theme.json',d)
        p=self.catalog.get('wizarch');self.assertTrue(p['diagnostics']);self.assertTrue(p['valid'])
        (root/'assets/wizarch-arcane-4k.png').unlink()
        p=next(p for p in self.catalog.list() if p['id']=='wizarch');self.assertFalse(p['valid']);self.assertTrue(p['diagnostics'])
    def test_catalog_refresh_invalidation(self):
        before=self.catalog.get('wizarch');root=self.paths.base/'themes/wizarch';d=read_json(root/'theme.json');d['name']='Changed';atomic(root/'theme.json',d)
        after=self.catalog.get('wizarch');self.assertEqual(after['name'],'Changed');self.assertNotEqual(before['revision'],after['revision'])
    def test_event_catalog_watcher_ignores_activation_state(self):
        import subprocess,select
        script="import sys,json;from pathlib import Path;sys.path.insert(0,sys.argv[1]);from theming.paths import Paths;from theming.watch import watch;watch(Paths(**{k:Path(v) for k,v in json.loads(sys.argv[2]).items()}))"
        child=subprocess.Popen([sys.executable,'-u','-c',script,str(ROOT/'quickshell/services'),json.dumps({k:str(v) for k,v in vars(self.paths).items()})],stdout=subprocess.PIPE,text=True)
        def cleanup():
            child.terminate();child.wait(timeout=5);child.stdout.close()
        self.addCleanup(cleanup)
        self.assertTrue(select.select([child.stdout],[],[],10)[0]);self.assertTrue(json.loads(child.stdout.readline())['ok'])
        root=self.paths.base/'themes/wizarch';d=read_json(root/'theme.json');d['name']='Watched';atomic(root/'theme.json',d)
        self.assertTrue(select.select([child.stdout],[],[],5)[0]);catalog=json.loads(child.stdout.readline())['catalog'];self.assertEqual(next(p for p in catalog if p['id']=='wizarch')['name'],'Watched')
        self.first();self.assertFalse(select.select([child.stdout],[],[],.35)[0],'activation state must not rescan the catalog')
        schemes=read_json(self.paths.base/'themes/eclipse/colors.json')['schemes']
        atomic(self.paths.config/'theme-overrides.json',{'schemaVersion':1,'packs':{'bundled:wizarch':{'schemes':schemes}}})
        self.assertTrue(select.select([child.stdout],[],[],5)[0]);catalog=json.loads(child.stdout.readline())['catalog'];self.assertEqual(next(p for p in catalog if p['id']=='wizarch')['previewSchemes'],schemes)
    def test_local_import_and_duplicate_ids(self):
        source=self.root/'collection';shutil.copytree(ROOT/'examples/material-collection',source)
        provider=LocalProvider(self.paths); result=provider.install(source);p=self.catalog.get(result['installed'][0]);self.assertTrue(p['valid']);self.assertEqual(p['color']['type'],'roles')
        second=provider.install(source);self.assertEqual(second['revision'],result['revision'])
        d=read_json(source/'catalog.json');d['packs'].append({**d['packs'][0],'path':'themes/other/theme.json'});atomic(source/'catalog.json',d)
        with self.assertRaisesRegex(ValueError,'duplicate'):provider.install(source)
    def test_seed_pack_single_mode_matches_schema_and_import(self):
        source=self.root/'single-mode';shutil.copytree(ROOT/'examples/material-collection',source)
        path=source/'themes/aurora/theme.json';d=read_json(path);d['modes']=['dark'];d['defaultMode']='dark';atomic(path,d)
        result=LocalProvider(self.paths).install(source);pack=self.catalog.get(result['installed'][0]);self.assertEqual(set(pack['schemes']),{'dark'})
        self.engine.apply(pack['identity'],live=False);before=self.engine.current();self.assertEqual(before['mode'],'dark')
        with self.assertRaisesRegex(ValueError,'mode'):self.engine.apply(pack['identity'],mode='light',live=False)
        self.assertEqual(self.engine.current(),before)
    def test_independent_mode_wallpaper_persistence_and_idempotence(self):
        self.first(); a=self.engine.current(); self.engine.apply('wizarch',wallpaper='nocturne',live=False);b=self.engine.current()
        self.assertEqual(a['colors'],b['colors']);self.assertEqual(b['wallpaperId'],'nocturne')
        self.engine.apply('wizarch',mode='light',live=False);c=self.engine.current();self.assertEqual(c['wallpaperId'],'nocturne')
        self.assertEqual(Engine(self.paths,Fake()).current(),c);self.assertTrue(self.engine.apply('wizarch',live=False)['unchanged'])
        atomic(self.paths.selection,{'bad':True}); self.engine.recover(False);self.assertEqual(read_json(self.paths.selection),c['selection'])
    def test_corrupt_active_last_good(self):
        self.first();good=self.engine.current();self.paths.active.write_text('{bad');self.engine.recover(False);self.assertEqual(self.engine.current(),good)
    def test_invalid_requests_preserve_current(self):
        self.first();before=self.paths.active.read_bytes()
        for args in [('missing',None,None),('wizarch','sepia',None),('wizarch','light','missing')]:
            with self.assertRaises(ValueError):self.engine.apply(*args,live=False)
            self.assertEqual(before,self.paths.active.read_bytes())
    def test_removed_wallpaper_keeps_compatible_choice_or_default(self):
        self.first();self.engine.apply('wizarch',wallpaper='nocturne',live=False);d=read_json(self.paths.base/'themes/wizarch/theme.json');d['wallpapers']=d['wallpapers'][:1];atomic(self.paths.base/'themes/wizarch/theme.json',d)
        self.engine.apply('wizarch',mode='light',live=False);self.assertEqual(self.engine.current()['wallpaperId'],'arcane')
    def test_compositor_rejection_and_rollback_failure(self):
        self.first();before=self.engine.capture()
        for rollback in [False,True]:
            engine=Engine(self.paths,Fake(True,rollback))
            with self.assertRaisesRegex(RuntimeError,'rejection'):engine.apply('fixture',live=True)
            self.assertEqual(before,engine.capture())
            if rollback:self.assertTrue((self.paths.state/'journal.json').exists());self.engine.recover(False)
        self.assertFalse((self.paths.state/'journal.json').exists())
    def test_interrupt_at_each_phase_and_startup_reconcile(self):
        self.first();original=self.engine.current()
        for phase in ['prepared','compositor-written','compositor-accepted','selection-written','published']:
            self.engine.apply('wizarch',live=False)
            def fault(actual):
                if phase==actual:raise SystemExit('simulated SIGKILL')
            engine=Engine(self.paths,Fake(),fault)
            with self.assertRaises(SystemExit):engine.apply('fixture',live=False)
            self.engine.recover(False)
            self.assertEqual(self.engine.current()['identity'],'bundled:fixture' if phase=='published' else 'bundled:wizarch')
            self.assertFalse((self.paths.state/'journal.json').exists())
    def test_post_commit_finalization_warning_and_recovery_history(self):
        self.first();prior=self.engine.current()
        def fault(phase):
            if phase=='published':raise OSError('injected fsync failure')
        engine=Engine(self.paths,Fake(),fault);result=engine.apply('fixture',live=False)
        self.assertTrue(result['ok']);self.assertIn('warning',result);self.assertEqual(engine.current()['id'],'fixture')
        self.engine.recover(False);self.engine.rollback(False);self.assertEqual(self.engine.current(),prior)
    def test_export_conversion_and_conflicting_input(self):
        from theming.color import import_export
        export=read_json(self.paths.base/'themes/wizarch/colors.json');before=copy.deepcopy(export)
        for c in export['schemes'].values():c.update(background=c['surface'],onBackground=c['onSurface'],surfaceVariant=c['surfaceContainerHighest'])
        self.assertEqual(import_export(export),before)
        manifest=read_json(self.paths.base/'themes/wizarch/theme.json');manifest['color']['keys']={'primary':'#6750a4'}
        with self.assertRaises(ValueError):validate('pack',manifest)
    def test_rollback_restores_snapshot_and_color_only_lua(self):
        self.first();a=self.engine.current();self.engine.apply('fixture',live=False);self.engine.rollback(False);self.assertEqual(self.engine.current(),a)
        for forbidden in ['border_size','rounding','shadow','blur']:self.assertNotIn(forbidden,lua(a['colors']).splitlines()[1])
    def test_migration_corrupt_and_unavailable_selection(self):
        old=read_json(ROOT/'tests/fixtures/material-legacy/wizarch.json');m,p=legacy(old);self.assertEqual(m['id'],'wizarch');self.assertEqual(p['schemes']['dark'],{r:old['colors'][r] for r in ROLES})
        atomic(self.paths.base/'state/active.json',{'id':'fixture'});self.engine.bootstrap(False);self.assertEqual(self.engine.current()['id'],'fixture')
        self.paths.active.unlink();self.paths.selection.unlink();(self.paths.state/'last-good.json').unlink();atomic(self.paths.base/'state/active.json',{'id':'missing'})
        with self.assertRaisesRegex(ValueError,'retained'):self.engine.bootstrap(False)
    def test_schema_source_fixtures_only(self):
        url,source=canonical_github_url('https://github.com/Example/Themes.git/');self.assertEqual(url,'https://github.com/example/themes')
        for url in ['https://other.com/a/b','https://x@y:password@github.com/a/b','https://github.com/a/b/tree/main','https://github.com/a/../b','ssh://github.com/a/b','https://github.com/a/b?ref=a']:
            with self.assertRaises(ValueError):canonical_github_url(url)
    def test_independent_overrides_and_invalid_override(self):
        self.first();d={'schemaVersion':1,'packs':{'bundled:wizarch':{'mode':'light','wallpaperId':'nocturne'}}};atomic(self.paths.config/'theme-overrides.json',d)
        self.engine.apply('wizarch',live=False);self.assertEqual(self.engine.current()['mode'],'light');self.assertEqual(self.engine.current()['wallpaperId'],'nocturne')
        self.engine.apply('wizarch',mode='dark',wallpaper='arcane',live=False);self.assertEqual(self.engine.current()['mode'],'dark')
        self.assertEqual(read_json(self.paths.config/'theme-overrides.json'),d)
        d['packs']['bundled:wizarch']['wallpaperId']='missing';atomic(self.paths.config/'theme-overrides.json',d);before=self.engine.capture()
        with self.assertRaises(ValueError):self.engine.apply('wizarch',live=False)
        self.assertEqual(before,self.engine.capture())
    def test_preference_strict_bounds_enums_booleans(self):
        import subprocess
        env=dict(os.environ,XDG_CONFIG_HOME=str(self.root/'prefs'))
        for key,value in [('systemVolume',True),('systemVolume',101),('borderThickness',0),('borderRadius',41),('windowSpacing',-1),('revealMode','glass'),('audioMode','quiet'),('alertPattern','infinite')]:
            r=subprocess.run([sys.executable,str(ROOT/'quickshell/services/preferences.py'),'set',key,json.dumps(value)],env=env,capture_output=True)
            self.assertNotEqual(r.returncode,0,(key,value))
    def test_missing_private_asset_diagnostic(self):
        (self.paths.base/'themes/eclipse/assets/wallpaper.jpg').unlink(missing_ok=True)
        p=next(p for p in self.catalog.list() if p['id']=='eclipse');self.assertFalse(p['valid']);self.assertTrue(p['diagnostics'])
    def test_json_overflow_and_large_metadata_cache_bound(self):
        bad=self.root/'bad.json'
        for text in ['{"value":NaN}','{"value":Infinity}','{"value":1e309}','{"value":-1e309}','{"value":1,"value":2}']:
            bad.write_text(text)
            with self.assertRaises(ValueError):read_json(bad)
        with self.assertRaises(ValueError):atomic(bad,{'value':float('inf')})
        root=self.paths.base/'themes/wizarch';d=read_json(root/'theme.json');d['extensions']={'tests.blob':'x'*258000};atomic(root/'theme.json',d)
        self.assertLessEqual((root/'theme.json').stat().st_size,256*1024)
        self.assertTrue(self.catalog.get('wizarch')['valid'])
        self.assertTrue(all(p.stat().st_size<=256*1024 for p in (self.paths.cache/'packs').glob('*.json')))
    def test_corrupt_cache_revalidated(self):
        self.catalog.get('wizarch');cache=next((self.paths.cache/'packs').glob('*.json'));cache.write_text('{bad')
        self.assertTrue(Catalog(self.paths).get('wizarch')['valid'])
    def test_cross_process_serialization(self):
        self.first();script='''import sys,json,time
sys.path.insert(0,sys.argv[1]);from theming.paths import Paths;from theming.activation import Engine as RealEngine
from theming.appearance import NoAppearance
from functools import partial
Engine = partial(RealEngine, appearance=NoAppearance())
from pathlib import Path
p=Paths(**{k:Path(v) for k,v in json.loads(sys.argv[2]).items()})
Engine(p).apply(sys.argv[3],live=False)
'''
        import subprocess
        p=json.dumps({k:str(v) for k,v in vars(self.paths).items()});children=[subprocess.Popen([sys.executable,'-c',script,str(ROOT/'quickshell/services'),p,name]) for name in ['fixture','wizarch','fixture','wizarch']]
        for child in children:self.assertEqual(child.wait(timeout=15),0)
        c=self.engine.current();self.assertEqual(c['selection'],read_json(self.paths.selection));self.assertEqual(self.paths.hypr.read_text(),lua(c['colors']))

if __name__=='__main__':unittest.main(verbosity=2)
