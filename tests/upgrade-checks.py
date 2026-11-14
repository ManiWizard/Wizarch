"""Run the upgrade's model/storage/offscreen suites; never inject desktop input."""
import argparse,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--node',required=True);p.add_argument('--output',required=True,type=Path);args=p.parse_args()
args.output.mkdir(parents=True,exist_ok=True)
tests=['geometry.js','geometry-coverage.py','reliability.js','reliability.py','ui-scale-preferences.py','workspaces.py','layouts.py','scrolling-frame.py','scrolling-stack.py','launcher.js','launcher.py','launcher-opening.py','calendar.js','calendar-preferences.py','quick-wheel.js','quick-wheel.py','window-spacing.py','upgrade-deployment.py','state-reader-qt.py','theme-watcher-qt.py','brightness-writer-qt.py','keyboard-focus-qt.py','settings-window-qt.py','quick-settings-qt.py','calendar-qt.py','media-card-qt.py','ui-scale-qt.py','preference-writer-qt.py']
results={}
for name in tests:
 try:
  result=subprocess.run([args.node if name.endswith('.js') else sys.executable,str(ROOT/'tests'/name)],cwd=ROOT,capture_output=True,text=True,timeout=100)
  (args.output/(name+'.log')).write_text(result.stdout+result.stderr);results[name]=result.returncode
 except subprocess.TimeoutExpired as error:
  (args.output/(name+'.log')).write_bytes((error.stdout or b'')+(error.stderr or b''));results[name]='timeout'
 print(name,results[name],flush=True)
(args.output/'results.json').write_text(json.dumps(results,indent=2)+'\n')
raise SystemExit(1 if any(results.values()) else 0)
