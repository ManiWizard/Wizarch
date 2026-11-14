# Wizard local Material themes (schema 1)

The copyable [example collection](../../examples/material-collection/catalog.json) is a functional local input. Copy its whole directory, change the pack ID and directory together, and retain your own wallpaper licenses. Wizard reads data and images only. Scripts, QML, Lua fragments and executable hooks are prohibited.

## Runtime and reproduction

Use Python 3.11 or later. This implementation was verified with Python 3.14. Install dependencies in a local virtual environment, never system Python:

```sh
python3 -m venv "$HOME/.local/share/wizarch/theme-runtime"
"$HOME/.local/share/wizarch/theme-runtime/bin/python" -m pip install -r quickshell/requirements-theme.lock
```

For nondefault XDG_DATA_HOME, place the environment at `$XDG_DATA_HOME/wizarch/theme-runtime`, or set `WIZARCH_THEME_PYTHON` to its Python executable. The CLI only selects an existing interpreter; it never installs packages or accesses the network. Pillow and jsonschema validate local inputs. Material generation additionally needs Material Color Utilities. Resolved palettes do not need MCU to activate; the resolved built-in QML fallback needs none of these Python dependencies.

The generator is `material-color-utilities==0.2.6`, the Apache-2.0 Python/pybind11 wrapper around Google's C++ implementation. Its dynamic roles implement the pre-2025 Material 3 scheme family (2021 color scheme semantics plus tonal surfaces and fixed roles supplied by this pinned release). We do not claim the newer 2025 specification. `tonal-spot-three-key` uses the pinned TONALSPOT dynamic role algorithm and neutral/neutral-variant/error palettes, with explicit key families supplied as `TonalPalette(Hct(hex))`. Primary, secondary and tertiary inputs each determine their own hue/chroma. Omitted secondary and tertiary retain the release's deterministic tonal-spot defaults, derived from primary. They are never substituted for explicit inputs.

Contrast levels are exactly 0, 0.5 or 1; booleans and other values are rejected. The example uses 0.5. These levels do not by themselves establish accessibility: resolution checks the actual role pairs and composited states. A generated input that fails the checks is rejected with ratios; choose another supported contrast level or provide an approved complete export. Monochrome generation was used only to author Eclipse's light export; new seed packs use the three-key variant.

The distribution source hash, API verification, and upstream license are in [generator provenance](evidence/generator-provenance.json) and [GENERATOR-LICENSE.txt](GENERATOR-LICENSE.txt). Exact dependency versions are locked. Generated schemes persist in the bounded XDG cache, and local import compiles seed packs into resolved exports in managed storage. Bundled light/dark exports and the built-in fallback are committed source data. No render loop runs HCT or regenerates schemes.

## Canonical portable layout

```text
collection/
  catalog.json
  themes/
    aurora/
      theme.json
      colors.json       # when color.type is "roles"
      wallpapers/dusk.png
      previews/card.png # optional
```

The collection catalog has `schemaVersion: 1`, a collection `id`, `name`, and `packs` containing stable `id` and `path` values of `themes/<id>/theme.json`. An optional manifestSha256 checks content consistency. It is not publisher authentication.

A theme.json must have schemaVersion, id, name, semantic version (`x.y.z`), modes, defaultMode, color, wallpapers and defaultWallpaper. Wallpaper entries require id, name and relative path. Optional author, description, license, attribution, preview and logo are portable strings; wallpaper license/attribution are separate from pack code licensing. See [pack schema](../../quickshell/schemas/pack.schema.json).

Choose exactly one color representation:

```json
{"type":"keys","keys":{"primary":"#386a20","secondary":"#386663","tertiary":"#81517c"},"variant":"tonal-spot-three-key","contrast":0.5}
```

or:

```json
{"type":"roles","path":"colors.json"}
```

Seed packs may declare only light or only dark; generation caches both schemes but exports and managed installation retain exactly the declared supported modes.

The latter file has `schemaVersion: 1`, `schemes` keyed by the exact supported modes, and all 46 canonical roles in each scheme. Optional generator metadata records library/version/specification/variant/license, keys and contrast. Each role is an opaque `#rrggbb` string. Exported roles are copied exactly, then validated; no generation or blending substitutes for an approved export. A manifest combining keys and a role path is rejected, rather than choosing a silent precedence.

For an existing Material export with all roles plus deprecated background/onBackground/surfaceVariant, wrap its light/dark data in the schema-1 palette envelope, then convert it explicitly:

```sh
python3 quickshell/services/themes.py import-palette original.json --output colors.json
```

The command keeps the 46 canonical colors verbatim and announces removal of the deprecated aliases. surface/onSurface/surfaceContainerHighest remain authoritative. No missing role is guessed. After conversion, set color.type to roles and path to colors.json. Direct canonical imports reject extra role names, including misspellings.

To generate a seed pack's export for review:

```sh
python3 quickshell/services/themes.py generate /absolute/collection/themes/aurora/theme.json
```

This writes colors.json with generator metadata. Keep the keys manifest for simple authoring, or change its color object to the roles representation to freeze the approved export. A colors.json beside a keys manifest is not a second source of truth.

## Local registration, refresh and selection

Appearance has a local collection path field and Import button. The same operation is available as:

```sh
python3 quickshell/services/themes.py import /absolute/collection
python3 quickshell/services/themes.py refresh
python3 quickshell/services/themes.py apply local-0123456789abcdef:aurora --mode light --wallpaper dusk
```

Use the identity returned by Import or List, rather than the example identity above. Local source IDs are derived from the canonical collection root path; identical pack IDs in different roots have different namespaces. Bundled identities are bundled:wizarch and bundled:eclipse. The old bare IDs remain CLI aliases for bundled packs.

Import validates the collection, stages only declared content, revalidates the copied bytes, compiles seed input into a palette, updates compiled manifest hashes, and atomically registers an immutable installed directory. Import does not activate or advance an active theme. Re-importing unchanged content is idempotent. Apply explicitly advances the selected content. Installed content is immutable; edit the original collection and re-import. Refresh and one shared inotify watcher expose changes and diagnostics. Broken registered packs remain listed; optional missing logos/previews fall back to neutral preview surfaces or the Arch glyph.

Selecting a card previews its mode-aware roles and wallpaper inside Appearance. Swatches use the draft colors. Apply commits; Cancel or closing Settings discards the draft without any desktop or compositor mutation. Mode and wallpaper identifiers are separate. Mode changes preserve compatible wallpaper IDs. A pack switch preserves a supported selected mode; a new pack gets its own default wallpaper unless an explicit choice is supplied. Wallpaper changes do not extract colors or regenerate a scheme. Extraction is not implemented and is never an automatic side effect.

Local overrides live in `$XDG_CONFIG_HOME/wizarch/theme-overrides.json`, separate from pack content. [Overrides schema](../../quickshell/schemas/overrides.schema.json) allows a per-identity mode, wallpaperId, or complete per-mode schemes. Merge order: explicit request; saved per-pack override; compatible committed choice; pack default. Full override schemes replace the requested exported scheme and pass the same validation/contrast checks. No partial hex override bag is accepted. Ordinary Apply and import never rewrite the override file.

## Bounds and content safety

Core schemas reject unknown fields, duplicate JSON fields, booleans used as integers, integral floats for integer fields, wrong types, unsupported versions, colors/enums/ranges, duplicate stable IDs and missing roles. Only the pack's extensions object permits additional namespaced data fields (`owner.feature`); extension data is inert and cannot add executable behavior. Metadata/diagnostics render as plain text, so markup cannot introduce remote images or override semantic ink. Non-finite numbers (including numeric overflow) are rejected. A manifest that expands beyond the cache JSON budget is validated without writing that oversized cache entry.

Manifest/JSON limit: 256 KiB. Pack enumeration: at most 128 files and 512 directory entries. Each image: 32 MiB, at most 8192 per dimension, at most 33,554,432 pixels, one frame. Pillow verifies and fully decodes PNG, JPEG and WebP; new SVG input is rejected. Required wallpapers must all validate. Each pack's wallpapers and each imported collection have a 256 MiB budget; total managed content is limited to 512 MiB. At most 128 registered packs and 128 source records are accepted. Palette cache retains at most 32 entries, pack cache at most 128; each cached JSON is bounded by the same JSON limit. Wallpaper and card QML images decode at display/preview size and do not retain old image-cache entries.

Assets must be relative, without traversal or backslashes, and remain inside their pack after symlink resolution. Internal symlinks are materialized as safe files on import. Optional preview/logo failures are diagnostic fallbacks. Existing bundled SVG logos/wallpaper remain compatible only through a restricted SVG parser: no script, entity/doctype, external references, CSS URL, event handlers or unsupported elements. That compatibility privilege does not extend to imported packs. Third-party artwork remains unmodified; shell-owned vector logos and control glyphs follow semantic ink roles.

Managed storage retains earlier directories so active and rollback snapshots keep usable paths. The hard storage bound deliberately stops further imports with an actionable error rather than deleting a possibly referenced snapshot. Automatic managed-content garbage collection/removal is not implemented. See [recovery](RECOVERY.md) before manually removing content.

## Review-hardened local bounds and previews

JSON readers consume at most 256 KiB plus one overflow byte; special files (including FIFOs) are rejected using the opened descriptor. Bad derived generation caches are discarded and rebuilt after schema/input/generator/contrast checks. Authored exports are authoritative input and are never treated as disposable caches. Missing MCU yields a generation-unavailable diagnostic; existing committed exports and fallback remain usable.

Import checks the prospective combined catalog, including bundled packs and diagnostic entries, before registration. A source replacement counts the new revision once; retained old snapshots do not count as catalog entries. Invalid registered sources remain diagnostic without hiding unrelated packs. Final compiled collection bytes are limited to 256 MiB; retained managed content plus exact registration bytes to 512 MiB. Identical revisions are revalidated/reused without charging duplicate content. Temporary staging has its own bounded collection allocation, separate from retained-storage accounting.

Appearance previews resolve complete local color overrides through the shared catalog presentation layer. Override edits invalidate that layer; they do not change the committed desktop until Apply. Explicit WIZARCH_THEME_PYTHON always selects the configured executable before imports. System callers prefer an existing documented local runtime; an existing virtualenv is retained unless explicitly overridden. See [review fixes](REVIEW-FIXES.md) for tests and durability limits.
