# Theme paths, activation transactions, and recovery

## XDG storage layout

| Purpose | Location |
| --- | --- |
| Bundled packs and schemas | `<quickshell-dir>/themes/` and `<quickshell-dir>/schemas/` |
| Saved selection | `$XDG_CONFIG_HOME/wizarch/theme-selection.json` |
| Local user overrides | `$XDG_CONFIG_HOME/wizarch/theme-overrides.json` |
| Imported immutable packs | `$XDG_DATA_HOME/wizarch/themes/<source>/<revision>/` |
| Validation caches | `$XDG_CACHE_HOME/wizarch/themes/` |
| Active snapshot, journal, lock, backups | `$XDG_STATE_HOME/wizarch/theme/` (`active.json`, `last-good.json`, `previous-good.json`, `operation.lock`) |
| Generated Hyprland colors | `$XDG_CONFIG_HOME/hypr/wizarch-theme.lua` |
| Optional Python venv | `$XDG_DATA_HOME/wizarch/theme-runtime/` |

Legacy `quickshell/state/active.json` is migrated read-only if encountered on first startup when `$XDG_STATE_HOME/wizarch/theme/active.json` does not yet exist.

## Transaction & fallback behavior

`quickshell/services/theming/activation.py` serializes `apply`, `rollback`, `recover`, and `import` via `operation.lock` (`flock`, 15 s timeout):

1. Reconciles any incomplete prior transaction journal.
2. Validates pack manifests, palette contrast, asset files, and optional overrides in memory.
3. Saves previous bytes and baseline `hyprctl configerrors` into a transaction journal.
4. Writes `$XDG_CONFIG_HOME/hypr/wizarch-theme.lua` atomically, reloads Hyprland, checks for new config errors, and updates desktop appearance settings.
5. Writes `theme-selection.json` and atomically replaces `active.json` (`Theme.qml`'s `FileView` commit point).
6. Records `last-good.json` / `previous-good.json` and removes the journal.

- If validation or Hyprland reload fails before `active.json` is published, prior files are restored and Hyprland is reloaded back cleanly.
- If `$XDG_STATE_HOME/wizarch/theme/active.json` is corrupt or missing on startup, `Theme.qml` runs `themes.py bootstrap` to recover `last-good.json` or reapply the saved selection; if no valid theme can be resolved, `Fallback.js` supplies a usable built-in dark palette while displaying the error in Quick Settings / Settings -> Appearance.

## CLI commands

```sh
python3 ~/.config/quickshell/services/themes.py list
python3 ~/.config/quickshell/services/themes.py apply bundled:wizarch --mode dark
python3 ~/.config/quickshell/services/themes.py rollback
python3 ~/.config/quickshell/services/themes.py recover
python3 ~/.config/quickshell/services/themes.py init wizarch
```

`init` writes the initial snapshot and `wizarch-theme.lua` offline without calling `hyprctl` or `gsettings`. `--no-compositor` performs validation and file writes without contacting Hyprland.
