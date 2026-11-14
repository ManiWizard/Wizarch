# Design-preserving desktop upgrade

This upgrade retains the installed palette, wallpaper, geometry model, monitor
configuration, shortcuts, generated configuration ownership and preference formats.
No package upgrade or compositor migration is involved. The baseline includes
uncommitted source files and the installed Quick Settings “Sound” label.

## Runtime changes

`StateReader.qml` provides one subprocess at a time per data source. It coalesces
bursts within an 80 ms window that continuous events cannot postpone, validates exit status and JSON before publication, retries failed reads
with delays capped at 30 seconds, and terminates a hung helper after 15 seconds.
A failed start is also retried. Callers retain their last valid snapshot and expose
errors through the existing UI error areas. Successful recovery clears the
reader's error. The accepted empty object still represents an intentionally empty
snapshot; helper failure is distinguished by exit status or required fields.

Window occupancy and hidden tray windows share one monitor/client read, replacing
independent 2- and 3-second polls with event updates and 10-second reconciliation.
Frame metrics update on compositor reload/hotplug and every 30 seconds. Workspace
and scrolling-frame readers reconcile every 10 seconds, in addition to events.
Unchanged workspace state is not rewritten. Theme catalog watchers reconnect
without discarding the previous catalog or clearing unrelated theme errors.

Brightness edits update immediately, serialize writes, keep the newest edit while
a write is in flight, and reject status polls from an older control generation.
A failed write restores the last confirmed level while reporting the failure.
Preferences retain their existing coalescing, atomic merge and explicit Retry.

Flat Settings buttons now draw the existing focus outline for keyboard focus.
Closing Settings search returns focus to the search button. Search, error-banner,
and category-group offsets use the owning geometry scale; default dimensions are
unchanged. Settings minimum dimensions scale with the controls. Quick Settings
uses a bounded viewport and the existing scrollbar when enlarged content exceeds
the monitor budget; keyboard focus scrolls into view. Its normal layout is unchanged.
The wheel's existing radial disk/hub are deliberately preserved artwork.

Workspace/layout fragments use unique temporary files, preserve permissions and
fsync their contents and containing directory. Hotplug results use the latest
monitor query while retaining stored workspace identities. Spacing generation
finishes before applying live gaps, serializes concurrent writers, and restores
previous live gaps if publishing the generated fragment fails. Its rollback
preserves asymmetric gaps and reports a rollback failure separately.

## Deploy and restore

`scripts/deploy-upgrade.py` accepts a JSON mapping of absolute paths:

```json
[{"source":"/absolute/staged/StateReader.qml","target":"/absolute/config/core/StateReader.qml"}]
```

Prepare a separate manifest per stage, outside the repository:

```sh
python3 scripts/deploy-upgrade.py prepare /absolute/release/stage.json --mapping /absolute/release/mapping.json
python3 scripts/deploy-upgrade.py apply /absolute/release/stage.json
python3 scripts/deploy-upgrade.py restore /absolute/release/stage.json
```

Preparation saves before/after bytes, modes and hashes. Apply validates all payloads
and targets before the first write, then rechecks each target immediately before
replacement. Restore permits only recorded before/after content and refuses later
edits. New files are removed only when listed in the manifest and still match the
recorded deployment. Interrupted deployments can be restored. The CLI serializes
operations on each manifest with a lock. It performs no commands or reloads.

These checks are not filesystem-wide atomicity: an external writer can race the
final check/rename, and an interruption can leave a partially applied stage.
Preserve the manifest and its `.files` directory, restore that stage, investigate,
and rerun verification. Never copy a complete checkout over the live installation.

Deploy in order: shared reader/services; keyboard and sizing; Hyprland helper
hardening. New QML types and helper interfaces must precede their consumers.
A fourth, single-file checkpoint bounds coalescing during sustained event streams.
A fifth checkpoint fixes constrained Quick Settings and scaled Settings minima.
Restore all five checkpoints in reverse order. Quickshell observes installed QML changes automatically. These changes need no
Hyprland session restart or main-configuration edits.

## Verification

Run `tests/upgrade-checks.py --node /absolute/node --output /absolute/check-logs`
for the safe model, storage and offscreen QML suites. New checks cover reader
failure/retry/startup/timeout, theme watcher reconnection, brightness races,
keyboard focus, generated-file failures, hotplug races and manifest restoration.
They use temporary state; hardware setters are mocked.

`tests/upgrade-wayland.py` requires an explicit isolated session `launch.json`, a
source tree and output folder. It refuses the caller's compositor runtime and
signature. It uses frozen clock, theme palette and device/media/notification
fixtures with production visual components. It captures eight surfaces on each of
two `UPGRADE-A`/`UPGRADE-B` outputs and optionally exercises virtual hotplug.
Use `--scale-check --input-only --input-driver /absolute/driver` for the 200%
viewport and real keyboard scroll checks. The input driver speaks only to the
explicit isolated compositor; no shell action handler is connected in the fixture.

It reads the local installed theme/preferences for the baseline, but writes only
the supplied output directory. Use the same installed selection for both runs.
Keep captures private because they include local wallpaper artwork.

The installed Hyprland 0.56.2 standalone `--verify-config` crashed during this
upgrade, including with the pre-existing configuration. Use successful isolated
compositor reloads, generated-rule evaluation and `hyprctl configerrors` as the
available validation evidence; do not report the standalone verifier as passed.

The optional Material pipeline suites require the already-provisioned theme
runtime: run `tests/material-themes.py` and `tests/material-appearance.py` with
`~/.local/share/wizarch/theme-runtime/bin/python`. They use mocked compositor and
desktop setters and temporary state.
