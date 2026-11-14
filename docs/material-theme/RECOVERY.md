# Selection migration, activation and recovery

## Paths

| Content | Location |
| --- | --- |
| Bundled packs and schemas | beside shell.qml: themes/ and schemas/ |
| Persistent selection | `$XDG_CONFIG_HOME/wizarch/theme-selection.json` |
| Independent local overrides | `$XDG_CONFIG_HOME/wizarch/theme-overrides.json` |
| Immutable local imports/registry | `$XDG_DATA_HOME/wizarch/themes/<source>/<revision>/` and registry.json |
| Validated color/pack caches | `$XDG_CACHE_HOME/wizarch/themes/` |
| Committed active snapshot, journal, lock, last/previous good | `$XDG_STATE_HOME/wizarch/theme/` |
| Generated compositor colors | `$XDG_CONFIG_HOME/hypr/wizarch-theme.lua` |
| Local dependency environment | `$XDG_DATA_HOME/wizarch/theme-runtime/` |

Unset XDG roots use the standard home defaults. Relative XDG paths are rejected. Portable packs never contain absolute runtime paths; active snapshots deliberately include resolved file URIs and content revisions. A source checkout and installed shell share a selection when using the same XDG roots. Verification must use separate roots and compositor IPC, as the test harness does.

## Migration

The old `state/active.json` is read only during first migration; it is never rewritten or deleted. wizarch/eclipse remain their identities under the bundled namespace. The selected pack and matching wallpaper are retained. Both current bundled manifests now use schema 1 and include light/dark exports; historical schema-less manifests remain readable through a bounded dark-only adapter. The adapter validates canonical roles and metadata, accepts only the former fields, validates the old compositor color/geometry types and ranges, and never executes or applies pack geometry. New authoring writes only schema 1.

A valid current committed snapshot wins over an old state file. If a committed snapshot is corrupt, recover the durable last-good record first. A valid selection without a current snapshot is reapplied by its stable identity. Corrupt or unavailable established selection is reported and retained; the QML built-in resolved palette provides a usable surface without choosing an unrelated pack. A fresh installation without any prior selection defaults to Wizarch. Missing Eclipse private artwork makes Eclipse a diagnostic unavailable pack; no image is fabricated or redistributed.

Geometry formerly lived in wizarch-theme.lua. Color-only generation would otherwise expose different base rounding/border values. During this machine's deployment, the measured prior values are preserved in a separate static wizarch-theme-geometry.lua imported immediately before the color fragment. Activation never writes that geometry file or any other compositor settings. For another installation, transfer the old valid geometry to its existing base config or a separate static fragment before adopting the color-only service. Do not copy a theme's geometry into the new pack schema.

If a wallpaper ID is removed from metadata, a later compatible activation preserves another matching ID or chooses the pack default. An explicitly requested missing ID fails. If a required file is missing while still declared, the pack is invalid and cannot activate; its existing committed colors remain available, and Wallpaper paints surface if the current URI cannot load. Earlier imported directories remain intact for rollback. Local overrides never modify pack content and invalid overrides fail before mutation.

## Actual transaction protocol

All activation, rollback and local import operations share an advisory flock under XDG state. CLI requests are serialized in lock-acquisition order; there is no promise that simultaneous processes acquire in invocation order. Lock acquisition has a 15-second timeout. QML keeps one running request and coalesces repeated pending activation requests to the latest complete request. A dedicated in-flight flag spans process startup and exit. In-flight transactions are not cancelled halfway through; pending requests can be replaced. Preview is presentation-only, so cancelling it needs no compositor rollback.

1. Reconcile any prior journal while locked. Validate metadata, palette, contrast, paths/assets, mode, wallpaper and local overrides. Stage the complete snapshot in memory, with a content-derived revision.
2. Capture exact previous active/selection/compositor bytes. Read a baseline of compositor errors. Durably fsync/rename a journal containing those prior files, the full candidate and baseline errors before any compositor write.
3. Atomically publish only the shell-owned color Lua, reload Hyprland through argv, and check for errors absent from the baseline. Reload and query timeouts are 5 seconds; three bounded 80 ms settling checks follow. No pack data becomes a command, script, Lua expression or geometry/effect value.
4. Durably write the selection, then atomically publish active.json. **active.json publication is the observable commit point.** QML reads one complete revision containing colors, mode and asset URIs; it never merges old/new role bags.
5. Persist the previous-good and current last-good byte records, then durably remove the journal. Idempotent requests skip reload and publication once reconciliation is complete.

This is not physical atomicity across a compositor and several files. Hyprland may observe staged colors before QML publication; the short cross-process interval is unavoidable here. The journal defines the durable decision and repair behavior. A crash before active publication restores the prior files and reloads. A crash after publication finalizes the committed snapshot, repairs selection/color files and records the correct immediate previous snapshot. Startup recovery applies the same decision.

A normal rejection/write failure before publication restores all prior files and checks the reloaded compositor against the original baseline. Rollback failures are reported separately and retain the journal and recoverable snapshot. A finalization error after publication is reported as **committed with a recovery warning**, retaining the journal; it does not pretend an already observed commit never happened. Recovery completes the last/previous-good records. Unrelated pre-existing compositor errors do not masquerade as theme rejection. Text-identical error lines cannot establish causal attribution beyond that comparison.

Atomic writes fsync both file and directory. Temporary write files are removed by normal cleanup; a process killed during a write can leave a small `.active.json…` or similar temporary file. These are not observed as active snapshots. Recovery handles the journal; orphan temporary files can be removed after confirming no operation is running. No persistent applying flag exists to remain stuck after restart.

## Commands and backups

```sh
python3 quickshell/services/themes.py recover
python3 quickshell/services/themes.py rollback
python3 quickshell/services/themes.py list
python3 quickshell/services/themes.py apply bundled:eclipse --mode dark --wallpaper original
```

Rollback restores the immediate prior committed snapshot through the same engine, including compositor validation. If no prior committed theme exists, it reports that fact. It does not mutate local override files. `--no-compositor` is for isolated directories/tests, not a successful live activation claim. `init` writes without contacting Hyprland and is retained for installation compatibility.

The completion report lists this deployment's exact backup and installed files. To undo the software deployment, restore only listed files from that backup (and remove only the newly added listed files), restore the saved theme Lua/main-config bytes and any new theme-state files, then reload Hyprland and allow Quickshell's normal source reload. Keep all unrelated current user files. Do not reset or copy an entire checkout over an installation. The preexisting preferences, wallpaper files, workspace maps and device settings are not part of this deployment.

## Review follow-up restore point

The eight reliability/preview fixes have a separate before-fix backup at `/home/Mw/Documents/Codex/Wizarch/work/material-review-backup/manifest.json`. It records the user's current Wizarch dark/Nocturne selection, exact current committed active/selection/color bytes, preserved unrelated file hashes and each installed code file's before/after hash. Restore only the listed code targets to undo these fixes; the earlier deployment backup remains available to undo the whole Material migration. Do not reset the checkout or overwrite independent launcher work.

Registered source catalogs that are unavailable/corrupt appear as diagnostics while unrelated sources and bundled packs remain accessible. A malformed whole registry retains bundled discovery and reports the registry error; repair from a backup rather than silently replacing its registrations. Imports reject prospective catalog/source/storage overflow before registry publication. Derived generation caches can regenerate after corruption; invalid authored exports remain errors and are not deleted.

Local import fsyncs files, nested directories bottom-up, newly created ancestors and both rename parents before registration. This is an explicit durability protocol, with call/order tests; physical power loss remains unverified. Retained managed quota accounting includes final compiled content and exact registry bytes. An unchanged immutable revision is revalidated/reused without charging duplicate content. Temporary staging has a separate collection bound.


## Desktop mode synchronization

Live activation now captures gsettings mode/theme and bounded GTK3 settings bytes in the journal, updates desktop appearance before active.json, and restores them on pre-commit failure. Startup, rollback and unchanged Apply synchronize the committed mode. Static GTK resource aliases remain installed. See [desktop integration and restore instructions](DESKTOP-APPEARANCE.md). Offline `init`/`--no-compositor` skip desktop writes as well as compositor changes.
