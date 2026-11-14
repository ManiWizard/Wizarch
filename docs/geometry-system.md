# Geometry system

All Wizarch QML surfaces derive layout metrics and corner radii from `quickshell/core/Geometry.js` through `Core.Geometry` (`Geometry.qml`) and per-window `Core.GeometryContext` (`GeometryContext.qml`).

## Unified shape profile

All UI corner radius roles in `Geometry.radius(role, width, height)` use one shared formula defined in `Geometry.js`:

```text
radius = min(min(width, height) / 5, metric("buttonHeight") / 3)
```

At the default 100% UI scale (`buttonHeight = 38`), the ceiling is `38 / 3 ≈ 12.67` logical pixels:

- Smaller controls scale smoothly with their shorter edge (`width / 5` or `height / 5`), keeping consistent rounded-rectangle corners instead of circles.
- Larger cards and panels share the button-height ceiling so corners do not grow disproportionately on large panels.
- Concentric inner elements use `insetRadius(outer, inset, width, height)` (`max(0, outer - inset)` bounded by the inner box).
- User-configured compositor screen-border rounding stays unscaled logical pixels constrained via `constraint(...)` (`borderThickness` 1–10 px, `borderRadius` 0–40 px) and optionally tracks Hyprland's live outer rounding via `quickshell/services/frame-metrics.py`.

## Per-output UI scaling

`Geometry.qml` binds `uiScaleByOutput` from `SystemServices.preferences` and validates per-output values in `[1, 2]` at `0.25` steps (`100%`, `125%`, `150%`, `175%`, `200%`), selectable per display in Settings -> Appearance.

Top-level windows (`Pill.qml`, `QuickWheel.qml`, `SettingsWindow.qml`) instantiate a `Core.GeometryContext` bound to their owning `screen.name` and `devicePixelRatio`. Child components resolve their nearest ancestor `uiGeometry` via `Core.Geometry.contextFor(parent)`.

## API summary

| Helper | Purpose |
| --- | --- |
| `dp(value)` | Scale a logical length by `lengthScale` and round once to the output's physical pixels (`devicePixelRatio`). |
| `metric(name)` | Look up a named calibrated length or derived window metric (`panelWindowWidth`, `revealWidth`, `headerHeight`). |
| `radius(role, w, h)` | Apply the unified shape profile to any named role in `radiusRoles`. |
| `insetRadius(outer, inset, w, h)` | Compute a bounded inner radius concentric with an outer container. |
| `controlHeight(role, contentH)` | Return at least the calibrated height role floor (`button`, `choice`, `switch`, `slider`, `glassSlider`, `row`, `quickSlider`, etc.). |
| `wheelOuterRadius(w, h)` / `wheelInnerRadius(outer)` | Compute responsive quick-action wheel geometry fitted to the screen viewport. |
| `stroke(focused)` | Return 1 or 2 scaled logical pixels, clamped to at least one physical pixel. |
| `constraint(name)` | Return unscaled logical compositor/gate constants (`borderThickness*`, `borderRadiusMaximum`, `resizeEpsilon`, `revealApproachInset`). |

Note: while the core geometry API and main surfaces scale cleanly via `GeometryContext`, a few secondary sub-panels (such as `NotificationCenter`) retain a mix of `uiGeometry` radii and fixed pixel typography.

## Verification

- `node tests/geometry.js` checks pure calculations, bounds, cross-role equality, and per-output scaling across `Geometry.js`.
- `python3 tests/geometry-coverage.py` checks QML files for unapproved local corner radius definitions outside `Core.Geometry`.
- `python3 tests/ui-scale-preferences.py` validates `uiScaleByOutput` preference persistence; `python3 tests/ui-scale-qt.py` exercises offscreen Qt geometry bindings.
