"""Visibility and actual preference-store restart tests, with isolated XDG roots."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('launcher_desktop', ROOT/'quickshell/panels/launcher-desktop.py')
visibility = importlib.util.module_from_spec(spec)
spec.loader.exec_module(visibility)

class Launcher(unittest.TestCase):
    def test_visibility_precedence_and_stable_ids(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            env = dict(os.environ, XDG_DATA_HOME=str(base/'user'), XDG_DATA_DIRS=str(base/'system'), XDG_CURRENT_DESKTOP='Hyprland:Test')
            def entry(root, name, fields):
                path = base/root/'applications'/name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('[Desktop Entry]\nType=Application\nName=Fixture\nExec=true\n'+fields)
            entry('user', 'hidden.desktop', 'Hidden=true\n')
            entry('system', 'hidden.desktop', 'Icon=valid-icon\n')
            entry('user', 'nodisplay.desktop', 'NoDisplay=true\n')
            entry('user', 'only.desktop', 'OnlyShowIn=GNOME;\n')
            entry('user', 'never.desktop', 'NotShowIn=Test;\n')
            entry('user', 'visible.desktop', 'OnlyShowIn=Test;\nIcon=missing-icon\n')
            entry('user', 'sub/app.desktop', 'NoDisplay=true\n')
            entry('user', 'try.desktop', 'TryExec=not-a-real-launcher-program\n')
            self.assertEqual(visibility.exclusions(env), {'hidden':'Hidden','nodisplay':'NoDisplay','only':'OnlyShowIn','never':'NotShowIn','sub-app':'NoDisplay','try':'TryExec'})
    def test_preference_store_roundtrip_preserves_unavailable_and_shared_data(self):
        with tempfile.TemporaryDirectory() as temp:
            env = dict(os.environ, XDG_CONFIG_HOME=temp)
            path = Path(temp)/'wizarch/preferences.json'
            path.parent.mkdir()
            path.write_text(json.dumps({'themeOwnerField':{'keep':True},'systemVolume':67}))
            updates = {'pinnedApps':['discord','temporarily-missing'], 'appGroups':[{'name':'Mixed','type':'large','apps':['v2rayN','temporarily-missing']}], 'launcherOrder':['app:temporarily-missing','group:Mixed','app:discord']}
            command = ['python3', str(ROOT/'quickshell/services/preferences.py')]
            subprocess.check_output(command+['merge',json.dumps(updates)],env=env)
            reopened = json.loads(subprocess.check_output(command,env=env))
            self.assertEqual({key:reopened[key] for key in updates},updates)
            self.assertEqual(reopened['themeOwnerField'],{'keep':True})
            self.assertEqual(reopened['systemVolume'],67)
            self.assertFalse(any(key in reopened for key in ('x','y','dragPoint')))

    def test_recent_history_recency_bound_corruption_and_parallel_writes(self):
        with tempfile.TemporaryDirectory() as temp:
            env = dict(os.environ, XDG_STATE_HOME=temp)
            command = ['python3', str(ROOT/'quickshell/panels/launcher-history.py')]
            self.assertEqual(json.loads(subprocess.check_output(command,env=env)),[])
            for identity in ['a','b','a']:
                subprocess.check_output(command+['record',identity],env=env)
            self.assertEqual(json.loads(subprocess.check_output(command,env=env)),['a','b'])
            workers = [subprocess.Popen(command+['record','parallel-'+str(i)],env=env,stdout=subprocess.PIPE) for i in range(16)]
            for worker in workers:
                worker.communicate(timeout=5)
                self.assertEqual(worker.returncode,0)
            saved=json.loads(subprocess.check_output(command,env=env))
            self.assertEqual(set(saved),{'a','b'}|{'parallel-'+str(i) for i in range(16)})
            self.assertEqual(len(saved),len(set(saved)))
            for i in range(30):subprocess.check_output(command+['record','bounded-'+str(i)],env=env)
            saved=json.loads(subprocess.check_output(command,env=env));self.assertEqual(len(saved),24);self.assertEqual(saved[0],'bounded-29')
            path=Path(temp)/'wizarch/launcher/recent.json';path.write_text('{broken')
            self.assertEqual(json.loads(subprocess.check_output(command+['record','recovered'],env=env)),['recovered'])

if __name__ == '__main__':
    unittest.main()
