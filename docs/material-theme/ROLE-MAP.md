# Semantic roles and current component coverage

The canonical QML API is `Core.Theme`. It exposes a coherent committed revision, palette, mode, wallpaper, catalog, draft presentation and the centralized operation boundary. Consumers do not read JSON/directories, spawn theme helpers, or generate palettes. The singleton is the only theme process/file watcher owner. The provider and validation layers are presentation-independent.

## Canonical roles (46)

| Family | Roles |
| --- | --- |
| Primary / accent | primary, onPrimary, primaryContainer, onPrimaryContainer, inversePrimary, primaryFixed, primaryFixedDim, onPrimaryFixed, onPrimaryFixedVariant |
| Secondary | secondary, onSecondary, secondaryContainer, onSecondaryContainer, secondaryFixed, secondaryFixedDim, onSecondaryFixed, onSecondaryFixedVariant |
| Tertiary | tertiary, onTertiary, tertiaryContainer, onTertiaryContainer, tertiaryFixed, tertiaryFixedDim, onTertiaryFixed, onTertiaryFixedVariant |
| Error | error, onError, errorContainer, onErrorContainer |
| Surfaces | surface, onSurface, onSurfaceVariant, surfaceDim, surfaceBright, surfaceContainerLowest, surfaceContainerLow, surfaceContainer, surfaceContainerHigh, surfaceContainerHighest, inverseSurface, inverseOnSurface |
| Boundaries/effects | outline, outlineVariant, shadow, scrim, surfaceTint |

Material defines inversePrimary; there is no invented inverseSecondary/inverseTertiary brand palette. All fixed roles are exposed even when current components do not use them.

Compatibility aliases: textPrimary→onSurface; textSecondary→onSurfaceVariant; textOnPrimaryContainer→onPrimaryContainer; divider→outlineVariant; background→surface; onBackground→onSurface; surfaceVariant→surfaceContainerHighest. hoverSurface and hoverActiveSurface are computed state-layer aliases over surfaceContainerHigh/onSurface and secondaryContainer/onSecondaryContainer, respectively. Old custom hover/divider hex entries are not competing runtime sources.

Qt in this environment interprets inline `on…` property bindings as handlers, leaving QColor black. Readonly aliases to an internal ink object avoid that ambiguity while retaining the standard public names. Runtime verification compares every canonical getter to the resolved snapshot, rather than assuming declaration implies a working color.

## Component mapping

| Component or surface | Background/hierarchy | Foreground and emphasis |
| --- | --- | --- |
| Pill collapsed/expanded body and shoulders | surface | onSurface, onSurfaceVariant; primary focus; ThemeLogo primary; workspace number is an additional state cue |
| Pill frame/exclusive-zone edges, ScreenBorder | surface | aperture geometry and reservations unchanged |
| ScrollingFrameGuard/native peeks | surface | same screen frame; no changes to native Scrolling policy |
| OverlayShadow | preserved inverse black/white contrast halo | intentional effect exception; original opacity/blur/offset unchanged |
| Launcher search field, groups, tiles, context menus | surfaceContainer, High/Highest; centralized hover alias | onSurface/onSurfaceVariant; primary focus; onPrimaryContainer for primary selection |
| TextInput/TextField in launcher, input picker, connectivity, Settings | tonal field backgrounds | onSurface; selection primaryContainer/onPrimaryContainer; native caret follows text ink |
| Calendar week/month/year | surface; day/month tonal hover | today primaryContainer/onPrimaryContainer; ordinary dates onSurface; secondary dates onSurfaceVariant; primary focus |
| Calendar inactive neighboring dates | existing 0.45 opacity | inactive/decorative exception; date labels remain visible, hue is not the sole date/today cue |
| ControlTile (Wi-Fi/Bluetooth and other reusable tiles) | secondaryContainer for active; surfaceContainer otherwise; exact-base state layers | active label/detail/glyph onSecondaryContainer; inactive onSurface/onSurfaceVariant; paired onSecondaryContainer inner focus/hover boundary on selected tiles, primary focus otherwise |
| Quick Settings quick actions | secondaryContainer active, surfaceContainerHigh idle | paired onSecondaryContainer glyph; labels/state text onSurface/onSurfaceVariant outside icon surface; On/Off/Unavailable text retained |
| Quick Settings volume/brightness, GlassSlider, SettingsSlider | surfaceContainer and Highest tracks | primary active tracks/handles; onSurface/onSurfaceVariant labels; onSurface focus borders |
| Quick Settings media card and artwork fallback | surfaceContainer/High | onSurface/onSurfaceVariant metadata; primary progress; tertiaryContainer/onTertiaryContainer play/pause; neutral previous/next |
| SettingsChoice and popup delegates | surfaceContainerHighest; primaryContainer selected | onSurface, onPrimaryContainer; primary focus; disabled opacity retained |
| Quick Settings power/menu/tray controls | surfaceContainerHigh and tonal hover | onSurface; primary focus; external tray/app icons remain original artwork |
| Settings window/sidebar, all eleven pages | surface/background; surfaceContainer sidebar/sections; Highest selected nav | onSurface headings/body, onSurfaceVariant description; primary focus; same shared controls on every page |
| Appearance theme/wallpaper cards | approved mode-specific pack preview roles; fallback surfaces for invalid pack | onSurface/onSurfaceVariant labels, primary selected/focus, primary/onPrimary check mark; errors and diagnostics visible |
| SettingsButton/SettingsSwitch | Highest tonal surfaces; primary switch track | onSurface button text; onPrimary active switch handle; existing opacity and position distinguish disabled/checked |
| Connectivity detail and SettingsConnectivity | surfaceContainer/High/Highest | shared themed switch; onSurface/onSurfaceVariant; primary field/focus; error text |
| Notification list/empty state/dismiss/clear | surfaceContainer; High action controls | onSurface/onSurfaceVariant; critical border/glyph error and explicit “Urgent” label; primary focus |
| Notification action buttons | absent in existing shell | no new action UI introduced; if added later use primaryContainer/onPrimaryContainer or errorContainer/onErrorContainer for destructive actions |
| InputPicker clipboard/emoji | tonal surfaces and selected primaryContainer | onSurface, onSurfaceVariant and onPrimaryContainer; emoji pixels retained |
| QuickWheel sectors and center | surfaceContainerHigh/Low; secondaryContainer selected; existing scrim | selected glyph/text onSecondaryContainer; onSurface/onSurfaceVariant elsewhere; onSecondaryContainer selection stroke (≥4.5 against its fill); textual/position selection cue |
| QuickWheel outer heading/help labels | added surfaceContainerLow backing inside existing text bounds | onSurface/onSurfaceVariant; backing makes text independent of wallpaper contrast without geometry changes |
| ThemedToolTip | inverseSurface | inverseOnSurface |
| ThemedScrollBar | outline handle, adapted state layer | meaningful handle vs tonal adjacent surface ≥3:1; original layout size follows control |
| FadedDivider and section/nav separators | outlineVariant with existing fades | decorative boundary exception |
| Glyph and ThemeLogo | no additional brand colors | Glyph.ink defaults onSurface and is paired on active surfaces; bundled logos primary; missing logos use Arch glyph |
| Wallpaper | original pixels; surface when missing/unready | no automatic palette extraction, blur or glass styling |
| Inactive ScrollingStack | existing surfaces, scrim, shadow | onSurface/onSurfaceVariant/primary; inactive component remains inactive |
| Legacy ThemePicker | compatibility facade and catalog | same semantic aliases; not instantiated by current shell |
| Shell-owned Hyprland borders | primary active, outlineVariant inactive | inactive border is decorative; client/wallpaper adjacency is outside a universal contrast guarantee |

The current calendar has no events/appointments; no event renderer was invented. Today, keyboard focus, date selection/navigation and all three existing views are covered. Notification server actions likewise have no current action-row renderer. Dismiss/clear and critical urgency are covered.

## States and contrast

`Theme.stateColor(base, ink, hovered, pressed, focused)` centralizes sRGB compositing. Standard maxima are hover 0.08, focus 0.10 and pressed 0.10. Near-threshold approved exports reduce layer opacity in 0.01 steps until ink/background contrast remains ≥4.5:1. This changes the state layer, not the exported roles. Focus/selection borders remain separate meaningful indicators; position, checkmarks, state text and urgency text avoid hue-only meaning. Selected control boundaries use the paired on-role where primary does not contrast with the selected container (notably higher-contrast schemes). State handlers and device actions are preserved.

Disabled opacity remains component-specific: existing controls 0.45, tiles 0.55, sliders 0.50/0.55. Existing inactive date and decorative-divider fades remain. These inactive/decorative cases are explicitly exempt from active text/control assertions. Ordinary enabled text is checked at 4.5:1 (stronger than the qualifying large-text 3:1 allowance); primary focus/active roles and outline handles are checked at 3:1 against tonal backgrounds. The contrast evidence covers every foreground/surface combination, family containers/fixed roles, inverse text and composited enabled states. We do not certify arbitrary third-party artwork or arbitrary application backgrounds.

Color-only Behaviors are disabled during snapshot publication to prevent a new light foreground landing on an interpolated old dark background. Existing hover animation durations and all geometry/morph/hide animations remain. Palette generation and validation happen outside QML rendering. See [residual color classification](evidence/color-coverage.json), [numeric contrast evidence](evidence/contrast.json) and runtime screenshot index in the completion report.

## Primary semantic and validation references

The independent tonal-palette inputs, light/dark modes, scheme variants and contrast levels follow the [MCU creating-color-scheme guide](https://github.com/material-foundation/material-color-utilities/blob/main/dev_guide/creating_color_scheme.md) and [dynamic scheme concepts](https://github.com/material-foundation/material-color-utilities/blob/main/concepts/dynamic_color_scheme.md). The shipped generator API is verified against the pinned 0.2.6 implementation, rather than assuming the current upstream API is identical.

Foreground/background pairing and role naming are cross-checked against [Material Components color documentation](https://github.com/material-components/material-components-android/blob/master/docs/theming/Color.md). The requested [Material 3 color system](https://m3.material.io/styles/color/the-color-system) requires JavaScript and is not readable through the text retrieval backend; the role tables and pinned source/API supply the inspectable evidence.

Numerical text validation uses [WCAG contrast minimum](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html), and meaningful active-control boundaries use [WCAG non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast). These are pair/compositing checks with stated inactive/decorative exceptions, not a claim of complete WCAG conformance.

Desktop light/dark preference synchronization is documented in [DESKTOP-APPEARANCE.md](DESKTOP-APPEARANCE.md). Applications retain toolkit-native role palettes. Launcher drag-grid `destination-in` black gradient stops are alpha masks; RGB is discarded, and visible grid ink comes from textSecondary.
