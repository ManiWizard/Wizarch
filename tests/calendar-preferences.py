from pathlib import Path
import json,os,subprocess,tempfile,unittest
helper=Path(__file__).resolve().parents[1]/'quickshell/services/preferences.py'
class CalendarPreferences(unittest.TestCase):
 def test_store(self):
  with tempfile.TemporaryDirectory() as folder:
   env=dict(os.environ,XDG_CONFIG_HOME=folder)
   store=Path(folder)/'wizarch/preferences.json';store.parent.mkdir();store.write_text(json.dumps({'custom':'keep','audioMode':'mute'}))
   def run(changes=None):
    return subprocess.run(['python3',str(helper)]+(['merge',json.dumps(changes)] if changes is not None else []),env=env,capture_output=True,text=True)
   initial=json.loads(run().stdout);self.assertEqual(initial['calendarPrimary'],'gregorian');self.assertEqual(initial['calendarSecondary'],'solar');self.assertEqual(initial['calendarWeekStart'],'auto')
   self.assertEqual(run({'calendarPrimary':'solar','calendarSecondary':'solar'}).returncode,0)
   self.assertEqual(json.loads(store.read_text())['calendarSecondary'],'off')
   event={'id':'one','date':'2024-02-29','title':'Leap event','color':'#aAbBcC','icon':'★'}
   self.assertEqual(run({'calendarSecondary':'gregorian','calendarEvents':[event]}).returncode,0)
   saved=json.loads(run().stdout);self.assertEqual(saved['calendarEvents'],[event]);self.assertEqual(saved['custom'],'keep');self.assertEqual(saved['audioMode'],'mute')
   for style in ['auto','saturday','monday','sunday']:
    self.assertEqual(run({'calendarWeekStart':style}).returncode,0);self.assertEqual(json.loads(run().stdout)['calendarWeekStart'],style)
   old=store.read_bytes()
   for update in [{'calendarWeekStart':'friday'},{'calendarWeekStart':6},{'calendarPrimary':'lunar'},{'calendarSecondary':False},{'calendarEvents':[dict(event,date='2023-02-29')]},{'calendarEvents':[dict(event,date='1900-12-31')]},{'calendarEvents':[dict(event,color='red')]},{'calendarEvents':[dict(event,title='')]},{'calendarEvents':[dict(event,icon='012345678')]},{'calendarEvents':[event,event]},{'calendarEvents':[dict(event,extra=True)]}]:
    self.assertNotEqual(run(update).returncode,0,update);self.assertEqual(store.read_bytes(),old)
   store.write_text(json.dumps({'calendarPrimary':[],'calendarSecondary':'solar','calendarEvents':[{'invalid':'entry'}],'custom':'keep'}))
   restored=json.loads(run().stdout);self.assertEqual(restored['calendarPrimary'],'gregorian');self.assertEqual(restored['calendarEvents'],[]);self.assertEqual(restored['custom'],'keep')
if __name__=='__main__':unittest.main()
