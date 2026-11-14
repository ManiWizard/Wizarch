"""Visible workspace isolation, exclusion and bounded column-order checks."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('stack', Path(__file__).resolve().parents[1]
                                            / 'quickshell/services/scrolling-stack.py')
stack = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stack)


class StackTests(unittest.TestCase):
    def setUp(self):
        self.monitors = [{'id': 0, 'name': 'A', 'activeWorkspace': {'id': 1}},
                         {'id': 1, 'name': 'B', 'activeWorkspace': {'id': 2}}]
        self.workspaces = [{'id': 1, 'name': 'one', 'tiledLayout': 'scrolling', 'lastwindow': 'a'},
                           {'id': 2, 'name': 'two', 'tiledLayout': 'dwindle', 'lastwindow': 'x'}]
        self.clients = [dict(address=a, monitor=0, workspace={'id': 1}, at=[i * 2000, 0])
                        for i, a in enumerate('abcde')]
        self.active = dict(self.clients[0])

    def read(self):
        return stack.stacks(self.monitors, self.workspaces, self.clients, self.active)

    def test_order_wrap_and_cap(self):
        self.active = dict(self.clients[3])
        cards = self.read()['A']['cards']
        self.assertEqual([c['address'] for c in cards], ['e', 'a', 'b'])
        self.assertEqual(self.read()['A']['count'], 5)

    def test_other_monitor_uses_last_window_and_ignores_hidden_workspace(self):
        self.active = {'address': 'x', 'monitor': 1, 'workspace': {'id': 2}}
        self.clients.append(dict(address='secret', monitor=0, workspace={'id': 9}, at=[0, 0]))
        self.assertEqual(self.read()['A']['active'], 'a')
        self.assertNotIn('B', self.read())
        self.assertNotIn('secret', [c['address'] for c in self.read()['A']['cards']])

    def test_fullscreen_special_and_floating_focus_hide_stack(self):
        self.workspaces[0]['hasfullscreen'] = True
        self.assertEqual(self.read(), {})
        self.workspaces[0]['hasfullscreen'] = False
        self.monitors[0]['specialWorkspace'] = {'id': -99}
        self.assertEqual(self.read(), {})
        self.monitors[0]['specialWorkspace'] = {'id': 0}
        self.clients[0]['floating'] = True
        self.assertEqual(self.read(), {})

    def test_excluded_clients_never_become_cards(self):
        for c, flag in zip(self.clients[1:], ['hidden', 'floating', 'pinned', 'mapped']):
            c[flag] = flag != 'mapped'
        self.assertEqual(self.read(), {})

    def test_inconsistent_active_snapshot_never_reserves_space(self):
        self.active['address'] = 'closed'
        self.assertEqual(self.read(), {})


if __name__ == '__main__':
    unittest.main()
