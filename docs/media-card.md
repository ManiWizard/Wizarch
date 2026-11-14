# Media card

`quickshell/components/MediaCard.qml` displays the currently selected MPRIS player (`SystemServices.player`, preferring an actively playing player or the first registered MPRIS player) inside Quick Settings. When no active player with playback or a track title is present, the card collapses (`height: 0`, `visible: false`).

## Visual presentation & empty/unknown states

- Renders available album artwork (`player.trackArtUrl`) behind a theme surface scrim (`84%` in dark mode, `90%` in light mode); missing or failed artwork falls back cleanly to the plain theme surface.
- Displays desktop entry identity (or MPRIS identity), track title, and track artist/album. Unknown metadata stays blank rather than inserting placeholder names.
- Position and duration display real player values (`M:SS` or `H:MM:SS`) when `lengthSupported` / `positionSupported` are true, or `—:—` when unavailable.

## Capability gating & track classification

Track kind classification in `quickshell/core/MediaMetadata.js` uses only the current track's metadata (never assumptions based on player or browser identity):

- Recognizes explicit `audio/*` or `video/*` values from `xesam:contentType` / `mpris:contentType` and unambiguous file extensions in `xesam:url`.
- Ambiguous containers (such as `.ogg`) and web URLs remain `unknown` unless an integration explicitly sets `mediaKindOverride` (`music` or `video`).
- Control availability follows live MPRIS capabilities:
  - Previous/next and play/pause require `canGoPrevious`, `canGoNext`, `canPlay`, `canPause`, and `canControl`. Unsupported actions are disabled or hidden.
  - Shuffle requires `kind === "music"`, `shuffleSupported`, and `canControl`. Video and unknown media hide shuffle.
  - Seeking requires positive track length, `lengthSupported`, `canSeek`, and `canControl`.
  - MPRIS provides no standard favorite endpoint and no favorite adapter is bundled, so the favorite control stays hidden unless an external `favoriteAdapter` (`supports`, `isFavorite`, `toggle`) is attached.
- Audio output device selection is not part of `MediaCard` or Sound Settings; volume and microphone mute/level controls live in Quick Settings and Settings -> Sound.

## Position polling

When visible and playing (`player.playbackState === MprisPlaybackState.Playing`), `MediaCard.qml` polls `player.positionChanged()` every `500 ms` and uses `Binding.RestoreNone` on the seek slider so dragging or keyboard seeking is not snapped back by stale bindings.

## Verification

- `python3 tests/media-card-qt.py` exercises capability gating, playback controls, shuffle/video hiding, position formatting, artwork fallback, and light/dark appearance against mock MPRIS fixtures in Qt (no live audio playback commands are sent during tests).
- Live PipeWire/MPRIS player behavior requires an active desktop session with a running media player.
