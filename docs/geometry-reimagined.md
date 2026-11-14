# Unified shape profile — current implementation

The original migrations centralized and reproduced existing shapes. This revision
supersedes their visual policy: the user's correction explicitly requires a new,
consistent silhouette, including controls that previously remained circular.

## One rule

All UI radius roles now use the same equation:

```
radius = min(shorter rendered edge / 5, scaled standard button height / 3)
```

The standard button height comes from the shared input/metric model. The two
profile proportions are defined once in `core/Geometry.js` as `shapeProfile`.
There is no per-feature radius table. Names such as `launcherGroup`, `tile`,
`navigation` and `softCard` describe use; they do not select different curves.
At the default standard control height of 38 logical pixels:

| Surface | New radius | Result |
| --- | ---: | --- |
| 30×30 header action | 6 | Rounded square instead of circle |
| 44×44 volume/brightness action | 8.8 | Same corners as its 44-high slider |
| 38×40 media playback button | 7.6 | Same proportion as other action buttons |
| 70×70 compact launcher group | 12.67 | Shared capped rounded rectangle |
| Large launcher group | 12.67 | Same corner family and ceiling as compact groups |
| 20-high weekday header | 4 | Rounded rectangle instead of capsule |

The ceiling keeps large surfaces from developing oversized corners that consume
content space. Final dimensions determine the smaller shapes; UI/font scaling
changes the shared control-height ceiling. The calculation is continuous, bounded
and independent of child-to-parent feedback. This is a deliberate design rule,
not a claim of a universally optimal aesthetic ratio.

## Actual consumers

Interactive circles and capsules were replaced with this profile throughout
Quick Settings (header, power trigger, action grid, volume and brightness surfaces
and buttons), sliders and handles, scrollbars, notifications, clipboard, calendar,
Settings, media playback, tray/workspace controls and quick-wheel center controls.
Launcher groups, slots, search/menu/result surfaces and fallback icon rectangles
consume the same rule. Existing relative icon-radius constants were removed.

Inset surfaces still derive from their outer contour minus the inset where the
shapes describe concentric edges: the switch thumb and launcher inset highlight
are examples. They are not independent style exceptions. Pill body, mask and shadow
now follow the profile too, instead of allowing a compositor frame preference to
choose the app's body shape.

Screen-frame inputs retain their compositor matching semantics. Radial navigation
sector arcs, battery/emblem drawings and imported logo/icon/image artwork retain
intrinsic geometry; they are drawings, not circular button backgrounds. Their
allocated size remains dynamic. The circle/capsule mathematical helper remains
available for bounding calculations, but no QML control calls it to choose its
appearance.

## Verification

- 8,395 pure-model assertions pass, including cross-role equality at equal box
  dimensions, bounds, scale inputs and explicit noncircular interactive shapes.
- The coverage check verifies 117 rendered radius assignments, rejects a returned
  historical radius table and prevents QML capsule bypasses.
- Real Qt Quick Settings tests assert that volume/brightness surfaces and their
  action buttons have equal, noncircular corners. Settings, Notifications and
  Power options are also checked as actual objects.
- Real media tests assert the playback background uses the new noncircular shape.
- Calendar tests verify actual date-card bindings. Launcher tests check visible
  surfaces against the shared profile during stable opening/reopening.
- Calendar, media, Settings and Quick Settings behavior checks pass; pointer, drag
  and keyboard slider input remain functional in the isolated tests.
- All production QML parses. Shared-control captures report no radius violations
  or runtime errors.

The source baseline, patch, captures and installation manifest live in the task
workspace's `audit/geometry-reimagined-20261009` directory. Twenty changed files
were backed up and installed. The installed Quick Settings label difference was
preserved. The live shell reloaded and its Quick Settings, launcher and calendar
were inspected separately from isolated fixture verification.

This revision deliberately changes silhouettes. Earlier pixel-identical reports
are historical evidence for the earlier policy, not acceptance criteria for this
new profile. The change concerns shape geometry; it does not replace interaction
flows or claim a complete rewrite of every layout dimension.
