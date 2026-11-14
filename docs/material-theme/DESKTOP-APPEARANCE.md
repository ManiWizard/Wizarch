# Desktop light/dark integration — completion and verification

Implemented and selectively deployed on 2026-10-09 UTC in `/home/Mw/Documents/Codex/Wizarch`. This follow-up connects Wizard's committed mode to the desktop settings read by applications. It does not export Material role colors into arbitrary application themes. GitHub theme transport, importing and updates remain deferred.

The reproduced initial mismatch was Eclipse **light** in active.json while `org.gnome.desktop.interface color-scheme` was `prefer-dark`, and the appearance portal returned `1` (dark). The first deployment corrected this to light without changing the theme snapshot or wallpaper. After the interrupted turn resumed, the current selection was Eclipse **dark**, with desktop preferences reset to `default`/`Adwaita`. Recovery synchronized that current selection to dark; its source of preference reset was not determined. The active user's current selection was preserved rather than restoring the older light selection. [Deployment evidence](evidence/desktop-appearance/deployment.json) records both observations.

## Behavior and implementation

| Path / symbol | Change |
| --- | --- |
| [appearance.py:DesktopAppearance](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/appearance.py:22) | Small injectable adapter for gsettings, a bounded GTK3 settings file, and static GTK resource aliases. Uses argument arrays and five-second subprocess timeouts; checks writability, stderr and readback. |
| [activation.py:Engine](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/activation.py:26) | Captures desktop preferences into the existing locked transaction journal; sets mode before active.json publication; restores preferences on rejection; startup and unchanged apply repair stale desktop settings. |
| [Theme.qml:launchApplication](/home/Mw/Documents/Codex/Wizarch/quickshell/core/Theme.qml:49) | Launches GUI/terminal argv and working directory with a GTK3 Qt platform adapter if no explicit adapter exists. Preserves an explicit adapter such as qt6ct. |
| [LauncherView.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/panels/LauncherView.qml:219) | Uses the centralized launch function. Only this call was patched in the installed launcher; concurrent launcher changes were retained. |
| [SettingsView.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/panels/SettingsView.qml:56) | Explains that Apply sets the desktop light/dark preference. Draft preview still has no desktop side effects. |
| [examples/hyprland-wizarch.lua](/home/Mw/Documents/Codex/Wizarch/examples/hyprland-wizarch.lua:1) | Documents the native Qt GTK3 adapter for a bare Hyprland session. |

Applying light writes `prefer-light`; dark writes `prefer-dark`. The running GTK portal publishes the standard `org.freedesktop.appearance/color-scheme` preference and its change signal. GTK3 also receives a matching theme name. On this installation GTK's embedded Adwaita CSS exists but the named Adwaita-dark alias did not produce a dark render. Two small `Wizard-Adwaita` aliases import GTK's built-in light/dark resources, so no third-party stylesheet or package is downloaded. They live under `$XDG_DATA_HOME/themes`. Custom GTK themes are retained rather than guessed or replaced; their ability to follow a mode depends on the theme.

`$XDG_CONFIG_HOME/gtk-3.0/settings.ini` stores the chosen GTK theme and `gtk-application-prefer-dark-theme` for legacy/newly started apps. The editor preserves other keys, sections and comments, rejects duplicate/malformed keys, special files and content over 32 KiB, and restores exact prior file bytes (or removes a newly created file) after failed activation. GTK4/libadwaita uses the desktop preference rather than an unsupported libadwaita GTK-settings override.

The existing operation lock also serializes these writes. The journal records effective gsettings values and optional base64 GTK settings bytes before mutation. A normal transaction updates desktop appearance after compositor acceptance and before selection/active publication. An interruption before active publication restores previous settings; after publication, recovery reapplies the committed mode. Rollback applies the previous snapshot's mode. An unchanged request has an `appearanceOnly` journal so an interruption cannot be mistaken for a new palette commit. Older journals without appearance fields remain readable. Effective gsettings values are restored explicitly; this does not preserve the distinction between inherited defaults and explicit values. Static theme aliases are installation assets and intentionally remain after a failed request.

Offline `init` and `--no-compositor` operations skip desktop settings as well as compositor mutations. They are intended for fixtures/offline staging. Missing gsettings/session bus or a locked preference fails a live request with an actionable error rather than reporting success. Another program can change these preferences after activation; this implementation repairs them on the next Apply/Recover/startup, without a continuous preference-enforcement daemon.

## Selective deployment and restore

Five shell targets were installed: `services/theming/appearance.py`, `services/theming/activation.py`, `core/Theme.qml`, `panels/SettingsView.qml`, and the narrow launch call in `panels/LauncherView.qml`. The other files in the dirty checkout were not copied. The retained QuickSettings source/install difference was not touched.

The only Hyprland change adds `hl.env("QT_QPA_PLATFORMTHEME", "gtk3")` beside existing Qt environment configuration. `/home/Mw/.config/environment.d/60-wizarch-appearance.conf` supplies the same default to future user services; `dbus-update-activation-environment --systemd` updated current activation environments. No application or compositor process was restarted by the deployment. An ordinary shell source reload loaded the QML edits. A subsequent user session restart was observed, and its shell process has `QT_QPA_PLATFORMTHEME=gtk3`.

Runtime additions are GTK3 settings and the two tiny CSS aliases. No system package was installed. Dependencies are the already installed gsettings-desktop-schemas/dconf, GTK3, the GTK portal and Qt's GTK3 platform plugin. Explicit Qt platform adapters are preserved in the launcher. Installations that use a different toolkit setup should adapt their session configuration rather than blindly overwrite it.

Exact before bytes and state are saved in `/home/Mw/Documents/Codex/Wizarch/work/desktop-appearance/backup/`. `manifest.json` records deployment hashes; `quickshell/panels/LauncherView.latest.qml` contains the concurrent launcher revision saved before the narrow patch. To undo integration, restore only matching backend/QML targets from that backup, reverse the `Core.Theme.launchApplication(app)` call if the launcher has newer work, remove the added Qt environment line/file, and restore the saved effective gsettings preferences. Remove the newly created GTK settings file only if it has no subsequent user changes. Keep the current active theme unless intentionally performing a theme rollback. Do not restore the entire historical Hyprland or launcher file over newer edits.

For mode repair with the integration installed:

```sh
python3 /home/Mw/.config/quickshell/services/themes.py recover
```

Theme rollback remains `themes.py rollback`. A failed rollback keeps its recovery journal and reports the failure. Runtime aliases contain GTK resource imports; no executable theme content or remote hooks were introduced.

## Verification and evidence

[Automated results](evidence/desktop-appearance/test-results.json) contain the commands, exit statuses and fresh-process elapsed times:

| Check | Result |
| --- | --- |
| `work/theme-env/bin/python tests/material-appearance.py` | 13 tests pass, 4.649 s. Fake gsettings and temp storage; both modes, idempotence, custom-theme preservation, locks, bounds/FIFOs, INI preservation, exact rollback, missing/write failures, interrupted publication, old journals and offline isolation. |
| `work/theme-env/bin/python tests/material-themes.py` | 27 tests pass, 18.608 s; original pipeline regression suite. Injected `NoAppearance` prevents live desktop changes. |
| `work/theme-env/bin/python tests/material-review.py` | 13 tests pass, 10.484 s; R1–R4 and related review regressions. |
| Bundled Node runtime `tests/launcher.js` | Pass: 1,536 layouts and existing launcher behavior; GUI/terminal argument and directory forwarding plus default/explicit Qt adapter interception. No real arbitrary commands executed. |
| `python tests/settings-window-qt.py` | All eleven settings pages and controls pass in the existing offscreen fixture; not evidence of real PanelWindow rendering. |
| `work/theme-env/bin/python tests/material-color-coverage.py` | 46 roles pass. Classified existing OverlayShadow halo plus concurrent launcher destination-in alpha masks; mask black RGB is discarded, while displayed grid ink is semantic. |
| `git diff --check`, Python compile | Pass. |

The native fixture sources are in [tests/fixtures/desktop-appearance](/home/Mw/Documents/Codex/Wizarch/tests/fixtures/desktop-appearance). The manual live runner and compiled programs are retained under `work/desktop-appearance/`; the runner temporarily sets GTK3/Qt/libadwaita windows to float and restores configuration by reload afterward. It changes only test-window rules and desktop appearance; it does not change device settings, monitor layouts, keyboard mappings or user files outside the intended adapter.

[Live results](evidence/desktop-appearance/live-results.json), [signal log](evidence/desktop-appearance/portal-signals.log), toolkit logs and [six indexed screenshots](evidence/desktop-appearance/screenshots.json) verify light → dark → light in already running GTK3, GTK4/libadwaita and Qt 6.11.2 widget windows on the real Wayland session. The [contact sheet](evidence/desktop-appearance/contact.png) was visually inspected; the three toolkits visibly changed both background and foreground. Qt reported light `#faf9f8` / `#000000`, dark `#323232` / `#ffffff`; portal values were 2/1/2. These are toolkit-native palettes, independent of the shell's approved Material roles.

The first test inherited `GDK_BACKEND=x11`, and initial crops included offscreen/overlapped windows. Those attempts were not accepted as render evidence; the runner was corrected to native Wayland and temporary floating placement, and all six indexed files were replaced with verified test-window crops. Current screenshots show test content, not private wallpapers or unrelated applications.

[Installed activation cycle](evidence/desktop-appearance/installed-cycle.json) verified Eclipse dark then light through the installed CLI, matching gsettings and portal after each transaction. Observed elapsed times were 629.12 and 641.79 ms, including subprocess start and readback. These are two observations, not a benchmark or a speedup claim. Verification restored the original snapshot and saved rollback history; later resume preserved the newly current Eclipse dark selection. Current compositor errors equal the original empty baseline, and no journal remains. Shell logs show successful Configuration Loaded events and existing BlueZ/portal application-ID warnings; those warnings are not claimed resolved.

## Limits and next work

The system preference is shared, but apps can explicitly force a theme. Choose “System”, “Automatic” or “Follow system” in such apps. Older Qt processes without a desktop adapter need to be reopened once; they cannot acquire a new process environment while running. X11 GTK processes need an XSettings manager for guaranteed live updates; this machine lacks xsettingsd, so newly started X11 apps have the GTK settings fallback but full live X11 coverage is unverified. Qt5, Flatpak-specific overrides, individual browsers, custom GTK theme variants and every installed app were not exhaustively tested. No application-specific preferences were overwritten to force compliance.

The unexplained post-resume desktop preference reset is recorded, not called a verified reboot persistence pass. Recover reconciles it, and the next theme Apply also repairs it. Physical power-loss, a controlled full reboot test, hardware matrix and long soak remain unverified. Remote GitHub execution remains outside this phase.

The integration uses the standardized [XDG appearance Settings preference and change signal](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.Settings.html), [GTK3 shared settings](https://docs.gtk.org/gtk3/class.Settings.html), and the [installed Qt version's GTK platform adapter](https://raw.githubusercontent.com/qt/qtbase/v6.11.2/src/plugins/platformthemes/gtk3/qgtk3theme.cpp). No claim is made that every app accepts the standard preference or that this is a full OS/application accessibility audit.
