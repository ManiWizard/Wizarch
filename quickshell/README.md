# Wizarch Quickshell source

This directory contains the QML shell, service helpers, icons, and theme assets. For screenshots, dependencies, manual installation, shortcuts, and licensing, see the [repository README](../README.md).

The `state/active.json` file is generated for each installation and is not committed. The optional Eclipse theme appears in the theme picker only after you supply its excluded wallpaper asset.

Window spacing is adjustable in Settings from 0–150%, with a default of 75%. The original 100% profile uses 5 px inner and 20 px outer gaps; values round to whole pixels. Changes apply live, save in the shell preferences, and generate `~/.config/hypr/wizarch-spacing.lua`. The example Hyprland Lua configuration loads that fragment on reload/login.

Reliability behavior: calendar week headings follow their actual dates; launcher drag release explicitly completes drops, with group center for membership and 16 px side zones for ordering. `Super+V` opens clipboard and `Super+Shift+V` toggles window floating. Settings/themes IPC opens the shared managed Settings window, tiled by default without toggling it closed. Preference writes coalesce for 180 ms through one writer; failed changes remain queued with Retry in settings. Moving away from the top-center reveal target cancels pending reveal.

Settings uses a normal tiled application window with a searchable category sidebar (Ctrl+F), grouped controls, theme previews and bundled wallpaper thumbnails. The navigation becomes an icon rail below 820 px. Appearance previews select complete theme packs; wallpaper thumbnails apply their theme, and the colour swatches show the current palette. Panel contains placement, auto-hide and screen-frame preferences; Sound, Notifications, Multitasking, Displays, Power, Wi-Fi, Bluetooth, Network and Keyboard have separate pages. Save failures and Retry remain visible across all pages.

The quick-action wheel opens with `Super+W`, while `Super+C` keeps closing the focused window. Arrows select their cardinal direction; Tab/Shift+Tab cycle all eight actions and Enter/Space confirm; Escape, right-click or a centre/outside click cancels. Mouse movement highlights sectors and a left click confirms. The focused monitor receives a transparent overlay with a compact continuous ring, icons and a selection arc using the active Wizarch palette. The circular hub shows the selected action name or Cancel in the dead zone. Both wheel and real cursor open at that monitor’s center; closing never moves the cursor. It reserves no desktop space. All eight entries route to existing shell panels, Settings/Themes or the installed screenshot tool. Clipboard captures the app focused before the wheel opened.

Regression checks: run `node tests/reliability.js`, `python3 tests/reliability.py`, `python3 tests/preference-writer-qt.py`, and `python3 tests/settings-window-qt.py` from the repository. The Qt test needs the existing Quickshell/Wayland session and uses an isolated temporary preference store. No live user preference values are changed by these tests.

Wheel regression checks: `node tests/quick-wheel.js`, `python3 tests/quick-wheel.py`, and `python3 tests/quick-wheel-qt.py`. The Qt check requires the existing Wayland session, briefly maps a wheel with an isolated action sink, and performs no real shell action.

Material themes: see [authoring](../docs/material-theme/AUTHORING.md), [recovery](../docs/material-theme/RECOVERY.md), and the [completion report](../docs/material-theme/COMPLETION-REPORT.md) for the local pipeline and verification evidence. GitHub transport and update execution remain deferred.
