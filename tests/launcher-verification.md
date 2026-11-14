# Launcher implementation and verification — 2026-10-09

The launcher keeps its existing home, All apps, compact/large groups, group editor, scoped search, and `>` convention. No feeds, accounts, recommendations, new navigation surface, theme roles, or shared services were added. The product structure is intentionally close to the inspected 433-line launcher; the implementation changes are larger than the visible UX changes because placement, keyboard handling, recovery, and icon presentation now have explicit contracts.

## Interaction contract

- Home displays the ordered mix of pins and groups. Apps/compact groups occupy one cell; large groups span 2×2 cells. Cell dimensions, gap, and spans determine tile bounds. Group contents and All apps use the same cell model; search retains a compact list.
- Typing searches the current scope. All apps searches the application catalog; a group searches its members. Edit apps toggles membership and retains existing home pins.
- `>` selects command mode. First Enter reviews/arms execution; a separate Enter confirms. Editing the text disarms it; auto-repeat does not confirm. No command runs on a mere search or empty command.
- Arrows select visible tiles spatially on home, by rows/columns in app grids, and vertically in results. Enter activates that visible selection. Tab exposes focused controls/tiles. Escape cancels dragging, closes a menu/deletion prompt, clears the query, goes back, then dismisses from home. Menu or Shift+F10 opens the selected object's menu.
- Dragging retains the source's calculated slot. A tile edge shows a before/after insertion bar; an app over a group's central region shows “Move into group.” Reordering and membership are distinct operations. Moving into a group removes its home pin; menu “Add to … · keep pin” and Edit apps retain it. Rejected/self drops and cancellation have no mutation. Held drags near the viewport edge scroll the content.
- App menus provide valid launch, pin, group creation and membership actions. Group menus provide open, Edit apps, preview size, rename and confirmed deletion. Empty-space menus provide creation and All apps where applicable. Menus stay within the viewport, scroll when needed, support keyboard selection, close on Escape/outside click, and restore focus. Group deletion leaves apps installed and pins intact.
- Missing icon names/failed images use one fallback. Absolute file icons use encoded file URLs; named icons use Quickshell's existing icon API. Unavailable saved apps retain a visible placeholder and saved identity. Intentionally hidden desktop entries remain excluded. Terminal argv and working directories retain the existing execution contract.

## Reproduced baseline defects

The inspected source and installed LauncherView were byte-identical. Their SHA-256 was `22b49e40bf5536b039cfce3e95bb073eefb2cb0247a33ca5c1602568a555dcc8`.

1. Actual pointer drag/release outside the launcher left the compact group at x=131, y=672 instead of its original x=50, y=122. `outputs/launcher/before-canceled-drop.png` and `baseline-tiles.json` record the displaced tile. The old DragHandler moved the layout item itself.
2. The actual old reorder function erased `app:temporarily-missing` from saved ordering because it rebuilt order from only visible home entries. `baseline-persistence.json` records the isolated reproduction. The new model keeps logical identities, including unavailable/hidden saved entries, through mutations.
3. Home selected the first pinned app although the first visible item was a group. The original home Enter routed through the app-results array. The physical replacement suite now verifies Enter opens the selected group and arrows follow mixed tile geometry.
4. Real installed Avahi/lstopo icon names resolved to an empty icon URL, producing blank artwork. These apps remain listed with the consistent fallback. The installed v2rayN desktop entry has an absolute PNG path; the suite verifies that its image becomes Ready through the file URL. No desktop entries, icon themes, or packages were changed.

## Automated checks

Run from the repository:

```sh
/usr/lib/chatgpt/resources/cua_node/bin/node tests/reliability.js
python3 tests/launcher.py
python3 tests/reliability.py
/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml quickshell/panels/LauncherView.qml quickshell/panels/LauncherIcon.qml
```

The launcher JS suite exercises 1,536 mixed layouts across one through six columns, checks nonoverlap and deterministic geometry, spatial selection, center/edge/self classification, file URL encoding, invalid reorders, pin versus membership mutations, unavailable IDs, and actual QML command/app routing with execution intercepted. Python checks XDG visibility and entry precedence, nested desktop IDs, and actual preference-store roundtrips in a temporary configuration, retaining unrelated preference fields. Existing queue/pointer/calendar and preference-store reliability checks also pass. QML lint and whitespace checks pass.

## Actual desktop input and rendering

`tests/launcher-wayland.py --session work/launcher-verification` runs production LauncherView inside the real, unmodified Pill in an isolated nested Hyprland session. `launcher-fixture.qml` exposes observation/setup IPC; `launcher-input.c` injects real Wayland keyboard/pointer events into that isolated session. The runner refuses the user's runtime/Hyprland signature and requires live isolated sockets. It needs an already running compositor, launch.json, and the compiled input driver; Wayland protocol bindings are test support, not product dependencies.

The completed run produced 15 captures and passed physical arrows/Enter/Escape/Tab, pointer and keyboard app/group menus, menu scrolling/clamping/outside dismissal, deletion cancellation, preview switching, group rename/create/delete, rejected/self/Escape-canceled drops, edge reorder, group-center move, membership retaining pins, reopening and process-restart persistence, file/missing icons, no-match and command-confirmation states, empty home/group/catalog, long-menu keyboard scrolling, and crowded mixed content with drag scrolling. Pairwise actual tile bounds were checked for overlap. There were no launcher QML runtime errors, assignment errors, binding loops, failed image loads, or parse errors in the checked logs. The isolated environment has pre-existing device/notification-service availability warnings; these are distinct from launcher behavior.

`outputs/launcher/verification.json` records source hashes, states, geometry, actual desktop entries, and screenshot paths. Captures include `after-home.png`, `drag-before.png`, `drag-membership.png`, `context-group.png`, `command-confirmation.png`, `all-apps.png`, `after-restart.png`, and `scrolling-drag.png`.

## Deployment and scope audit

Only these product files were written/deployed:

- `quickshell/panels/LauncherView.qml`
- `quickshell/panels/LauncherModel.js`
- `quickshell/panels/LauncherIcon.qml`
- `quickshell/panels/launcher-desktop.py`

Focused tests are `launcher.js`, `launcher.py`, `launcher-fixture.qml`, `launcher-input.c`, `launcher-wayland.py`, and this report. The existing reliability JS file now invokes the focused launcher suite instead of its obsolete Flow/DropArea assertions; its other checks are retained.

Before deployment, the installed launcher was checked against the original hash and every new source against the latest physical-verification hashes. The four files were installed individually and the installed shell reloaded successfully. `outputs/launcher/deployment.json` confirms that every other installed file and the user's preferences were unchanged. Launcher backups are under `work/launcher-verification/installed-backup`. Source/installed Pill and ThemedScrollBar hashes matched. Theme, materials, frame/shadow, Settings, services, shell, and Hyprland bindings were not edited by this work.

The actual installed launcher was shown and dismissed using its existing panel IPC. `installed-home.png` and `installed-collapsed.png` show the connected pill with the user's current theme; capture waited for reveal/morph to settle. The Super+Space binding remains `wizarch-open launcher`, and its existing routing contract is unchanged.

## Verification limits

Physical command testing stops at confirmation. Command execution, GUI launch, terminal argv and working-directory forwarding are intercepted in isolated function tests; arbitrary shell commands were never executed for verification. The suite uses actual desktop entries on this machine, so its file-icon assertion is intentionally environment-specific. Super+Space's actual human key chord was not exercised on the user's desktop; its configuration and panel routing were inspected and the existing IPC route exercised. This work preserves the shared preference writer, including its error/retry behavior; the launcher displays its save error rather than claiming a failed write succeeded. The 10–15% UX limit is a qualitative product constraint, not a measurable code-diff percentage.
