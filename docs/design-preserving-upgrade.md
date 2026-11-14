# Runtime reliability and deployment tools

Wizarch separates Qt/QML presentation from stateful system helpers under `quickshell/services/` so failures are reported in the UI without crashing or overwriting user settings.

## State readers & queues

- **`quickshell/core/StateReader.qml`**: Runs at most one helper subprocess at a time per data source, coalesces event bursts over an `80 ms` window, rejects hung processes after a `15 s` timeout, retries failed or crashed reads with exponential backoff up to `30 s`, and retains the last valid snapshot until recovered.
- **`quickshell/services/window-state.py` & `frame-metrics.py`**: Combined monitor occupancy and minimized-tray snapshot (`window-state.py --snapshot`) plus outer window corner-radius matching (`frame-metrics.py`) triggered on Hyprland events (`Connections { target: Hyprland }`) with periodic reconciliation.
- **`quickshell/services/workspaces.py` & `layouts.py`**: Manage nine independent workspace slots per monitor (`$XDG_CONFIG_HOME/wizarch/workspace-monitors.json` and generated `$XDG_CONFIG_HOME/hypr/wizarch-workspaces.lua`) plus remembered Dwindle/Scrolling choices (`$XDG_CONFIG_HOME/wizarch/workspace-layouts.json` and `$XDG_CONFIG_HOME/hypr/wizarch-layouts.lua`). Writes use file locks, temporary files, preserved permissions, and directory `fsync`.
- **`quickshell/core/PreferenceQueue.js` & `preferences.py`**: Debounce preference updates (`180 ms`) through one writer queue. Failed writes stay queued and show a visible Retry banner across Settings and Calendar.
- **`quickshell/services/desktop-status.py` & `SystemServices.qml`**: Track hardware and session capabilities (Wi-Fi radio/rfkill, NetworkManager hotspot, backlight sysfs, power profiles, `wf-recorder`, hibernate support) with generation tracking so stale status polls never overwrite newer brightness edits. Controls for absent hardware or missing tools stay visibly unavailable rather than fabricating values.
- **`quickshell/services/window-spacing.py`**: Applies gap scaling (`0–150%`, default `75%`) atomically to `$XDG_CONFIG_HOME/hypr/wizarch-spacing.lua`, rolling back live compositor gaps if publishing the fragment fails.

## Manifest deployment helper (`scripts/deploy-upgrade.py`)

For targeted upgrades across an existing installation, `scripts/deploy-upgrade.py` supports manifest-based staging with byte/hash checks:

```sh
python3 scripts/deploy-upgrade.py prepare /path/to/stage.json --mapping /path/to/mapping.json
python3 scripts/deploy-upgrade.py apply /path/to/stage.json
python3 scripts/deploy-upgrade.py restore /path/to/stage.json
```

`restore` verifies recorded before/after hashes before restoring files and refuses to overwrite post-deployment edits. For standard full installation and removal, use `scripts/install.sh` and `scripts/uninstall.sh`.

## Verification suites

Most logic and offscreen Qt tests run standalone from the repository root (`tests/`):

- **Pure JS suites** (`calendar.js`, `geometry.js`, `launcher.js`, `quick-wheel.js`, `reliability.js`): run via Node in CommonJS mode (note: if running from outside `tests/` with an outer ESM `package.json`, run with `tests/` as working directory).
- **Python unit suites**: `tests/windows.py`, `tests/layouts.py`, `tests/workspaces.py`, `tests/calendar-preferences.py`, `tests/quick-wheel.py`, `tests/reliability.py`, `tests/scrolling-frame.py`, `tests/scrolling-stack.py`, `tests/window-spacing.py`, `tests/ui-scale-preferences.py`, `tests/upgrade-deployment.py`, `tests/geometry-coverage.py`.
- **Qt/Wayland suites** (`tests/*-qt.py`, `tests/upgrade-wayland.py`): require PyQt/Quickshell Qt runtime (and a running Wayland/Hyprland session for Wayland-only checks like `quick-wheel-qt.py` or `material-wayland.py`).
- **Automated runner**: `python3 tests/upgrade-checks.py --node "$(command -v node)" --output /tmp/wizarch-checks` runs the non-live check suite into a log directory.
