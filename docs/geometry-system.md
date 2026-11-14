# Geometry model

**Superseded visual policy:** read [the current unified shape profile](geometry-reimagined.md).
The current implementation replaces historical radius values and circular
control backgrounds; preservation claims below describe earlier migrations.

**Current corner coverage:** the [complete rounded-control migration](geometry-corners.md)
is installed in the running shell. All application-defined rounded controls and
circles now use this API. The first-pass coverage/deployment notes below are
historical; independent layout scaling remains separate work.

`core/Geometry.qml` is the shared geometry singleton. It imports only QtQuick and
the pure `core/Geometry.js` library; it has no theme, system-service, or rendered
item dependencies. The default appearance is calibrated from the current shell.
Existing measurements live together in named semantic roles rather than being
replaced by a new curve family or guessed proportions.

## Inputs and dependency direction

The four upstream inputs are `uiScale = 1`, `referenceFontSize = 13`,
`fontSize = 13`, and `devicePixelRatio = 1`. Preferred logical lengths scale by
`uiScale * fontSize / referenceFontSize`. Fonts use named calibrated metrics too.
The reference font defines the calibration, and the requested font defines the
current content scale. Device pixel ratio aligns preferred static lengths to the
nearest physical pixel and supplies the minimum visible stroke; it does not
multiply logical control dimensions. Alignment happens once at the calibrated
metric output. Layout fractions and animation progress remain continuous; do
not round a child's computed size and feed it back into its parent.

The dependency graph is one-way:

```
explicit inputs → calibrated preferred metrics → content/layout size → bounded radii
                                         available space → fitted size
```

Intrinsic content measurements may increase preferred control height. Available
space may constrain a rendered size. Neither may update the input model. In
particular, do not calculate a parent's preferred size from a child whose size is
already anchored to that parent. Radii consume the final width/height and never
participate in sizing.

## API

Import `"../core" as Core` from a component, then use:

| Function | Meaning |
| --- | --- |
| `metric(name)` | Existing named measurement, proportionally scaled. |
| `align(value)` | Already-scaled nonnegative static length rounded to a physical pixel. |
| `constraint(name)` | Named logical-pixel platform preference limit, independent of UI/font scale. |
| `controlHeight(role, contentHeight)` | Greater of role minimum and padding-complete intrinsic content height. |
| `fit(preferred, available)` | Preferred length bounded to nonnegative available space. |
| `radius(role, width, height)` | Scaled, pixel-aligned semantic radius bounded by half the smaller dimension. |
| `capsule(width, height)` | Exactly `min(width, height) / 2` for nonnegative dimensions. |
| `boundedRadius(preferred, width, height)` | Bounded already-scaled platform/user radius. |
| `insetRadius(outer, inset, width, height)` | `max(0, outer - inset)`, bounded to the inner box. |
| `stroke(focused = false)` | Existing one/two logical-pixel stroke, with a one-device-pixel minimum. |
| `clamp(minimum, maximum, value)` | Bounds a nonnegative length between ordered limits. |

Height roles are `button`, `choice`, `switch`, `slider`, `glassSlider`, `glassSliderTrack`, `glass`,
`row`, `quickSlider`, `tile`, and `action`. Tiles/actions have no independent
historic implicit height, so their content or containing layout determines it.
Radius roles are `button`, `tile`, `action`, `section`, `panel`, `header`, `media`,
`navigation`, `workspace`, and `tray`. Unknown names throw a descriptive error.
The source's `calibration` object and derived branches in `metric` are the authoritative metric definitions.

The singleton also exposes `lengthScale` and the dimensionless mathematical
constant `cubicCircleFactor` for existing cubic circular contour construction.
Preference constraints are `borderThicknessDefault = 3`,
`borderThicknessMinimum = 1`, `borderThicknessMaximum = 10`, and
`borderRadiusMaximum = 40`. They retain compositor logical-pixel semantics.

## Circular nesting and constraints

A capsule uses both dimensions, including for very short slider fills. A nested
circular rectangle uses its actual outer radius minus its actual inset and the
inner rectangle's own dimensions. Pass the rendered outer radius, not the
unbounded preferred radius, to preserve concentric corners. An existing platform
input defined as an inner contour radius keeps that meaning; deriving its outer
contour adds the inset instead of changing the user's preference.

Screen bounds, an imposed parent size, and intrinsic text height are independent
constraints. They must be named at their source and applied after preferred
metrics. An explicit compact allocation may clip or elide content; bounded radii
still remain valid even at zero size. Non-finite/negative dimensions become zero,
and invalid positive model inputs fall back to calibration defaults. Overflowing
scale products also fall back to a finite baseline. Capsule and inner-contour
radii preserve their exact half-dimension/difference formula after static
metrics have been aligned.

## Bounded migration

This model covers the migrated shared settings/quick controls and the panel
geometry. It is not a claim that every shell component now consumes it. Calendar
layout, launcher layout, scrolling mechanics, screen/frame preferences, SVG and
canvas icon artwork, and unconverted component-specific measurements can still
have independent geometry. Their existing values remain valid until explicitly
migrated. Icon drawing coordinates and animation timing are not control metrics.

Keep adding a metric only when it describes an existing semantic measurement.
For circular track/thumb/fill geometry, derive from the allocated box or inset
instead of adding another independently tunable radius. The pure JavaScript API
accepts its input model as a final argument so geometry invariants can be checked
without starting Quickshell.

## Calibration and migration coverage (2026-10-09)

The baseline is the user's current source captured before this task at
`/home/Mw/ChatGPT/Wizarch Shell/audit/geometry-20261009/baseline/quickshell`,
not an older audit or Git HEAD. Default inputs retain these representative values:

| Role | Default geometry in logical pixels |
| --- | --- |
| Settings button | height 38, radius 9, horizontal label inset 13 |
| Switch | hit box 50×32, track 50×28, thumb 22×22, radius 11 |
| Quick slider/action | height 44, capsule/circle radius 22 |
| Section | padding 18, gap 12, body radius 16 |
| Pill | collapsed 194×42, status width 360, launcher width 420, body radius 12 |
| Pill shoulders | 32 wide on either side, 28 high; original cubic controls retained |
| Quick Settings power | five square cards at normal widths; 64 at content width 324, 52 at 264 |

The switch preserves its existing asymmetric endpoints: left inset 3, checked
right inset 1 (`switchCheckedInset`). Thumb size derives from the track height
minus twice the vertical inset. Its circular radius uses the track end radius
minus that inset, bounded to the thumb box. This does not re-center the existing
checked state.

The pill's concave shoulders remain the original cubic curve. Their coordinates
scale from named calibration metrics. Subtracting an inset from a radius is **not**
an exact offset construction for those noncircular curves, and this system does
not apply that formula to them. Header highlights are separate optical shapes
with their existing radius role, not concentric inner borders of the pill.
The screen frame's existing `frameRadius` input denotes its inner circular
contour, so its meaning is retained. Its quarter-circle coefficient is named.
Canvas emblem coordinates remain a 30-unit artwork coordinate system; its
allocated box provides the transform. Timing, ratios, counts, and zero coordinates
are dimensionless and retain their existing behavior.

Migrated shared components: `ControlTile`, `GlassSlider`, `QuickActionCard`,
`QuickSliderRow`, `SettingsButton`, `SettingsChoice`, `SettingsRow`,
`SettingsSection`, `SettingsSlider`, and `SettingsSwitch`. Migrated shell surfaces:
`Pill`, `ScreenBorder`, `OverlayShadow`, and `panels/QuickSettings`.
The power grid computes its column count from available width and a calibrated
minimum cell (icon + label region + inset), never from an allocated child's
implicit height. Five-card default layouts are preserved; scaled/narrow layouts
can use additional rows.

Remaining independent layout geometry is in 20 QML files: `CalendarDay`,
`CalendarMonthCard`, `FadedDivider`, `MediaCard`, `QuickWheel`, `ScrollingStack`,
`SettingsThemeCard`, `SettingsWindow`, `ThemedScrollBar`, `ThemedToolTip`,
`CalendarView`, `ConnectivityView`, `InputPicker`, `LauncherDragOverlay`,
`LauncherIcon`, `LauncherView`, `NotificationCenter`, `SettingsConnectivity`,
`SettingsView`, and `ThemePicker`. The exact inventory and baseline-to-task patch
are in `audit/geometry-20261009/{migration-inventory.json,implementation.diff}` in
the task workspace. A literal scan is an inventory aid, not proof of universal
coverage: expressions and imported artwork also need review during migration.

The four model properties are a reusable programming API; this task adds no
persisted geometry settings. Qt continues to handle display scaling. A caller
can set `devicePixelRatio` for static alignment, but automatic per-output DPR
adaptation and migration of the remaining panels are unfinished. Those panels
still impose some fixed child dimensions and content-height calculations, so
whole-shell scaling and very small screens are not claimed fully supported.
Pill expanded width and transparent window width are screen-bounded; expanded
height remains driven by the existing panel content contracts. Parent-imposed
sizes can still override intrinsic minima. Complete viewport/reflow migration
must address those allocation contracts before claiming universal usability.

## Extension contract

1. Choose a semantic existing role; use `metric` for preferred lengths and fonts.
   Add a calibrated measurement centrally only if it cannot be derived from an
   existing inset, allocation, content metric, or semantic proportion.
2. Compute content-complete intrinsic height independently of allocated parent
   height. Fit widths to available space and choose breakpoints from upstream
   preferred metrics. Avoid feeding child allocation back into layout choices.
3. Compute corner geometry after final allocation: semantic bounded radius,
   exact capsule, or circular outer-minus-inset as appropriate. Preserve existing
   noncircular paths with their own calibrated formulas.
4. Keep platform/user logical-pixel preferences unscaled via named constraints.
   Do not round animated dimensions. Add geometry-invariant and baseline checks
   for a migrated component before changing its allocation contract.

## Verification and reusable handoff

`tests/geometry.js` tests the production pure model. `tests/geometry-qt.py` renders
actual shared components using isolated offscreen Quickshell and a fake theme.
Its `--pill` mode extracts the actual source shoulder path and body geometry into a
fixture; this checks silhouettes without loading live compositor services.
`docs/geometry-verification.json` records captures, geometry/pixel comparisons,
scale/DPR cases, and limitations. Existing Quick Settings, calendar, and Settings
integration fixtures include the new singleton through `theme-fixture.py`.
No source files were deployed to `/home/Mw/.config/quickshell`, and the installed
shell was not restarted.

Reusable handoff prompt:

> Continue the source-only geometry migration in `/home/Mw/Documents/Codex/Wizarch`.
> Read `docs/geometry-system.md` and `docs/geometry-verification.json`, inspect
> current files and applicable AGENTS.md, and preserve unrelated user edits.
> Use `Core.Geometry` roles/formulas; calibrate against the current appearance.
> Migrate the remaining 20 files incrementally, including parent allocations,
> viewport height, content minima, and per-output pixel alignment. Keep dependencies
> acyclic; preserve default shapes, checked endpoints, focus and dismissal.
> Run isolated baseline comparisons and meaningful existing checks. Do not deploy,
> restart the live shell, or claim whole-shell coverage without verification.

The transparent panel window derives from launcher width plus two shoulder
widths; the reveal target derives from collapsed width plus two shoulders. Header
height derives from collapsed height minus twice the header inset. Those values
are calculated from pixel-aligned upstream metrics, not independent calibration
entries. Resize suppression (`resizeEpsilon = 1`) and edge-approach tolerance
(`revealApproachInset = 2`) retain their existing logical-pixel behavior as named
constraints.

Final checks: 5,119 pure-model assertions pass. Four default shared-control states,
six pill silhouettes, and six complete Quick Settings/power states have zero
pixel differences against the pristine task baseline. Large-font growth and
power-grid reflow pass; Quick Settings, calendar, and Settings integration checks
pass. Parsing succeeds; static Quickshell metadata warnings remain. See the JSON
evidence for the exact tested scope and offscreen limitations.
