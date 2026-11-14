"""Isolated preference-store and monitor-occupancy regression checks."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'quickshell'


class ReliabilityTests(unittest.TestCase):
    def test_atomic_merge_and_unknown_fields(self):
        with tempfile.TemporaryDirectory() as folder:
            env = dict(os.environ, XDG_CONFIG_HOME=folder)
            store = Path(folder) / 'wizarch/preferences.json'
            store.parent.mkdir()
            store.write_text(json.dumps({'customField': 'keep', 'revealMode': 'wallpaper'}))
            def run(*args):
                return subprocess.run(['python3', str(ROOT/'services/preferences.py'), *args], env=env, capture_output=True, text=True)
            result = run('merge', json.dumps({'pinnedApps': ['b'], 'appGroups': [{'name': 'Test', 'apps': ['a']}], 'launcherOrder': ['group:Test']}))
            self.assertEqual(result.returncode, 0)
            saved = json.loads(store.read_text())
            self.assertEqual(saved['customField'], 'keep')
            self.assertEqual(saved['revealMode'], 'overlay')
            self.assertEqual(saved['pinnedApps'], ['b'])
            self.assertEqual(saved['appGroups'][0]['apps'], ['a'])
            previous = store.read_bytes()
            self.assertNotEqual(run('set', 'dnd', '"bad type"').returncode, 0)
            self.assertEqual(store.read_bytes(), previous)
            # A real filesystem error, independent of root permissions.
            store.unlink(); store.mkdir()
            self.assertNotEqual(run('set', 'dnd', 'true').returncode, 0)
            store.rmdir(); store.write_bytes(previous)
            self.assertEqual(run('set', 'dnd', 'true').returncode, 0)
            self.assertTrue(json.loads(store.read_text())['dnd'])

    def test_visible_workspace_occupancy(self):
        spec = importlib.util.spec_from_file_location('window_state', ROOT/'services/window-state.py')
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        monitors = [{'id':0,'name':'A','activeWorkspace':{'id':1}}, {'id':1,'name':'B','activeWorkspace':{'id':2}, 'specialWorkspace':{'id':-5}}]
        client = {'monitor':0,'workspace':{'id':1},'mapped':True,'class':'app'}
        self.assertEqual(module.occupied(monitors,[client]), {'A':True,'B':False})
        for changes in [{'hidden':True}, {'mapped':False}, {'workspace':{'id':3}}, {'class':'org.quickshell'}]:
            self.assertFalse(module.occupied(monitors,[dict(client,**changes)])['A'])
        settings = dict(client, **{'class':'org.quickshell','title':'Wizarch Settings'})
        self.assertTrue(module.occupied(monitors,[settings])['A'])
        self.assertFalse(module.occupied(monitors,[dict(settings,workspace={'id':3})])['A'])
        self.assertFalse(module.occupied(monitors,[dict(settings,hidden=True)])['A'])
        self.assertFalse(module.occupied(monitors,[dict(settings,mapped=False)])['A'])
        special = dict(client,monitor=1,workspace={'id':-5})
        self.assertEqual(module.occupied(monitors,[special]), {'A':False,'B':True})
        monitors[1]['specialWorkspace']['id']=0
        self.assertFalse(module.occupied(monitors,[special])['B'])
        with tempfile.TemporaryDirectory() as folder:
            env=dict(os.environ, PATH=folder)
            self.assertEqual(subprocess.check_output(['/usr/bin/python3',str(ROOT/'services/window-state.py')],env=env,text=True).strip(),'{}')


if __name__ == '__main__':
    unittest.main()
