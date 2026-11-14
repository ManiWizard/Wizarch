"""Spacing publication failures restore live gaps and preserve prior Lua bytes."""
import importlib.util,json,subprocess,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('spacing',Path(__file__).resolve().parents[1]/'quickshell/services/window-spacing.py')
spacing=importlib.util.module_from_spec(spec);spec.loader.exec_module(spacing)
class SpacingTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.folder=Path(self.tmp.name)
  self.target=self.folder/'wizarch-spacing.lua';self.target.write_text('previous');self.commands=[]
  def run(args,**kw):
   self.commands.append(args)
   return subprocess.CompletedProcess(args,0,json.dumps({'css':'2 3 4 5'}) if args[1]=='getoption' else 'ok\n','')
  self.addCleanup(patch.stopall);patch.object(spacing.subprocess,'run',run).start()
 def test_generated_spacing(self):
  self.assertEqual(spacing.apply(35,self.folder),{'ok':True,'inner':2,'outer':7})
  self.assertIn('gaps_in = 2, gaps_out = 7',self.target.read_text())
 def test_publish_failure_preserves_fragment_and_restores_asymmetric_gaps(self):
  with patch.object(spacing.os,'replace',side_effect=OSError('read only')):
   with self.assertRaises(OSError):spacing.apply(80,self.folder)
  self.assertEqual(self.target.read_text(),'previous')
  self.assertIn('top=2,right=3,bottom=4,left=5',self.commands[-1][2])
  self.assertEqual({p.name for p in self.folder.iterdir()}, {'wizarch-spacing.lua','.wizarch-spacing.lock'})
 def test_validation_does_not_touch_compositor(self):
  for value in [-1,151]:
   with self.assertRaises(ValueError):spacing.apply(value,self.folder)
  self.assertEqual(self.commands,[]);self.assertEqual(self.target.read_text(),'previous')
 def test_generation_failure_does_not_apply(self):
  with patch.object(spacing.tempfile,'mkstemp',side_effect=OSError('disk full')):
   with self.assertRaises(OSError):spacing.apply(80,self.folder)
  self.assertTrue(all(c[1]=='getoption' for c in self.commands));self.assertEqual(self.target.read_text(),'previous')
if __name__=='__main__':unittest.main()
