"""Independent monitor navigation, migration and retained workspace identities."""
import copy
import importlib.util
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('workspaces', Path(__file__).resolve().parents[1] / 'quickshell/services/workspaces.py')
ws = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ws)


class WorkspaceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.config = Path(self.temp.name)
        self.state = self.config / 'session.json'
        self.old_state = ws.STATE
        ws.STATE = self.state
        self.monitors = [dict(id=0, name='A', focused=True, activeWorkspace=dict(name='1')),
                         dict(id=1, name='B', focused=False, activeWorkspace=dict(name='2'))]
        self.clients = [dict(address='0xa', monitor=0, workspace=dict(name='1')),
                        dict(address='0xb', monitor=1, workspace=dict(name='2'))]
        self.commands = []
        self.query_patch = patch.object(ws, 'query', self.query)
        self.eval_patch = patch.object(ws, 'evaluate', self.evaluate)
        self.query_patch.start(); self.eval_patch.start()

    def tearDown(self):
        self.query_patch.stop(); self.eval_patch.stop()
        ws.STATE = self.old_state
        self.temp.cleanup()

    def query(self, what):
        if what == 'monitors': return copy.deepcopy(self.monitors)
        if what == 'clients': return copy.deepcopy(self.clients)
        if what == 'activewindow': return copy.deepcopy(self.clients[0])
        if what == 'workspaces': return [dict(name=m['activeWorkspace']['name'], monitor=m['name']) for m in self.monitors]
        raise AssertionError(what)

    def evaluate(self, code):
        self.commands.append(code)
        if 'hl.dsp.focus' in code:
            name = json.loads(re.search(r'hl.get_monitor\((".*?")\)', code)[1])
            target = json.loads(re.search(r'workspace = (".*?")', code)[1]).removeprefix('name:')
            for m in self.monitors:
                m['focused'] = m['name'] == name
                if m['name'] == name: m['activeWorkspace']['name'] = target
        elif 'hl.dsp.window.move' in code:
            target = json.loads(re.search(r'workspace = (".*?")', code)[1]).removeprefix('name:')
            self.clients[0]['workspace']['name'] = target

    def run_action(self, action='sync', value=None, monitor=None):
        return ws.run(action, value, monitor, self.config)['monitors']

    def test_switch_and_wrap_only_selected_monitor(self):
        self.run_action()
        result = self.run_action('switch', '9')
        self.assertEqual(result['A']['current'], 9)
        self.assertEqual(result['B']['current'], 1)
        self.assertEqual(self.monitors[1]['activeWorkspace']['name'], '2')
        self.assertEqual(self.run_action('switch', 'next')['A']['current'], 1)
        self.assertEqual(self.run_action('switch', 'prev')['A']['current'], 9)
        self.assertEqual(self.monitors[1]['activeWorkspace']['name'], '2')

    def test_native_sync_never_dispatches_other_monitor(self):
        self.run_action()
        self.commands.clear()
        self.monitors[1]['activeWorkspace']['name'] = 'wizarch-4-B'
        self.monitors[1]['focused'] = True
        self.monitors[0]['focused'] = False
        result = self.run_action()
        self.assertEqual(result['B']['current'], 4)
        self.assertEqual(result['A']['current'], 1)
        self.assertEqual(result['A']['revision'], 0)
        self.assertEqual(result['B']['revision'], 1)
        self.assertEqual(self.commands, [])

    def test_move_captures_window_without_switching_either_monitor(self):
        before = copy.deepcopy(self.monitors)
        self.run_action('move', '3')
        self.assertEqual(self.clients[0]['workspace']['name'], 'wizarch-3-A')
        self.assertEqual(self.clients[1]['workspace']['name'], '2')
        self.assertEqual(self.monitors, before)
        self.assertIn('address:0xa', self.commands[-1])
        self.assertIn('follow = false', self.commands[-1])
        self.assertEqual(self.run_action()['A']['used'], [1, 3])
        self.assertEqual(self.run_action()['B']['used'], [1])

    def test_explicit_monitor_click_and_local_desktop(self):
        self.run_action('switch', '5', 'B')
        self.assertEqual(self.monitors[0]['activeWorkspace']['name'], '1')
        self.assertEqual(self.run_action('desktop')['B']['current'], 5)
        self.assertEqual(self.monitors[1]['activeWorkspace']['name'], '__desktop_B')
        self.run_action('desktop')
        self.assertEqual(self.monitors[1]['activeWorkspace']['name'], 'wizarch-5-B')
        self.assertEqual(self.monitors[0]['activeWorkspace']['name'], '1')

    def test_legacy_map_migrates_and_survives_new_session_and_reconnect(self):
        mapping = {m['name']: {str(i): f'wizarch-{i}-{m["name"]}' for i in range(1, 10)} for m in self.monitors}
        mapping['A']['1']='1'; mapping['B']['1']='2'
        self.state.write_text(json.dumps(dict(current=1, used=[1], revision=4, desktop=False, map=mapping)))
        self.run_action()
        saved=json.loads((self.config/'wizarch/workspace-monitors.json').read_text())
        self.assertEqual(saved['map'], mapping)
        generated=(self.config/'hypr/wizarch-workspaces.lua').read_text()
        self.assertEqual(generated.count('persistent = true'), 18)
        self.assertEqual(generated.count('default = true'), 2)
        self.state.unlink()
        self.monitors.reverse()
        self.run_action()
        self.assertEqual(json.loads(self.state.read_text())['map'], mapping)
        detached=self.monitors.pop()
        self.run_action()
        self.monitors.append(detached)
        self.run_action()
        self.assertEqual(json.loads(self.state.read_text())['map'], mapping)

    def test_invalid_slot_or_disconnected_monitor_never_navigates(self):
        self.run_action()
        self.commands.clear()
        with self.assertRaises(ValueError): self.run_action('switch', '10')
        with self.assertRaises(ValueError): self.run_action('switch', '1', 'missing')
        self.assertEqual(self.commands, [])

    def test_disconnect_during_query_uses_latest_monitor_list(self):
        self.run_action()
        original=self.query
        reads=0
        def query(what):
            nonlocal reads
            if what=='monitors':
                reads+=1
                return original(what) if reads==1 else original(what)[:1]
            return original(what)
        with patch.object(ws,'query',query):
            result=self.run_action()
        self.assertEqual(set(result),{'A'})

    def test_reconnect_does_not_reassign_slots_or_navigate(self):
        self.run_action()
        saved=(self.config/'wizarch/workspace-monitors.json').read_bytes()
        detached=self.monitors.pop()
        self.run_action();self.commands.clear()
        self.monitors.append(detached)
        self.run_action()
        self.assertEqual(self.commands,[])
        self.assertEqual((self.config/'wizarch/workspace-monitors.json').read_bytes(),saved)

    def test_atomic_failure_preserves_prior_file(self):
        target=self.config/'hypr/wizarch-workspaces.lua'
        target.parent.mkdir(parents=True);target.write_text('previous')
        with patch.object(ws.os,'replace',side_effect=OSError('disk full')):
            with self.assertRaises(OSError):ws.atomic_write(target,'candidate')
        self.assertEqual(target.read_text(),'previous')
        self.assertEqual([p.name for p in target.parent.iterdir()],['wizarch-workspaces.lua'])


if __name__ == '__main__': unittest.main()
