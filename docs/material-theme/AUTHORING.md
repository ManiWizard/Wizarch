# Local Material themes and authoring (schema 1)

Wizarch reads declarative theme packs (`theme.json`, JSON color palettes, and image assets) validated against JSON schemas under `quickshell/schemas/`. Scripts, QML snippets, Lua code, and executable hooks are never loaded from theme packs.

See `examples/material-collection/catalog.json` for a complete copyable collection example (`aurora`).

## Python runtime requirements

Bundled resolved exports and the built-in QML fallback palette (`quickshell/core/Fallback.js`) work without extra Python libraries. Generating palettes from seed keys (`color.type: "keys"`), validating schema/images strictly with Pillow/`jsonschema`, and importing local collections use a dedicated virtual environment (never system Python):

```sh
python3 -m venv "${XDG_DATA_HOME:-$HOME/.local/share}/wizarch/theme-runtime"
"${XDG_DATA_HOME:-$HOME/.local/share}/wizarch/theme-runtime/bin/python" -m pip install -r quickshell/requirements-theme.lock
```

Set `WIZARCH_THEME_PYTHON` to override which Python interpreter `quickshell/services/themes.py` delegates to. The CLI only locates an existing interpreter; it never downloads packages or accesses the network.

- Seed generation uses `material-color-utilities==0.2.6` (Apache-2.0, see [GENERATOR-LICENSE.txt](GENERATOR-LICENSE.txt)) with `tonal-spot-three-key` tonal palettes and explicit contrast levels `0`, `0.5`, or `1`.
- Authored role exports (`color.type: "roles"`) preserve all 46 canonical Material roles verbatim and still undergo contrast validation.

## Portable collection layout

```text
collection/
  catalog.json
  themes/
    aurora/
      theme.json
      colors.json        # when color.type is "roles"
      wallpapers/dusk.png
      previews/card.png  # optional
```

- **`catalog.json`** (`quickshell/schemas/catalog.schema.json`): `schemaVersion: 1`, `id`, `name`, and `packs` array (`id` and relative `path` to `themes/<id>/theme.json`), with optional `manifestSha256`.
- **`theme.json`** (`quickshell/schemas/pack.schema.json`): `schemaVersion: 1`, `id`, `name`, semver `version` (`x.y.z`), `modes` (`["light"]`, `["dark"]`, or both), `defaultMode`, `color`, `wallpapers`, and `defaultWallpaper`.

Choose one `color` representation:

```json
{"type": "keys", "keys": {"primary": "#386a20", "secondary": "#386663", "tertiary": "#81517c"}, "variant": "tonal-spot-three-key", "contrast": 0.5}
```

or:

```json
{"type": "roles", "path": "colors.json"}
```

## Helper commands

Convert an older palette JSON containing deprecated aliases (`background`, `onBackground`, `surfaceVariant`) to canonical 46-role `colors.json`:

```sh
python3 quickshell/services/themes.py import-palette original.json --output colors.json
```

Generate a static `colors.json` export from a seed-key `theme.json`:

```sh
python3 quickshell/services/themes.py generate /absolute/path/to/collection/themes/aurora/theme.json
```

Import, inspect, and apply local collections (also available from Settings -> Appearance -> Theme sources):

```sh
python3 quickshell/services/themes.py import /absolute/path/to/collection
python3 quickshell/services/themes.py list
python3 quickshell/services/themes.py refresh
python3 quickshell/services/themes.py apply bundled:wizarch --mode dark
```

## Overrides and bounds

- Optional per-pack overrides live in `$XDG_CONFIG_HOME/wizarch/theme-overrides.json` (`quickshell/schemas/overrides.schema.json`). They can override `mode`, `wallpaperId`, or complete 46-role `schemes` without editing pack files.
- Merge precedence: explicit request -> saved per-pack override -> compatible committed choice -> pack default.
- Validation bounds enforced by `quickshell/services/theming/validation.py` and `storage.py`:
  - Strict JSON parsing (rejects duplicate keys, non-finite numbers, special files/FIFOs, files over `256 KiB`).
  - Image assets (`PNG`, `JPEG`, `WebP`) capped at `32 MiB`, `8192` px per dimension, and single frame; paths must stay relative within the pack directory after symlink resolution.
  - Up to `128` registered packs/sources, `256 MiB` compiled collection limit, and `512 MiB` retained managed-content quota.
  - Broken or missing-asset packs remain listed as diagnostic entries in the catalog so users can inspect what is missing (for example, the bundled `eclipse` pack when its third-party local wallpaper is absent).
