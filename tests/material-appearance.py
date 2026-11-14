"""Isolated desktop adapter/transaction regressions. Never touches the user bus."""
import copy, json, shutil, subprocess, sys, tempfile, unittest
from pathlib import Path
from types import SimpleNamespace
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'quickshell/services'))
from theming.activation import Engine
from theming.appearance import DesktopAppearance, NoAppearance
from theming.paths import Paths
from theming.storage import read_json, atomic

class Settings:
    def __init__(self):
        self.values={'color-scheme':'prefer-dark','gtk-theme':'Adwaita-dark'}
        self.calls=[];self.fail=None;self.stderr='';self.locked=False
    def run(self,args,**kwargs):
        assert kwargs['timeout']==5 and kwargs['check']
        assert args[:1]==['gsettings'] and args[2]=='org.gnome.desktop.interface'
        self.calls.append(args);action,key=args[1],args[3]
        if self.fail==action: raise subprocess.CalledProcessError(1,args)
        if action=='get': out=repr(self.values[key])
        elif action=='writable': out='false' if self.locked else 'true'
        else:
            assert action=='set'
            import ast
            if not self.stderr:self.values[key]=ast.literal_eval(args[4])
            out=''
        return SimpleNamespace(stdout=out,stderr=self.stderr if action=='set' else '')

class Compositor:
    def errors(self):return set()
    def reload(self):pass
    def check(self,baseline):pass

class AppearanceTests(unittest.TestCase):
    def setUp(self):
        self.backend=Settings();self.appearance=None
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        root=Path(self.temp.name);self.appearance=DesktopAppearance(self.backend.run, root/'desktop-themes', root/'gtk-3.0/settings.ini');base=root/'shell';shutil.copytree(ROOT/'quickshell/themes/wizarch',base/'themes/wizarch')
        self.paths=Paths(base=base,config=root/'config',state=root/'state',cache=root/'cache',data=root/'data',hypr=root/'hypr/colors.lua')
        self.engine=Engine(self.paths,Compositor(),appearance=self.appearance)
        self.engine.apply('wizarch','dark',live=False)
    def test_two_way_adwaita_and_idempotence(self):
        self.appearance.apply('light');self.assertEqual(self.backend.values,{'color-scheme':'prefer-light','gtk-theme':'Wizard-Adwaita'})
        self.backend.calls=[];self.appearance.apply('light');self.assertFalse(any(c[1]=='set' for c in self.backend.calls))
        self.appearance.apply('dark');self.assertEqual(self.backend.values,{'color-scheme':'prefer-dark','gtk-theme':'Wizard-Adwaita-dark'})
    def test_custom_theme_preserved_and_arguments_not_shell(self):
        self.backend.values['gtk-theme']='Custom $(should-not-run)'
        self.appearance.apply('light');self.assertEqual(self.backend.values['gtk-theme'],'Custom $(should-not-run)')
        prior=self.appearance.capture();self.appearance.restore(prior)
        self.assertTrue(all(isinstance(c,list) for c in self.backend.calls))
    def test_invalid_mode_and_locked_policy(self):
        with self.assertRaises(ValueError):self.appearance.apply('sepia')
        self.backend.locked=True
        with self.assertRaisesRegex(RuntimeError,'policy'):self.appearance.capture()
    def test_dconf_failure_exit_zero_and_timeout(self):
        self.backend.stderr='dconf-WARNING: failed to commit changes'
        with self.assertRaisesRegex(RuntimeError,'failed to commit'):self.appearance.apply('light')
        self.backend.fail='get'
        with self.assertRaisesRegex(RuntimeError,'session D-Bus'):self.appearance.capture()
    def test_mode_wallpaper_and_same_revision_repair(self):
        self.engine.apply('wizarch','light',live=True)
        self.assertEqual(self.backend.values['color-scheme'],'prefer-light')
        original=self.engine.current();self.engine.apply('wizarch',wallpaper='nocturne',live=True)
        self.assertEqual(self.engine.current()['mode'],'light');self.assertEqual(original['colors'],self.engine.current()['colors'])
        self.backend.values['color-scheme']='prefer-dark'
        self.assertTrue(self.engine.apply('wizarch',live=True)['unchanged'])
        self.assertEqual(self.backend.values['color-scheme'],'prefer-light')
    def test_rollback_and_restart(self):
        self.engine.apply('wizarch','light',live=True);self.engine.rollback(live=True)
        self.assertEqual(self.backend.values['color-scheme'],'prefer-dark')
        self.backend.values['color-scheme']='prefer-light'
        self.engine.bootstrap(live=True);self.assertEqual(self.backend.values['color-scheme'],'prefer-dark')
    def test_interruption_before_and_after_publication(self):
        for phase in ('appearance-applied','selection-written','published'):
            self.engine.apply('wizarch','dark',live=True)
            def fault(actual):
                if actual==phase:raise SystemExit('interrupt')
            engine=Engine(self.paths,Compositor(),fault,self.appearance)
            with self.assertRaises(SystemExit):engine.apply('wizarch','light',live=True)
            self.engine.recover(live=True)
            mode='light' if phase=='published' else 'dark'
            self.assertEqual(self.engine.current()['mode'],mode)
            self.assertEqual(self.backend.values['color-scheme'],'prefer-'+mode)
            self.assertFalse((self.paths.state/'journal.json').exists())
    def test_partial_desktop_write_failure_restores_both(self):
        before=self.engine.capture();prior=copy.deepcopy(self.backend.values);normal=self.backend.run
        def fail(args,**kwargs):
            if args[1]=='set' and args[3]=='gtk-theme' and args[4]=="'Wizard-Adwaita'":
                raise subprocess.CalledProcessError(1,args)
            return normal(args,**kwargs)
        self.appearance.run=fail
        with self.assertRaisesRegex(RuntimeError,'previous theme restored'):self.engine.apply('wizarch','light',live=True)
        self.assertEqual(self.engine.capture(),before);self.assertEqual(self.backend.values,prior)
    def test_desktop_rollback_failure_retains_journal(self):
        def fault(phase):
            if phase=='appearance-applied':self.backend.fail='set';raise RuntimeError('failure after appearance')
        engine=Engine(self.paths,Compositor(),fault,self.appearance)
        with self.assertRaisesRegex(RuntimeError,'recovery journal retained'):engine.apply('wizarch','light',live=True)
        self.assertTrue((self.paths.state/'journal.json').exists());self.backend.fail=None
        self.engine.recover(live=True);self.assertEqual(self.backend.values['color-scheme'],'prefer-dark')
    def test_unchanged_failure_and_interruption_journal(self):
        before=self.engine.current();prior=copy.deepcopy(self.backend.values)
        original=self.appearance.apply
        def broken(mode):original(mode);raise SystemExit('interrupt')
        self.appearance.apply=broken
        with self.assertRaises(SystemExit):self.engine.apply('wizarch',live=True)
        record=read_json(self.paths.state/'journal.json');self.assertTrue(record['appearanceOnly'])
        self.appearance.apply=original;self.engine.recover(live=True)
        self.assertEqual(self.engine.current(),before);self.assertEqual(self.backend.values['color-scheme'],prior['color-scheme'])
    def test_ini_preservation_and_byte_exact_rollback(self):
        original=b'# keep me\n[Settings]\ngtk-font-name=Sans 11\ngtk-theme-name=Old\n[Other]\nkeep=yes\n'
        self.appearance.settings_file.parent.mkdir(parents=True)
        self.appearance.settings_file.write_bytes(original);before=self.appearance.capture()
        self.appearance.apply('light');text=self.appearance.settings_file.read_text()
        self.assertIn('# keep me',text);self.assertIn('gtk-font-name=Sans 11',text);self.assertIn('keep=yes',text)
        self.assertIn('gtk-theme-name=Wizard-Adwaita',text);self.assertIn('gtk-application-prefer-dark-theme=false',text)
        self.appearance.restore(before);self.assertEqual(self.appearance.settings_file.read_bytes(),original)
    def test_bounds_special_files_and_alias_content(self):
        import os
        path=self.appearance.settings_file;path.parent.mkdir(parents=True)
        path.write_bytes(b' ' * 32769)
        with self.assertRaisesRegex(ValueError,'32 KiB'):self.appearance.capture()
        path.unlink();os.mkfifo(path)
        with self.assertRaisesRegex(ValueError,'regular'):self.appearance.capture()
        path.unlink();self.appearance.ensure_native_themes()
        css=self.appearance.theme_root/'Wizard-Adwaita/gtk-3.0/gtk.css';css.write_text('User edit')
        with self.assertRaisesRegex(ValueError,'different content'):self.appearance.apply('light')
        self.assertEqual(css.read_text(),'User edit')
    def test_old_journal_compatibility_and_offline_no_calls(self):
        def fault(actual):
            if actual=='appearance-applied':raise SystemExit()
        engine=Engine(self.paths,Compositor(),fault,self.appearance)
        with self.assertRaises(SystemExit):engine.apply('wizarch','light',live=False)
        p=self.paths.state/'journal.json';record=read_json(p);record.pop('appearance');atomic(p,record)
        self.backend.calls=[];self.engine.recover(live=False);self.assertEqual(self.backend.calls,[])
        self.assertEqual(self.engine.current()['mode'],'dark')

if __name__=='__main__':unittest.main(verbosity=2)
