# Wizarch Quickshell source

This directory contains the QML shell (`shell.qml`, `core/`, `components/`, `panels/`), Python service helpers (`services/`), icons (`assets/`), JSON schemas (`schemas/`), and bundled theme metadata (`themes/`). For installation, uninstallation, package requirements, keybindings, and troubleshooting, see the [repository README](../README.md).

## Runtime notes

- **Theme state (`$XDG_STATE_HOME/wizarch/theme/active.json`)**: Generated on first startup or via `themes.py init wizarch`; not committed to Git. If unavailable, `core/Fallback.js` supplies a usable built-in palette. The bundled `eclipse` pack stays flagged diagnostic/unavailable until you place your local image at `themes/eclipse/assets/wallpaper.jpg`.
- **Window spacing**: Configurable in Settings -> Multitasking (`0–150%`, default `75%`, where `100%` corresponds to `5 px` inner / `20 px` outer gaps). Applies live through `services/window-spacing.py` and persists to `$XDG_CONFIG_HOME/hypr/wizarch-spacing.lua`.
- **Workspaces & Scrolling**: Nine independent slots per monitor (`services/workspaces.py`) plus remembered Dwindle/Scrolling choices (`services/layouts.py`).
- **Quick-Action Wheel**: Triggered via `Super+W` (`services/quick-wheel.py`), centering the cursor and wheel overlay on the focused monitor without reserving desktop space.
- **Settings**: Managed tiled window (`SettingsWindow.qml`) with `Ctrl+F` search across 12 categories, collapsing to an icon rail below `820 px`, plus preference coalescing and an explicit Retry banner on write errors.

## Documentation & tests

- [Geometry system](../docs/geometry-system.md)
- [Media card](../docs/media-card.md)
- [Runtime reliability & deployment](../docs/design-preserving-upgrade.md)
- Material theming: [Authoring](../docs/material-theme/AUTHORING.md), [Recovery](../docs/material-theme/RECOVERY.md), [Role map](../docs/material-theme/ROLE-MAP.md), [Desktop appearance](../docs/material-theme/DESKTOP-APPEARANCE.md), and [GitHub contract](../docs/material-theme/GITHUB-CONTRACT.md) (remote GitHub importing is unimplemented in this build).

See `tests/` for the JS, Python, and Qt/Wayland test suites (`tests/upgrade-checks.py` runs the non-live check suite).
