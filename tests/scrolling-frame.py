"""Monitor/workspace isolation for the native peek screen-frame guard."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('frame',Path(__file__).resolve().parents[1]/'quickshell/services/scrolling-frame.py')
frame = importlib.util.module_from_spec(spec)
spec.loader.exec_module(frame)

class FrameTests(unittest.TestCase):
    def setUp(self):
        self.monitors=[{'name':'A','activeWorkspace':{'id':1}}, {'name':'B','activeWorkspace':{'id':2}}]
        self.workspaces=[{'id':1,'tiledLayout':'scrolling'}, {'id':2,'tiledLayout':'dwindle'}, {'id':3,'tiledLayout':'scrolling'}]
    def test_visible_scrolling_only(self):
        self.assertEqual(frame.protected(self.monitors,self.workspaces),{'A':True})
    def test_fullscreen_and_special_workspaces_have_no_guard(self):
        self.workspaces[0]['hasfullscreen']=True
        self.assertEqual(frame.protected(self.monitors,self.workspaces),{})
        self.workspaces[0]['hasfullscreen']=False
        self.monitors[0]['specialWorkspace']={'id':-99}
        self.assertEqual(frame.protected(self.monitors,self.workspaces),{})
    def test_missing_or_stale_workspace_keeps_guard_hidden(self):
        self.monitors[0]['activeWorkspace']={'id':100}
        self.assertEqual(frame.protected(self.monitors,self.workspaces),{})
    def test_outputs_are_independent(self):
        self.workspaces[1]['tiledLayout']='scrolling'
        self.assertEqual(frame.protected(self.monitors,self.workspaces),{'A':True,'B':True})

if __name__=='__main__':unittest.main()
