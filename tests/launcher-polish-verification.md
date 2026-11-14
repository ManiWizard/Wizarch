# Launcher polish verification — 2026-10-09

This follow-up covers the requested focus, drag motion/grid, fallback icons, command input, footer removal, and Recently used section. The initial interaction contract is documented in `launcher-verification.md`; its earlier screenshots and footer description are superseded here.

## Implemented behavior

- Home, app results, groups, and explicit `>` commands retain the existing navigation and pill contract. The new input caption identifies application search, shell command entry, and execution confirmation. The command button is keyboard focusable; command execution still requires two deliberate Enter presses.
- Compact and large groups use their existing preview border for focus, with no second outer border. App selection uses a thin one-pixel outline.
- Dragging lifts a pointer-following preview while preserving logical grid slots. Stable render identities let neighboring tiles animate to their new positions. The snap destination animates separately from the background grid. Group-center moves remain distinct from edge reordering and menu membership actions that retain the pin.
- The drag background consists of continuous crossing lines in the grid gutters, drawn behind the tiles. Each intersection has a six-pixel plus with slightly brighter strokes. Horizontal and vertical alpha gradients fade the grid at all four edges. Grid visibility also fades on drag start/end.
- Missing icons use a small app-window drawing and name initial. Existing theme-name and file-path resolution remain intact.
- Informational footer text is removed. Actual errors and unavailable-app notices remain visible.
- Recently used appears after pins and participates in spatial keyboard selection, activation, and app context menus. It shows up to four available, visible apps launched through this launcher. Stable desktop IDs are persisted in a launcher-owned bounded history file under `$XDG_STATE_HOME/wizarch/launcher/recent.json`. Temporarily unavailable IDs remain recoverable. Existing desktop launch routing, terminal handling, and working directories are preserved.

## Evidence

`outputs/launcher-polish/verification.json` records the exact verified source hashes and 17 captures. Physical keyboard/pointer tests ran in an isolated nested Wayland compositor using the actual Pill and real desktop entries, isolated preferences and recent history, and the current shared theme code. They exercised single group borders, intermediate and settled snap coordinates, intermediate tile movement, mixed spans, rejected/self/canceled drops, scrolling, reorder and membership, menus, keyboard navigation into recent apps, reopening/restart persistence, no-match/empty/unavailable states, and command confirmation. No arbitrary command was executed. No launcher QML runtime errors, failed loads, binding loops, or assignment warnings were detected.

The inspected drag capture `drag-before.png` confirms crossing lines behind the tiles, brighter intersections, and fading edges; `snap-mid-animation.png` records the independently moving destination. `recently-used.png` shows the populated recent section. `before.png` preserves the previous installed launcher; `installed-home.png` and `installed-collapsed.png` show the deployed launcher in the user's real pill after the reveal/morph settled.

Automated checks passed:

- `tests/launcher.js`: 1,536 mixed layouts, spatial navigation, drop classification, icon URLs, mutations, unavailable ID recovery, and intercepted two-step command routing.
- `tests/launcher.py`: desktop visibility and preference persistence plus isolated history ordering, deduplication, 16 concurrent writers, bounded storage, and corrupted-history recovery.
- Qt `qmllint`: LauncherView, LauncherIcon, and LauncherDragOverlay.

## Changed files and deployment

Product changes are confined to `quickshell/panels/LauncherView.qml`, `LauncherIcon.qml`, new `LauncherDragOverlay.qml`, and new `launcher-history.py`. Focused updates are in `tests/launcher.js`, `launcher.py`, `launcher-fixture.qml`, and `launcher-wayland.py`. No shared theme, material, service, screen, Settings, Pill, or Hyprland files were edited by this follow-up.

Before deployment, installed launcher hashes were compared with the pre-polish snapshot and sources with the completed physical suite. Only the four product files were installed, dependencies first. `outputs/launcher-polish/deployment.json` confirms that preferences and every other installed file were unchanged. The installed shell reloaded successfully with no new warnings. Backups are in `work/launcher-polish/installed-backup`.

## Limits

Recent history starts with apps opened through this launcher; it does not invent usage before tracking began or track launches from other programs. Actual application/terminal and arbitrary command execution were intercepted in isolated routing tests rather than run during desktop verification. Physical drag and keyboard interactions were exercised in the isolated desktop; the installed desktop was separately inspected expanded and collapsed. The Super+Space binding and pill integration were preserved, not rewritten.
