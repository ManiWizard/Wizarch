from pathlib import Path
import importlib.util, os, tempfile, unittest
from unittest.mock import patch
path=Path(__file__).resolve().parents[1]/'quickshell/services/quick-wheel.py'
spec=importlib.util.spec_from_file_location('wheel',path);wheel=importlib.util.module_from_spec(spec);spec.loader.exec_module(wheel)
class Wheel(unittest.TestCase):
 def test_focused_monitor_center_ignores_pointer(self):
  monitors=[{'name':'left','x':-1920,'y':0,'width':1920,'height':1080,'scale':1},{'name':'right','x':0,'y':0,'width':2560,'height':1440,'scale':2,'focused':True}]
  self.assertEqual(wheel.location(monitors),('right',640,360,640,360))
 def test_all_rotations_scale_offsets_and_fractional_centers(self):
  for transform in range(8):
   monitor={'name':'portrait','x':-1700,'y':-240,'width':1920,'height':1080,'scale':1.25,'transform':transform,'focused':True}
   x,y=(432,768) if transform%2 else (768,432)
   self.assertEqual(wheel.location([monitor]),('portrait',x,y,x-1700,y-240))
  monitor={'name':'odd','x':-800,'y':500,'width':1921,'height':1081,'scale':2,'focused':True}
  self.assertEqual(wheel.location([monitor]),('odd',480.25,270.25,-319.75,770.25))
  with self.assertRaises(ValueError):wheel.location([dict(monitor,disabled=True)])
  with self.assertRaises(ValueError):wheel.location([dict(monitor,mirrorOf='primary')])
 def test_opening_captures_previous_target_before_warp(self):
  values={'monitors':[{'name':'third','x':3840,'y':0,'width':1920,'height':1080,'focused':True}],'activewindow':{'address':'0x123abc'}}
  events=[]
  def ipc_call(*args):
   events.append(args)
   return 'false' if args[1]=='isOpen' else ''
  with patch.object(wheel,'query',side_effect=lambda name:values[name]),patch.object(wheel,'ipc',side_effect=ipc_call),patch.object(wheel,'warp',side_effect=lambda x,y:events.append(('warp',x,y))):
   wheel.toggle()
  self.assertEqual(events,[('quick-wheel','isOpen'),('warp',4800,540),('quick-wheel','toggle','third',960,540,'0x123abc')])
 def test_closing_never_queries_geometry_or_warps(self):
  with patch.object(wheel,'query') as query,patch.object(wheel,'warp') as warp,patch.object(wheel,'ipc',side_effect=['true','']) as ipc:
   wheel.toggle();query.assert_not_called();warp.assert_not_called()
   self.assertEqual(ipc.call_args_list[-1].args,('quick-wheel','close'))
 def test_fractional_warp_uses_native_lua_dispatch(self):
  import subprocess
  with patch.object(wheel.subprocess,'run',return_value=subprocess.CompletedProcess([],0,'ok\n','')) as run:
   wheel.warp(-319.75,770.25)
   self.assertEqual(run.call_args.args[0],['hyprctl','eval','hl.dispatch(hl.dsp.cursor.move({x=-319.75, y=770.25}))'])
 def test_warp_failure_does_not_map_wheel(self):
  with patch.object(wheel,'ipc',return_value='false') as ipc,patch.object(wheel,'query',side_effect=[[{'name':'a','x':0,'y':0,'width':1920,'height':1080}],{}]),patch.object(wheel,'warp',side_effect=ValueError('failed')):
   with self.assertRaises(ValueError):wheel.toggle()
   ipc.assert_called_once_with('quick-wheel','isOpen')
 def test_all_existing_panel_routes_and_no_unknown_execution(self):
  with tempfile.TemporaryDirectory() as temporary,patch.dict(os.environ,{'XDG_CACHE_HOME':temporary}),patch.object(wheel,'query',return_value=[{'name':'third'}]),patch.object(wheel,'ipc') as ipc:
   for action,section in wheel.ACTIONS.items():
    wheel.activate('third',action,'');ipc.assert_called_with('panel-third','togglePanel' if section in ('settings','themes') else 'show',section)
   count=ipc.call_count
   with self.assertRaises(ValueError):wheel.activate('third','unknown','')
   self.assertEqual(ipc.call_count,count)
   with self.assertRaises(ValueError):wheel.activate('missing','settings','')
 def test_clipboard_keeps_original_window_with_isolated_cache(self):
  with tempfile.TemporaryDirectory() as temporary,patch.dict(os.environ,{'XDG_CACHE_HOME':temporary}),patch.object(wheel,'query',return_value=[{'name':'third'}]),patch.object(wheel,'ipc'):
   cache=Path(temporary)/'wizarch/previous-window'
   wheel.activate('third','clipboard','0x123abc');self.assertEqual(cache.read_text(),'0x123abc')
   wheel.activate('third','clipboard','invalid');self.assertFalse(cache.exists())
 def test_ipc_retries_reload_readiness_without_double_activation(self):
  import subprocess
  responses=[subprocess.CompletedProcess([],0,'Not ready to accept queries yet.',''),subprocess.CompletedProcess([],0,'','')]
  with patch.object(wheel.subprocess,'run',side_effect=responses) as run,patch.object(wheel.time,'sleep'):
   wheel.ipc('quick-wheel','toggle','third',1,2,'');self.assertEqual(run.call_count,2)
 def test_screenshot_uses_existing_tool(self):
  with patch.object(wheel,'query',return_value=[{'name':'third'}]),patch.object(wheel.os,'execv') as execute:
   wheel.activate('third','screenshot','');execute.assert_called_once_with(str(Path.home()/'.local/bin/hypr-screenshot'),[str(Path.home()/'.local/bin/hypr-screenshot')])
if __name__=='__main__':unittest.main()
