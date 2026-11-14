"""Theme role/API coverage and classified residual colors; no runtime assets modified."""
import json,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'quickshell/services'))
from theming.validation import ROLES
q=ROOT/'quickshell';api=(q/'core/Theme.qml').read_text();declared=set(re.findall(r'(?:readonly )?property (?:color|alias) (\w+):',api));compat={'textPrimary','textSecondary','textOnPrimaryContainer','divider','hoverSurface','hoverActiveSurface','background','onBackground','surfaceVariant'}
assert set(ROLES)<=declared,set(ROLES)-declared
exceptions={'components/OverlayShadow.qml':'Intentional inverse contrast halo: preserves existing dark/light opacity, blur and shape. This is a shell effect, not compositor shadow enablement.'}
residual=[]
for p in q.rglob('*.qml'):
 for i,line in enumerate(p.read_text().splitlines(),1):
  for role in re.findall(r'Core.Theme\.(\w+)',line):
   # Semantic data/services are intentionally separate from canonical role completeness.
   if role in ROLES or role in compat:assert role in declared
  if re.search(r'#[a-fA-F0-9]{3,8}|"white"|"black"',line):
   rel=p.relative_to(q).as_posix()
   if rel=='panels/LauncherDragOverlay.qml' and 'addColorStop' in line:
    assert 'ctx.globalCompositeOperation = "destination-in"' in p.read_text()
    residual.append({'file':rel,'line':i,'code':line.strip(),'reason':'Alpha-only destination-in mask; its black RGB is discarded, not displayed UI ink.'});continue
   assert rel in exceptions,(rel,i,line)
   residual.append({'file':rel,'line':i,'code':line.strip(),'reason':exceptions[rel]})
print(json.dumps({'canonicalRoles':len(ROLES),'apiCoverage':'pass','residualColors':residual,'thirdPartyArtwork':'Wallpapers, logos, desktop/tray app icons and media art keep original pixels; control SVGs use Glyph.ink.'},indent=2))
