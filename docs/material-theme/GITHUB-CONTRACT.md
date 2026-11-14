# Future GitHub theme sources (contract only)

**Remote GitHub theme transport, cloning, fetching, and scheduled updates are not implemented in this build.**

In `quickshell/services/theming/providers.py`, `GitHubProvider.operational` is `false` and its transport methods raise a deferred-feature error. In the UI, Settings -> Appearance displays local collection importing (`LocalProvider`) and states plainly that GitHub URL sources and automatic updates are unavailable.

## Schema & design boundary

The repository keeps `quickshell/schemas/sources.schema.json` to document the intended storage contract for any future implementation:

- Strict validation of public `https://github.com/owner/repo` source records without shell interpolation.
- Namespace separation (`github-<hash>:<pack-id>`) so remote packs cannot collide with bundled or local packs (`bundled:*`, `local-*:*`).
- Immutable commit pinning, bounded manifest/image decoding before activation, and rollback preservation identical to `LocalProvider`.

Until remote transport is implemented, use local collections via `themes.py import /path/to/collection` or Settings -> Appearance -> Import local collection.
