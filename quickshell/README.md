# Wizarch

A compact Quickshell for Hyprland: flat Material surfaces, progressive disclosure, deliberate spacing, and a wizard-hat Arch-inspired mark.

## Use

- Left-click the hat: installed application launcher.
- Right-click the hat: themes, in the same compact 360 × 208 view as the week calendar.
- Clock: week/calendar. Status: quick settings.
- Quick settings: Wi-Fi and Bluetooth tiles, a four-column control grid, volume and brightness sliders, and a now-playing card when media is active. Unavailable controls are dimmed.
- The bell opens a titleless notification center with dismiss and clear-all controls. Quickshell receives notifications through its built-in notification service.
- Outside click or Escape dismisses. Non-launcher panels time out after 30 seconds of inactivity.
- Theme changes apply to both screens, wallpaper, palette, logo, and Hyprland window borders/rounding; selection survives login.

## Structure

- `shell.qml`: composition only.
- `core/SystemServices.qml`: shared clock, battery, audio, media and status polling.
- `core/Theme.qml`: observable active theme and apply process.
- `components/`: pill, wallpaper, glyph, tiles and slider.
- `panels/`: launcher, quick settings, calendar and theme picker.
- `services/`: bounded system queries and transactional theme application.
- `themes/<id>/theme.json`: name, description, Material colors, relative assets, Hyprland styling.
- `themes/<id>/assets/`: theme-owned wallpaper and logo.
- `assets/icons/`: shared control icons.
- `state/active.json`: generated persisted theme, not a hand-edited theme source.

## Themes

**Wizarch** — smoky violet Material Tonal Spot palette, abstract flowing wallpaper, wizard-hat mark. The original SVG logo has an angular Arch-like silhouette, folded tip, hatband, and negative-space arch. It is a custom project mark, not the official Arch logo.

**Eclipse** — the previous grayscale Material palette and downloaded Berserk wallpaper, preserved as an alternative.

## Adding a theme

Copy a theme directory, change its matching folder/id, name, description, full `colors` map, and assets. Colors use `#RRGGBB`. Assets must stay inside that theme's directory. Hyprland border colors use `#RRGGBB`, rounding 0–30, borderSize 1–5. Reload Quickshell to refresh the catalog.

Apply from a terminal: `python3 ~/.config/quickshell/services/themes.py apply THEME_ID`.

The helper atomically writes the Hyprland theme fragment, reloads and checks compositor errors, then commits active state. Failure restores previous files. `hyprland.lua` loads `~/.config/hypr/wizarch-theme.lua` last, overriding only the themed border colors, border width and corner radius. Existing key bindings, gaps, screenshot helper, and compositor behavior are preserved.

Backups of the entire previous shell and Hyprland config were saved before migration. Runtime requires only the existing Quickshell modules, Python standard library and installed system tools; the Material generation library is not a runtime dependency.
