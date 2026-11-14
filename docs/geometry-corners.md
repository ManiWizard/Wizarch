# Complete rounded-control migration

**Superseded visual policy:** read [the current unified shape profile](geometry-reimagined.md).
The current implementation replaces historical radius values and circular
control backgrounds; preservation claims below describe earlier migrations.

All application-defined rounded QML surfaces now consume `Core.Geometry`, or forward
an already calculated radius into a clipping mask. This extends the first geometry
migration to the complete corner/circle inventory and is installed in the running
shell. The task-start source snapshot preserves the user's current edits; installed
files were checked against that snapshot before replacement and backed up.

## Coverage

The source inventory contains 117 rendered `radius` assignments plus one scrolling
stack property carrying a compositor radius input. No rendered component-local
radius formula remains. `tests/geometry-coverage.py` prevents new independent radius
assignments and permits explicit calculated mask aliases and frame conditionals.
This scan supplements source inspection and runtime checks; it is not a claim that
all possible interactions have been exercised.

The migration includes launcher compact/large groups, group slots, drag previews,
search and result rows, menus, app highlights and membership circles; calendar day
and month cards, miniature date markers, weekday capsules and event inputs; media
cards, progress tracks/fills, seek handles and playback buttons; notifications and
dismiss circles; clipboard/emoji rows, dialogs and deletion controls; connectivity
controls; Settings navigation and input fields; theme cards/previews and selection
circles; scrollbars, tooltips, scrolling clips and quick-wheel circular geometry.
The first migration already covered switches, shared buttons/sliders, Quick Settings,
the pill, frame, highlights and shadow.

## Calculation rules

Rounded cards use semantic calibrated roles. Their preferred radius scales from
explicit UI/font inputs, aligns to the model's DPR and is bounded to half the final
smaller dimension. This preserves existing default curves while handling invisible,
small and dynamically allocated boxes. New roles are `field`, `softCard`,
`compactControl`, `appHighlight`, `launcherGroup`, `launcherGroupLarge`, `tooltip`,
`previewLine` and `insertionMarker`; existing roles remain shared where appropriate.

True circles, capsules, slider handles and fills use `capsule(width, height)` rather
than an independent radius. The former 29-pixel close control is now an exact circle
with a 14.5-pixel radius. This is a small precision correction; there is no wholesale
change of curve family. Miniature calendar marks retain their intentionally softer
rectangular shape through a bounded semantic role.

The launcher's inset app highlight derives from its outer section radius minus its
actual inset. Standalone group slots are distinct surfaces and retain their own role.
The fallback launcher icon uses `proportionalRadius` with its original 0.23/0.12
proportions and a bounded, scaled detail minimum. Quick-wheel inner and outer radii
are shared viewport calculations; undersized viewports no longer force a 100-pixel
radius beyond their available space. Its center circle has a nonnegative allocation.

Compositor/user frame radii retain their logical-pixel input meaning and are bounded
when rendered. Existing cubic pill shoulders retain their shared calibrated path.
Canvas emblem arcs already scale through their allocated canvas transform. Imported
SVG, application-icon and wallpaper artwork retain their intrinsic paths; artwork
is not redrawn as a control surface.

## Verification and deployment

- 5,411 pure geometry assertions pass, including every radius role, proportional
  icon bounds and zero/narrow radial-menu viewports.
- All production QML parses. Shared-control captures have zero radius violations.
- Calendar, media, Settings and Quick Settings integration checks pass.
- Launcher opening/reopening checks pass and recursively validate actual rendered
  radii during the width morph; tile bounds remain stable.
- All 11 calendar and five media captures are pixel-identical to the task-start
  baseline. This statement is scoped to those captures, not every application state.
- Quick-wheel pure navigation checks pass. The live exclusive wheel was not opened
  for exhaustive physical interaction tests.
- 22 source files were installed, backed up and verified by hash. The existing
  running instance reloaded successfully. Live launcher groups and calendar dates
  were visually inspected on HDMI-A-1. The laptop's fullscreen application hides
  its Top-layer shell surfaces; it was left in place.

Evidence, source snapshot, patch, image comparisons, live captures and deployment
manifest are in the task workspace's `audit/geometry-complete-20261009` directory.
The manifest names the timestamped installed-file backup.

All rounded-control radii are migrated. Independent layout dimensions, automatic
per-output DPR selection and complete whole-shell viewport reflow are separate work;
this change does not claim all spacing, font and layout measurements were converted.
Future components must calculate corners through the shared API and run the coverage
check. Physical interaction across every hidden panel state remains unverified.
