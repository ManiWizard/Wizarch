from pathlib import Path
import runpy,unittest
module=runpy.run_path(str(Path(__file__).resolve().parents[1]/"quickshell/services/preferences.py"))
class ScalePreferences(unittest.TestCase):
 def test_supported_output_values(self):
  for scale in [1,1.25,1.5,1.75,2]:self.assertTrue(module["valid"]("uiScaleByOutput",{"HDMI-A-1":scale}))
 def test_invalid_values(self):
  for value in [0,3,1.1,float("nan"),float("inf"),"2",True,None]:self.assertFalse(module["valid"]("uiScaleByOutput",{"HDMI-A-1":value}))
  for value in [[],None,{"":2},{"x"*129:2}]:self.assertFalse(module["valid"]("uiScaleByOutput",value))
 def test_independent_outputs(self):
  self.assertTrue(module["valid"]("uiScaleByOutput",{"HDMI-A-1":2,"eDP-1":1}))
if __name__=="__main__":unittest.main()
