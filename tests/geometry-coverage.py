"""Prevent new component-local corner formulas; platform inputs and mask aliases are explicit."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]/'quickshell'
count=0
assert "var radiusCalibration" not in (root/"core/Geometry.js").read_text(),"Historical per-role radii returned"
failures=[]
for path in root.rglob('*.qml'):
    assert all(call not in path.read_text() for call in ['Core.Geometry.capsule(', 'uiGeometry.capsule(']),f'Interactive circle/capsule bypass in {path.name}'
    for line_number,line in enumerate(path.read_text().splitlines(),1):
        for match in re.finditer(r'\bradius:\s*([^;\n}]+)',line):
            expression=match[1].strip()
            # This stack property is the compositor's input, not a rendered radius.
            if 'readonly property real radius:' in line and path.name=='ScrollingStack.qml':
                continue
            # The installed radial wheel's disk/hub are intrinsic navigation artwork.
            # Preserve their current silhouette; no other control may bypass the model.
            if path.name=='QuickWheel.qml' and expression=='width/2' and any(f'objectName: "{name}"' in line for name in ['wheelDisk','wheelHub']):
                continue
            count+=1
            if not (expression.startswith(('Core.Geometry.', 'uiGeometry.')) or re.fullmatch(r'(pillWindow|separation.panel)\.screenBorder \? (?:Core\.Geometry|uiGeometry)\.boundedRadius\(.+\) : (?:Core\.Geometry|uiGeometry)\.radius\(.+\)',expression) or expression in ['body.radius','card.radius']):
                failures.append(f'{path.relative_to(root)}:{line_number}: {expression}')
assert not failures,'Unmanaged corner formulas:\n'+'\n'.join(failures)
print(f'CORNER_COVERAGE_PASS: {count} rendered radius assignments use shared geometry or mask aliases')
