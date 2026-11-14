# Artwork-backed media card

`quickshell/components/MediaCard.qml` presents the actual selected MPRIS player's
artwork, desktop app identity, title, artist/creator, position, duration and
capability-gated controls. `SystemServices.player` still selects a playing player
first; its existing selection logic is unchanged. The card uses a shared 166 px implicit height,
rounded cropped artwork and a theme surface scrim (84% dark, 90% light); missing
or failed artwork uses the same theme surface. Titles and creators elide to one
line. Unknown creator is left blank rather than invented.

Classification uses current-track evidence, never browser identity or a player's
list of supported MIME types. `MediaMetadata.kind` recognizes audio/video MIME
values in the optional, nonstandard `xesam:contentType`/`mpris:contentType`
metadata and unambiguous audio/video file extensions in `xesam:url`. Ambiguous
URLs, including browser pages, and containers such as `.ogg` stay `unknown`.
Integrations can set `MediaCard.mediaKindOverride` to `music` or `video` when they
have reliable knowledge. No app-specific classification is assumed by default.
Unknown sources retain transport and progress but hide music-only controls.
Video always hides shuffle and favorite, including when a favorite adapter exists.

Shuffle requires a music classification, `shuffleSupported`, and `canControl`.
Previous/next and the current play/pause operation use the corresponding player
capabilities; unsupported operations are hidden and unavailable control is
disabled. Buttons and the seek slider support keyboard focus and accessible
names. Activation guards also reject hidden/disabled controls.

MPRIS has no generic favorite operation. **No real favorite adapter is shipped**,
so the production favorite button is hidden. A future authorized app integration
can supply `favoriteAdapter` with `supports(player)`, `isFavorite(player)`, and
`toggle(player)`. It must validate the current player and track, expose live
favorite state and execute the app's real API. The test adapter is isolated and
never invokes a real service. A decorative favorite button is not displayed.

Duration and position honor `lengthSupported` and `positionSupported`. Unknown
values show `—:—`, without pretending every unknown-duration stream is live.
Seeking additionally requires a known positive duration and `canSeek`/`canControl`.
A visible playing card polls the MPRIS position notification every 500 ms; the
API supplies the current position. Slider binding uses `RestoreNone` so pressing
or keyboard adjustment cannot restore a stale pre-binding position. Track and
player metadata continue to update through QML bindings.

Validation:

- `python3 tests/media-card-qt.py` and `python3 tests/media-card-qt.py --wayland`
  exercise the real component with mock music/video/unknown metadata, adapter
  gating, transport dispatch, shuffle, position polling, keyboard seeking/play,
  desktop identity/fallback, unknown duration, hour timing, artwork/error fallback,
  narrow sizing and unclipped compact geometry, light/dark themes and selected-player removal.
- `python3 tests/quick-settings-qt.py` checks existing power, toggles, shared slider
  card, disabled states and geometry using isolated state.
- Wayland fixture screenshots are saved under
  `/home/Mw/ChatGPT/Wizarch Shell/audit/media-20261009/`. Offscreen Qt validates
  behavior; its software backend does not render the image effects fully.

Deployment replaces only the media block in each current QuickSettings file and
copies the new component, helper and two icons. Source and installed panel backups
are in the same audit folder. Other uncommitted work and concurrent power/toggle/
slider changes are preserved. No real playback commands are used in validation.

Visible audio-output selection is removed from Quick Settings and Settings.
Sound Settings retains playback mute/volume and microphone controls without
displaying a device selector or current output-device row. Compact text uses
14 px title, 11 px artist/creator and 10 px app name; both time labels remain
10 px. Playback buttons retain their 38 × 40 px input areas and progress retains
its 24 px input area. Compact-layout backups are in
`/home/Mw/ChatGPT/Wizarch Shell/audit/media-compact-20261009/`.
