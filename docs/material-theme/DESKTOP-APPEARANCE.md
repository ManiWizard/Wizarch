# Desktop light/dark appearance synchronization

When you apply a Wizarch theme or switch light/dark mode, Wizarch synchronizes desktop light/dark preferences alongside its own shell palette (`quickshell/services/theming/appearance.py` and `activation.py`). It does not rewrite third-party application color schemes with Material role hex values.

## What is updated on activation

1. **GNOME / XDG Portal color scheme (`gsettings`)**:
   - Light mode sets `org.gnome.desktop.interface color-scheme` to `prefer-light`.
   - Dark mode sets `org.gnome.desktop.interface color-scheme` to `prefer-dark`.
   - Standard XDG desktop portals expose this change via `org.freedesktop.appearance` (`color-scheme`).
2. **GTK 3 compatibility (`$XDG_CONFIG_HOME/gtk-3.0/settings.ini`)**:
   - Updates `gtk-application-prefer-dark-theme` and sets `gtk-theme-name` to local `Wizard-Adwaita` / `Wizard-Adwaita-dark` CSS aliases under `$XDG_DATA_HOME/themes/` (which import GTK's built-in Adwaita CSS resources).
   - If you already configured a custom non-Adwaita `gtk-theme-name`, Wizarch preserves your custom theme name and updates only `gtk-application-prefer-dark-theme`.
   - Existing comments, unrelated keys, and sections in `settings.ini` are preserved.
3. **Qt desktop integration**:
   - `examples/hyprland-wizarch.lua` sets `hl.env("QT_QPA_PLATFORMTHEME", "gtk3")` so native Qt apps follow the GTK/portal desktop preference cleanly under Hyprland.
   - `Theme.qml:launchApplication` sets `QT_QPA_PLATFORMTHEME=gtk3` if not already set in the environment (preserving explicit overrides such as `qt6ct`).

## Offline, rollback, and failure behavior

- Draft preview in Settings -> Appearance (`Core.Theme.preview(...)`) never mutates `gsettings`, `gtk-3.0/settings.ini`, or Hyprland. Changes apply only when you commit (`Apply` or quick-settings mode toggle).
- Before modifying desktop settings, `activation.py` records prior `gsettings` values and exact `gtk-3.0/settings.ini` bytes in its transaction journal and restores them if compositor reload or snapshot commit fails.
- `themes.py init` and `--no-compositor` skip live `gsettings` / `hyprctl` mutations for offline staging and tests.
- Running `python3 quickshell/services/themes.py recover` repairs stale desktop mode preferences to match the committed `active.json`.

## Limitations

- Apps set to force an explicit Light or Dark theme ignore system mode until set to Follow System / Automatic.
- Running Qt processes launched before an environment update keep their process environment until restarted.
- Requires `gsettings` (`glib2` / `gsettings-desktop-schemas`), `xdg-desktop-portal-gtk` (or portal backend), and Qt's `gtk3` platform theme plugin for full cross-toolkit synchronization.
