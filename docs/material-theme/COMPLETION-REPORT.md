# Wizard / Wizarch Material theme implementation report

Implementation and verification date (updated after local reliability review): 2026-10-09 UTC. Source checkout: `/home/Mw/Documents/Codex/Wizarch`. Audit baseline: `/home/Mw/ChatGPT/Wizarch Shell/audit/complete-diagnosis-20261009/`. Starting Git HEAD: `4ba01459aa40556fd645baa84aef122d4af077a1`; this checkout already contained unrelated edits and untracked components. No reset, clean, commit, push, repository creation or theme-source fetch was performed.

The local pipeline now provides complete Material roles, two bundled light/dark exports, functional local collection import, independent mode/wallpaper selection, durable recovery and an Appearance workflow. GitHub source transport/import/update execution remains explicitly non-operational. This report distinguishes source changes, deployment, automated evidence and actual Wayland renders; device fixtures and unexecuted cases are identified below.


The independent completion review reproduced four local bounds/recovery defects. They are now fixed and regression-tested, with import directory syncing, explicit runtime selection and override-preview agreement also addressed. [REVIEW-FIXES.md](REVIEW-FIXES.md) maps each finding to behavior and tests; [review deployment evidence](evidence/review-deployment.json) records the eight installed fixes and preserved current state. GitHub execution remains deferred.

A further requested desktop-mode integration is now deployed: mode activation also updates the OS appearance preference, GTK compatibility settings and Qt launch integration. [DESKTOP-APPEARANCE.md](DESKTOP-APPEARANCE.md) records the five selective shell changes, backups, 53 passing pipeline tests, six real toolkit renders, installed activation cycles, and app/X11/persistence limitations. The shell palette and wallpaper remain independently selected.

## Goal evidence checklist

| Requested objective | Result and evidence |
| --- | --- |
| Three configurable accent families, complete semantic roles, light/dark, existing interactions/geometry | Implemented: 46 canonical roles and compatibility aliases; exported dark characters preserved; genuine MCU light schemes; [role/component map](ROLE-MAP.md), contrast evidence, geometry comparison and runtime matrix |
| Versioned authoring/validation/catalog/preferences/provider/activation separation | Implemented in small theming modules, eight authoritative schemas, local import, one event watcher, saved stable IDs and independent overrides; fault-injected pipeline tests |
| Validated snapshots, cross-process serialization, recovery/rollback/last-good | Implemented; active.json is the commit point; journal reconciles both sides; compositor baseline errors and rollback errors distinguished; [protocol](RECOVERY.md) |
| Future multi-pack GitHub contracts without execution | Delivered: portable example, source schema, URL identity contract, deferred provider, UI notice, update/removal/network policies and deferred tests; [contract](GITHUB-CONTRACT.md) |
| Available bundled modes plus custom/exported/higher contrast render verification | Actual nested Wayland matrix, numeric pairs, all eleven Settings pages, media/notification fixtures, error/preview/state/morph/restart/switch/monitor checks. Details below; hardware and other limitations are not certified |
| Documentation, migration, completion report and return handoff | Delivered in this directory, with exact file/evidence indexes and restore instructions. No other chat was messaged |

[Requirement-by-requirement completion audit](evidence/requirements-audit.json) ties the original scope to current artifacts and distinguishes available checks from unverified physical/hardware cases.

## Architecture and decisions

| Responsibility | Implementation boundary |
| --- | --- |
| XDG config/data/cache/state and old-state adapter | `services/theming/paths.py:Paths`, `migration.py:legacy` |
| Strict JSON/schema/identity/path/image validation | `validation.py:validate`, `contained`, `asset`, `bounded_files`; jsonschema is authoritative, QML scanning is additional coverage |
| Material generation/export/contrast | `color.py:generate`, `resolve`, `import_export`, `contrast_results`; generation outside QML/render loops |
| Discovery/cache/diagnostic entries | `catalog.py:Catalog`; invalid packs remain visible; cached data revalidated, assets invalidated by bounded stat fingerprints |
| Local staging and immutable registration | `providers.py:LocalProvider`; shared lock; declared data/images only, seed inputs compiled to approved resolved exports |
| Publication/compositor/reconciliation | `activation.py:Engine`, `Compositor`, `lua`; durable writes/lock in `storage.py`; argument arrays, colors-only compositor fragment |
| Catalog reactivity | `watch.py:watch`; one shared inotify process watches current registered revisions, avoids retained snapshot trees and selection-triggered rescans; explicit Refresh remains available |
| QML API and presentation | `core/Theme.qml`; one committed FileView and centralized processes, aliases for standard on-role names, latest pending apply coalescing, presentation-only draft preview |
| Appearance and controls | `panels/SettingsView.qml`, shared themed components; mode, three swatches, independent wallpapers, diagnostics, Apply/Cancel/Refresh/Rollback and local path Import |

The generator pins `material-color-utilities==0.2.6` (Apache-2.0, pybind11 wrapper around Google's C++ HCT implementation), its pre-2025 dynamic roles, TONALSPOT variant plus explicit HCT tonal palettes for each supplied key, and contrast levels 0/0.5/1. The release implements Material 3 2021 scheme semantics with its tonal surface/fixed roles; no 2025 implementation is claimed. Omitted secondary/tertiary use documented deterministic defaults. Explicit keys influence only their respective families. Full exported schemes are retained verbatim; contradictory seed/export objects are rejected. The source archive hash, API verification, lock file and license establish the reproduction inputs; persisted exports avoid runtime regeneration or network dependency. See [authoring](AUTHORING.md) and [provenance](evidence/generator-provenance.json).

Wizarch retains its dark violet character and original wallpapers; Eclipse retains its dark monochrome colors and locally available private wallpaper. Their new light exports are complete and validated. Private Eclipse artwork is still intentionally excluded from Git. A missing asset yields a visible invalid pack, never a fabricated replacement. The copyable Aurora collection has three distinct inputs, higher contrast 0.5 and an authored CC0 solid wallpaper; local installation compiles it into offline exports. Numeric contrast also verifies level 1; the runtime representative uses level 0.5.

Standard on-role names need readonly aliases to an internal ink object because Qt interpreted direct `on…` bindings as handlers and left colors black. Actual runtime tests compare all 46 getters to the committed role bag. Color animations stop during revision publication to avoid transient light/dark ink/background mismatches; geometry/motion behaviors retain their timings. Selected wheel/tile boundaries use the matching on-role where primary would not contrast with their selected container, particularly at increased contrast. This was caught numerically rather than inferred from HCT or screenshot existence.

## Schemas, examples and user workflows

All schemas are Draft 2020-12, schemaVersion 1, under `quickshell/schemas/`: pack, palette, selection, snapshot, catalog, overrides, material-export, and sources. Integer validation rejects booleans and integral floats. Strict JSON parsing rejects duplicate fields and non-finite numbers, including numeric overflow. Metadata and diagnostics are plain text so a pack cannot introduce rich-text colors or remote images. A valid expanded pack record over 256 KiB bypasses disk caching while retaining bounded validation/memory use. Single-mode seed packs expose exactly their declared modes; the deterministic generator cache can retain both. Core fields/enums/ranges/colors are explicit; misspellings and unknown versions fail with field paths. Pack extensions alone allow inert namespaced extra data. Schemas, canonical manifests, loader and `examples/material-collection/catalog.json` agree on `themes/<id>/theme.json`, relative assets, and exactly one color input. Runtime registration/paths never live in portable content.

Use [AUTHORING.md](AUTHORING.md) for the copyable layout, full-role import conversion, seed generation, local import, namespaces, licenses, limits and override merge order. The environment is local under XDG data; the CLI selects it but never installs packages automatically. Resolved activation needs jsonschema/Pillow; MCU is only required for generation. Built-in resolved QML fallback needs no Python dependency or artwork.

New image assets are PNG/JPEG/WebP, verified and fully decoded with bounded dimensions/pixels/files/bytes. Canonical containment includes symlinks. New SVGs and executable content/hooks are rejected; existing bundled SVG compatibility rejects external references/scripts/entities/unsafe tags. Optional logos/previews fall back visibly. Cache and managed-storage budgets are hard bounds. Old imported revisions remain intact for active/rollback paths; automatic garbage collection/removal is not implemented, so further import stops at the bound rather than deleting a referenced snapshot.

Preview changes only the Appearance draft. Closing/Cancel does not publish selection, compositor colors or active.json. Apply performs one complete transaction. Mode and wallpaper selections have separate stable IDs. Wallpaper changes never regenerate/extract colors; a supported mode follows pack selection, and compatible wallpaper IDs survive mode changes. Required missing assets prevent activation; a removed wallpaper ID falls back to the pack default only on a subsequent compatible activation. Independent overrides remain outside pack content and are never overwritten by Apply/import.

## Migration, transaction and recovery

[RECOVERY.md](RECOVERY.md) gives exact paths, precedence, commands and restoration instructions. The old installed `state/active.json` stays untouched. A valid committed snapshot wins; corrupt current state recovers last-good; valid saved selection is reapplied; unavailable/corrupt established selection is retained and reported with a usable QML fallback, rather than silently choosing an unrelated pack.

One shared flock serializes activation/rollback/import; acquisition timeout is 15 seconds, not guaranteed simultaneous-request invocation order. QML coalesces pending applies to the latest complete request and lets an in-flight transaction finish. There is no durable applying flag. Each transaction validates a complete snapshot, journals previous exact bytes and baseline compositor errors, stages color Lua, reloads/checks new errors, writes selection and finally publishes active.json as the observable commit point. It then records previous/last-good and removes the journal. All atomic writes fsync file and directory.

Several files and a compositor are not physically atomic. The staged compositor may briefly precede the QML snapshot. Recovery restores prior bytes before commit or repairs/finalizes the published snapshot after commit. Precommit failures roll back; rollback failures retain the journal and report separately. Postcommit finalization failures return a committed-with-recovery-warning result and retain the journal. No executable pack values are interpolated into Lua or commands; only strict hex roles are emitted. Tests inject rejection, interrupted phases and finalization/rollback failures in temporary directories, never live configuration.

## Preservation and deployment

Deployment details and exact before/after hashes are in [deployment evidence](evidence/deployment.json). Source changes are measured against the start-of-task source backup, rather than attributing the checkout's preexisting Git diff to this task. The installed QuickSettings stateLabel remains its original Sound/Muted/On/Off expression; the audited unrelated source expression remains in source. This one deliberate source/install difference is retained.

SystemServices.qml, Workspaces.qml, shell.qml and workspaces.py match their task-start hashes. Device settings, user preference content, wallpaper assets, monitor layouts, keyboard mappings and unrelated Hyprland config were not replaced. No theme swap restarts the shell. Software deployment uses normal source reloads during the single file batch; no full-checkout copying. The transient compile failure and subsequent successful load are recorded below. Final fixes were applied to seven listed files, retaining original rollback bytes; the ordinary source reload refreshed the shared catalog watcher without restarting the live process.

The prior generated Lua contained geometry. Measured rounding 12/border width 2 are transferred into a static `wizarch-theme-geometry.lua` imported immediately before the colors fragment. Activation never writes that geometry file or main Hyprland config. This targeted migration prevents removing theme-owned geometry from exposing different base values. The generated fragment only sets primary active/outlineVariant inactive borders, without blur/shadow/effects.

The initial migration retained Eclipse dark/original wallpaper. The review deployment preserved the then-current Wizarch dark/Nocturne selection. A subsequent independent change to Eclipse light/original is observed and left untouched. Rollback copies and generated XDG records are listed in the deployment evidence. Screenshots and all preview/switch operations were isolated; no live device control was exercised. The original legacy state and private wallpaper bytes remain intact.

## Automated verification

| Command or suite | Evidence and scope |
| --- | --- |
| `work/theme-env/bin/python tests/material-themes.py` | [pipeline-tests.txt](evidence/pipeline-tests.txt): 27 passing tests; schema/type/role/export/determinism/contrast/containment/assets/diagnostics/refresh/inotify/import/persistence/mode/wallpaper/invalid state/overrides/recovery/concurrency/rejection/rollback/interrupted publication/finalization. Pure URL/schema fixtures do not test remote integration |
| `work/theme-env/bin/python tests/material-color-coverage.py` | [color-coverage.json](evidence/color-coverage.json): all 46 API roles; only classified OverlayShadow black/white effect literals remain; artwork exceptions documented |
| WCAG numeric checks | [contrast.json](evidence/contrast.json): exact exported and generated roles, actual on-role pairs, neutral text, fixed/inverse roles, focus/outline/error indicators and composited hover/focus/pressed layers. Enabled ordinary text ≥4.5, meaningful controls/focus ≥3; inactive/decorative cases excepted in role map |
| Existing Python regression suites | [regression-tests.txt](evidence/regression-tests.txt): reliability, layouts, wheel model, native frames/stack, windows, workspaces, preference writer pass; wheel offscreen failure preserved as unavailable backend evidence |
| Qt Settings fixture | [settings-tests.txt](evidence/settings-tests.txt): all-page routing/search/preferences/audio/theme handlers, compact/wide navigation, retry and close/reopen pass; fixture does not claim physical device integration |
| Real Wayland wheel Qt integration | [wheel-wayland-tests.txt](evidence/wheel-wayland-tests.txt): keyboard handlers, sectors/dead zone, confirmation, previous target, invalid monitor/cancellation pass; Qt offscreen cannot host this PanelWindow |
| JavaScript and Lua regressions | [JS reliability](evidence/js-reliability-tests.txt), [JS wheel](evidence/js-wheel-tests.txt), [Lua Scrolling](evidence/lua-scrolling-tests.txt): queue/calendar/launcher/reveal intent, radial navigation and native lifecycle/workspace isolation pass |
| Additional production controls | `work/theme-env/bin/python tests/material-controls-wayland.py --session work/material-verification`; [controls-wayland-tests.txt](evidence/controls-wayland-tests.txt): 36 actual renders, six controls in all six modes, PlainText metadata proven in Qt, selection/caret/popup/tooltip properties verified |
| Review regressions | `work/theme-env/bin/python tests/material-review.py`; [review-regression-tests.txt](evidence/review-regression-tests.txt): 13 tests for R1–R4, quotas/boundaries/replacement/isolation, limited reads/FIFO/growth, caches, directory sync calls, configured/partial runtime and override agreement |
| Actual override agreement | `work/theme-env/bin/python tests/material-overrides-wayland.py --session work/material-verification`; [override-wayland-tests.txt](evidence/override-wayland-tests.txt): inactive card/draft/apply and edited-active preview/cancel, decoded preview assets, 3 actual captures |
| Actual rendered matrix | [wayland-tests.txt](evidence/wayland-tests.txt), screenshot index below: production QML on nested Hyprland, exact getter/snapshot comparison, open-panel and morph preservation, draft cancellation, shared-control states, error/restart/resources/virtual monitor coverage |

The Python fixture uses a public transaction pack derived from Wizarch so missing private Eclipse art cannot invalidate unrelated transaction tests. Existing Eclipse completeness is verified only when its real asset is present; its unavailable diagnostic is always exercised. Fault injection simulates process interruption, not physical power-loss testing.

## Runtime screenshots and coverage

The isolated session uses a separate XDG runtime/config/data/cache/state, compositor IPC and private D-Bus. The test uses the real production Pill, Wallpaper, frame guard, SettingsWindow and QuickWheel. Media and notification data are deterministic local Qt fixtures; no messages are sent, and no radio/audio/power/device settings are changed. BlueZ/PipeWire unavailable warnings are expected in this isolated runtime, including PipeWire connection errors. Unchanged native-workspace helpers may warn during virtual monitor removal. The empty warning arrays filter QML binding/type/load failures; they do not claim the complete service log is warning-free. No mockup is labelled a screenshot.

Screenshot files are under `/home/Mw/Documents/Codex/Wizarch/outputs/material-theme/`, intentionally ignored because they include private artwork. [Runtime index](/home/Mw/Documents/Codex/Wizarch/outputs/material-theme/index.json) records theme/mode/surface, content revision, source-content SHA256, actual geometry, rendered role pixel counts and notes. [Additional controls index](/home/Mw/Documents/Codex/Wizarch/outputs/material-theme/controls-index.json) records 36 further production-control captures, observed state, revision and the same source hash. [Override index](/home/Mw/Documents/Codex/Wizarch/outputs/material-theme/overrides-index.json) records three additional production override captures. [Inspection notes](evidence/screenshot-inspection.json) record viewed content and limits. Main captures are 1920×1080. Contact sheets crop/scale those actual images for inspection (including `inspection-*` and `controls-contact.png`); they are not independent renders or accessibility measurements.

| Captured surfaces | Eclipse dark/light | Wizarch dark/light | Aurora 0.5 dark/light |
| --- | --- | --- | --- |
| Closed pill + frame + wallpaper/desktop | Both | Both | Both |
| Search and week/month/year calendar | Both | Both | Both |
| Quick Settings + disabled controls + media | Both | Both | Both |
| Ordinary/urgent notifications + wheel | Both | Both | Both |
| Wi-Fi, Network, Bluetooth, Displays, Sound, Power | All pages/both | All pages/both | All pages/both |
| Multitasking, Appearance, Panel, Notifications, Keyboard | All pages/both | All pages/both | All pages/both |
| Appearance focused/hover/pressed shared buttons | All states/both | All states/both | All states/both |
| Search selection/caret, context menu, mode popup, Apps tooltip, literal metadata | All six controls/both | All six controls/both | All six controls/both |
| Complete override preview/card/apply/cancel | Separate 3-capture case | Verified with Wizarch overrides | See override index |
| Additional failure/restart/resources/second-monitor cases | See index | See index | See index |

Inspection checks actual tonal hierarchy and ink, critical urgency, disabled distinction, selected controls, unchanged outlines/placement, wallpaper/frame behavior and page coverage. Numeric validation accompanies the images; neither HCT nor screenshots alone establish contrast. Calendar events and notification action rows do not exist in the current shell; today/navigation and dismiss/clear are covered, rather than inventing those interfaces. The additional controls run independently captures search selection/caret, launcher context menu, mode popup, Apps tooltip, and literal pack metadata in every mode. It asserts actual Qt focus/selection/cursor/popup/tooltip properties and all 46 role getters. These are production controls with deterministic fixture metadata, not mocked drawings.

The task-start/runtime baseline is closed pill 194×42, launcher width 420, other panel widths 360, opening/closing sequences 90+250+120≈460 ms, resizing 240 ms, hide motion 280 ms and reveal gate 290 ms. [Geometry comparison](evidence/geometry-preservation.json) confirms timing/geometry statements remain identical; QuickWheel adds tonal text backing inside existing label bounds only. Actual geometry probes validate settled sizes and theme changes during an existing morph. These timing constants are not a hardware-independent frame-time claim.

## Performance, limits and remaining work

[performance.json](evidence/performance.json) compares six fresh CLI processes using the start-of-task service and the new service with separate temporary caches, identical bundled assets and no network. Baseline first catalog list: 51.18 ms; warm median: 54.29 ms. New first: 700.20 ms; warm median: 242.57 ms. Strong schema/image validation and Python dependency startup cost more; no speedup is claimed. Ordinary render/animation loops do no HCT work. Runtime switch timings and resource counts are in the final index/evidence summary below.

The validation targets enabled text on actual owned backgrounds. Existing disabled opacities, inactive calendar dates, decorative dividers/inactive borders, original contrast halos and third-party art are documented exceptions. Borders against arbitrary application/artwork backgrounds cannot have a universal contrast guarantee. Hardware services are represented by fixtures or isolated unavailable states, not end-to-end network/Bluetooth/audio/power tests. No physical monitor hotplug, system reboot, real power loss, every display/GPU/scale, or long-term memory soak is certified. Virtual monitor creation/removal and repeated switching provide bounded evidence only. Real keyboard/focus behavior uses existing Qt handler tests and actual nested focus/pointer interaction; a comprehensive physical-keyboard/assistive-technology audit remains outside this verification.

Managed-content automatic GC/removal and wallpaper color extraction are not implemented. Higher contrast is selectable in pack authoring/exports, rather than a global appearance switch. Provider transport for GitHub remains deferred: no repositories created, theme repositories cloned/fetched, URLs installed, authentication configured, content published/pushed, update schedules created, network updater activated or remote integration tests executed. [GITHUB-CONTRACT.md](GITHUB-CONTRACT.md) defines independent pack validation, immutable revision snapshots, source identities/records, public URL forms, future policies and deferred test plan. Review that contract before implementing authorized remote behavior.


## Post-review local performance

Fresh measurements run after rendered verification, with no overlapping owned capture/test workload. Baseline is the task-start shell; before-review is the exact `60b14ee843a833e3222cae7e19e1fff2e220a65f5d0d13f927bc589a5c73794c` source restored from preserved installed bytes; final is this fix implementation. Six CLI runs and three Configuration Loaded samples per implementation are small observations, not first-pixel or all-machine claims.

| Measurement | Task-start | Before review fixes | After review fixes |
| --- | ---: | ---: | ---: |
| First catalog list | 55.47 ms | 747.19 ms | 701.31 ms |
| Warm fresh-process catalog median | 59.05 ms | 211.78 ms | 214.32 ms |
| Nested compositor CLI switch median | 63.62 ms | 597.70 ms | 612.32 ms |
| Wayland Configuration Loaded median | 346.55 ms | 377.59 ms | 377.58 ms |

Full method, samples and copied production source hashes are retained in the review performance JSON files. The final full-shell performance copy includes concurrent launcher work; Configuration Loaded timings are observational and cannot isolate the cost of these eight theme fixes. Theme CLI timing does not execute launcher QML. The reliability fixes do not demonstrate a selection/listing speedup; small differences can reflect run variability. The three 80 ms compositor acceptance waits remain a 240 ms floor. Process reuse, stage profiling and event-driven acceptance are future optimization candidates; they were not substituted for locking, validation or durable recovery in this bounded follow-up.

The review verification compositor/private bus were stopped; the host compositor/shell and the independent launcher verification session were left running. No hardware, physical power-loss or remote integration tests were performed.

## Exact file and final evidence indexes

The machine-readable [source file list](evidence/source-files.json) lists only shell files changed/added by this task relative to the task-start backup. Additional task files are the Material docs/evidence, portable example, targeted tests/legacy fixtures and minimal README links. Preexisting unrelated source changes remain uncommitted and unaltered; use the baseline hashes before attributing a Git diff.

Final rendered source-content SHA256 (QML/Python/JS/JSON, including manifests/schemas): `9c3a852b558a62106a29641df6858bc05ccf91a627645929dcfbb2a29a6ef76b`. It matches the main/control indexes, second-monitor record and independently reconstructed production hash for the override harness. The override index retains its original observed whole-checkout hash, 8bdc00c0e219da683552c5a0a3a5f7e4ff326669a601b3c9d85d7e81de103aac, and labels that as capture-time checkout context; concurrent launcher changes were absent from its production copy. All eight theme-fix files match current source, installed files and the rendered production copy. Whole-checkout hash observed when writing the report (concurrent work may continue): `c2c2741ccd0bf0d92c5fe46e67f041813e9555786831c409bf5c8366ace9377a`. Independent launcher edits appeared during verification: LauncherIcon.qml, LauncherModel.js, LauncherView.qml and launcher-desktop.py. They were preserved, excluded from this fix deployment, and **not** claimed as covered by the rendered snapshot. The installed UI retains the audited Quick Settings stateLabel difference; installed README links resolve to this source checkout.

- 27 original pipeline tests and 13 review regressions pass (40 total). Eight numerical scheme cases cover 704 pairs, including both generated contrast levels 0.5/1. Minimum enabled-text ratio: 4.5262:1; minimum tested meaningful-indicator ratio: 3.2072:1. Disabled/decorative/artwork exceptions are not counted as passing text/control pairs.
- 132 matrix screenshots (22 per theme/mode), one activation-error screenshot, 36 additional control captures (six per theme/mode), three override-preview/apply screenshots, one second-monitor screenshot, and two cropped live installed-calendar screenshots (the earlier Eclipse capture is historical): **175 indexed actual captures, 173 isolated**. Contact sheets and inspection crops are derivatives, not additional captures. All six mode cases preserve open search and calendar navigation, cancel preview without publication, and finish an in-progress morph.
- Ten additional alternating switches: one watcher/one descendant before and after; descriptors 55→54. This is a bounded leak check, not a soak guarantee. Restart retains the committed revision, colors and selection. A virtual second monitor creates two pills; removal returns to one. Actual outside click and directional edge reveal succeed with the preserved 1200 ms hide delay, 120 ms edge intent and 280 ms hide motion.
- Final matrix request-to-idle timings: range 692.69–742.65 ms, median 721.82 ms. The historical [runtime performance](evidence/runtime-performance.json) samples remain available. Fresh post-review comparisons are in [review runtime performance](evidence/review-runtime-performance.json) and [review catalog performance](evidence/review-catalog-performance.json), summarized below. No first-pixel, FPS or generalized speedup is claimed.
- Initial migration preserved Eclipse dark/original. Before this review deployment the user had selected Wizarch dark/Nocturne, revision `ab64ddc83832727ee9bf95fd89115f93f2844e874a6de8dd5d179e7fa7f75d0c`; that selection, snapshot, preferences and generated colors were byte-identical across the eight-file deployment and post-install render check. A later independent Eclipse light/original change is recorded without reverting it. Geometry stays rounding 12/border 2 and both host monitors retain 10 px frame reservations. No steady-state QML/compositor errors. The initial deployment's transient batch reload error remains disclosed. Fresh live calendar role pixels match within 8 RGB levels; the temporarily shown read-only calendar was closed and auto-hidden again. An initial auto-hidden frame crop had no text and was discarded, not labelled a passing render.
- Backup: `/home/Mw/Documents/Codex/Wizarch/work/material-deployment-backup/manifest.json`; task-start source/install snapshots: `/home/Mw/Documents/Codex/Wizarch/work/material-baseline/`. Restore only listed targets. New state files: `/home/Mw/.local/state/wizarch/theme` (active.json, last-good.json, previous-good.json, operation.lock); schema/cache records under XDG cache; local venv `/home/Mw/.local/share/wizarch/theme-runtime/` with the dependency lock. No journal remains after the successful live commit. [Cleanup evidence](evidence/cleanup.json) records termination of the isolated compositor/private bus and restoration of the live calendar to closed state.

[Final current-state gates](evidence/final-gates.txt) check source/index identity, installed hashes, preserved live selection/preferences/label, no journal or runtime errors, documentation links and `git diff --check`.

### Code entry points

- [services/theming/activation.py — class Engine:](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/activation.py:25)
- [services/theming/activation.py — def _commit(](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/activation.py:104)
- [services/theming/activation.py — def _reconcile(](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/activation.py:52)
- [services/theming/providers.py — class LocalProvider:](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/providers.py:25)
- [services/theming/providers.py — class GitHubProvider:](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/providers.py:96)
- [services/theming/color.py — def generate(](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/color.py:7)
- [services/theming/validation.py — def validate(](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/validation.py:18)
- [services/theming/catalog.py — class Catalog:](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/catalog.py:8)
- [services/theming/watch.py — def watch(](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/watch.py:5)
- [core/Theme.qml — function apply(](/home/Mw/Documents/Codex/Wizarch/quickshell/core/Theme.qml:44)
- [panels/SettingsView.qml — Theme colours](/home/Mw/Documents/Codex/Wizarch/quickshell/panels/SettingsView.qml:41)

### Task-owned source file list

[changed-files.json](evidence/changed-files.json) distinguishes original Material changes, the eight reviewed fixes and concurrent work excluded from attribution. The inventory excludes private artwork, screenshots and ignored work directories. LauncherView.qml contains earlier Material edits and newer independent edits; this list does not attribute that whole current file to the review fixes.

- [.gitignore](/home/Mw/Documents/Codex/Wizarch/.gitignore)
- [README.md](/home/Mw/Documents/Codex/Wizarch/README.md)
- [docs/material-theme/AUTHORING.md](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/AUTHORING.md)
- [docs/material-theme/COMPLETION-REPORT.md](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/COMPLETION-REPORT.md)
- [docs/material-theme/GENERATOR-LICENSE.txt](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/GENERATOR-LICENSE.txt)
- [docs/material-theme/GITHUB-CONTRACT.md](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/GITHUB-CONTRACT.md)
- [docs/material-theme/RECOVERY.md](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/RECOVERY.md)
- [docs/material-theme/REVIEW-FIXES.md](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/REVIEW-FIXES.md)
- [docs/material-theme/ROLE-MAP.md](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/ROLE-MAP.md)
- [docs/material-theme/evidence/changed-files.json](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/changed-files.json)
- [docs/material-theme/evidence/cleanup.json](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/cleanup.json)
- [docs/material-theme/evidence/color-coverage.json](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/color-coverage.json)
- [docs/material-theme/evidence/contrast.json](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/contrast.json)
- [docs/material-theme/evidence/controls-wayland-tests.txt](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/controls-wayland-tests.txt)
- [docs/material-theme/evidence/deployment.json](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/deployment.json)
- [docs/material-theme/evidence/final-gates.txt](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/final-gates.txt)
- [docs/material-theme/evidence/generator-provenance.json](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/generator-provenance.json)
- [docs/material-theme/evidence/geometry-preservation.json](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/geometry-preservation.json)
- [docs/material-theme/evidence/js-reliability-tests.txt](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/js-reliability-tests.txt)
- [docs/material-theme/evidence/js-wheel-tests.txt](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/js-wheel-tests.txt)
- [docs/material-theme/evidence/lua-scrolling-tests.txt](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/lua-scrolling-tests.txt)
- [docs/material-theme/evidence/override-wayland-tests.txt](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/override-wayland-tests.txt)
- [docs/material-theme/evidence/performance.json](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/performance.json)
- [docs/material-theme/evidence/pipeline-tests.txt](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/pipeline-tests.txt)
- [docs/material-theme/evidence/regression-tests.txt](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/regression-tests.txt)
- [docs/material-theme/evidence/requirements-audit.json](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/requirements-audit.json)
- [docs/material-theme/evidence/review-catalog-performance.json](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/review-catalog-performance.json)
- [docs/material-theme/evidence/review-deployment.json](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/review-deployment.json)
- [docs/material-theme/evidence/review-regression-tests.txt](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/review-regression-tests.txt)
- [docs/material-theme/evidence/review-runtime-performance-tests.txt](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/review-runtime-performance-tests.txt)
- [docs/material-theme/evidence/review-runtime-performance.json](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/review-runtime-performance.json)
- [docs/material-theme/evidence/runtime-performance.json](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/runtime-performance.json)
- [docs/material-theme/evidence/screenshot-inspection.json](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/screenshot-inspection.json)
- [docs/material-theme/evidence/settings-tests.txt](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/settings-tests.txt)
- [docs/material-theme/evidence/source-files.json](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/source-files.json)
- [docs/material-theme/evidence/verification-summary.json](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/verification-summary.json)
- [docs/material-theme/evidence/wayland-tests.txt](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/wayland-tests.txt)
- [docs/material-theme/evidence/wheel-wayland-tests.txt](/home/Mw/Documents/Codex/Wizarch/docs/material-theme/evidence/wheel-wayland-tests.txt)
- [examples/hyprland-wizarch.lua](/home/Mw/Documents/Codex/Wizarch/examples/hyprland-wizarch.lua)
- [examples/material-collection/catalog.json](/home/Mw/Documents/Codex/Wizarch/examples/material-collection/catalog.json)
- [examples/material-collection/themes/aurora/theme.json](/home/Mw/Documents/Codex/Wizarch/examples/material-collection/themes/aurora/theme.json)
- [examples/material-collection/themes/aurora/wallpapers/dusk.png](/home/Mw/Documents/Codex/Wizarch/examples/material-collection/themes/aurora/wallpapers/dusk.png)
- [quickshell/README.md](/home/Mw/Documents/Codex/Wizarch/quickshell/README.md)
- [quickshell/components/ControlTile.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/components/ControlTile.qml)
- [quickshell/components/Glyph.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/components/Glyph.qml)
- [quickshell/components/Pill.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/components/Pill.qml)
- [quickshell/components/QuickWheel.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/components/QuickWheel.qml)
- [quickshell/components/ScrollingStack.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/components/ScrollingStack.qml)
- [quickshell/components/SettingsButton.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/components/SettingsButton.qml)
- [quickshell/components/SettingsChoice.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/components/SettingsChoice.qml)
- [quickshell/components/SettingsSwitch.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/components/SettingsSwitch.qml)
- [quickshell/components/SettingsThemeCard.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/components/SettingsThemeCard.qml)
- [quickshell/components/SettingsWindow.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/components/SettingsWindow.qml)
- [quickshell/components/ThemeLogo.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/components/ThemeLogo.qml)
- [quickshell/components/ThemedScrollBar.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/components/ThemedScrollBar.qml)
- [quickshell/components/ThemedToolTip.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/components/ThemedToolTip.qml)
- [quickshell/components/Wallpaper.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/components/Wallpaper.qml)
- [quickshell/core/Fallback.js](/home/Mw/Documents/Codex/Wizarch/quickshell/core/Fallback.js)
- [quickshell/core/Theme.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/core/Theme.qml)
- [quickshell/panels/ConnectivityView.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/panels/ConnectivityView.qml)
- [quickshell/panels/InputPicker.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/panels/InputPicker.qml)
- [quickshell/panels/LauncherView.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/panels/LauncherView.qml)
- [quickshell/panels/NotificationCenter.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/panels/NotificationCenter.qml)
- [quickshell/panels/QuickSettings.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/panels/QuickSettings.qml)
- [quickshell/panels/SettingsConnectivity.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/panels/SettingsConnectivity.qml)
- [quickshell/panels/SettingsView.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/panels/SettingsView.qml)
- [quickshell/panels/ThemePicker.qml](/home/Mw/Documents/Codex/Wizarch/quickshell/panels/ThemePicker.qml)
- [quickshell/requirements-theme.lock](/home/Mw/Documents/Codex/Wizarch/quickshell/requirements-theme.lock)
- [quickshell/requirements-theme.txt](/home/Mw/Documents/Codex/Wizarch/quickshell/requirements-theme.txt)
- [quickshell/schemas/catalog.schema.json](/home/Mw/Documents/Codex/Wizarch/quickshell/schemas/catalog.schema.json)
- [quickshell/schemas/material-export.schema.json](/home/Mw/Documents/Codex/Wizarch/quickshell/schemas/material-export.schema.json)
- [quickshell/schemas/overrides.schema.json](/home/Mw/Documents/Codex/Wizarch/quickshell/schemas/overrides.schema.json)
- [quickshell/schemas/pack.schema.json](/home/Mw/Documents/Codex/Wizarch/quickshell/schemas/pack.schema.json)
- [quickshell/schemas/palette.schema.json](/home/Mw/Documents/Codex/Wizarch/quickshell/schemas/palette.schema.json)
- [quickshell/schemas/selection.schema.json](/home/Mw/Documents/Codex/Wizarch/quickshell/schemas/selection.schema.json)
- [quickshell/schemas/snapshot.schema.json](/home/Mw/Documents/Codex/Wizarch/quickshell/schemas/snapshot.schema.json)
- [quickshell/schemas/sources.schema.json](/home/Mw/Documents/Codex/Wizarch/quickshell/schemas/sources.schema.json)
- [quickshell/services/preferences.py](/home/Mw/Documents/Codex/Wizarch/quickshell/services/preferences.py)
- [quickshell/services/themes.py](/home/Mw/Documents/Codex/Wizarch/quickshell/services/themes.py)
- [quickshell/services/theming/__init__.py](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/__init__.py)
- [quickshell/services/theming/activation.py](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/activation.py)
- [quickshell/services/theming/catalog.py](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/catalog.py)
- [quickshell/services/theming/color.py](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/color.py)
- [quickshell/services/theming/migration.py](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/migration.py)
- [quickshell/services/theming/paths.py](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/paths.py)
- [quickshell/services/theming/providers.py](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/providers.py)
- [quickshell/services/theming/storage.py](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/storage.py)
- [quickshell/services/theming/validation.py](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/validation.py)
- [quickshell/services/theming/watch.py](/home/Mw/Documents/Codex/Wizarch/quickshell/services/theming/watch.py)
- [quickshell/themes/eclipse/colors.json](/home/Mw/Documents/Codex/Wizarch/quickshell/themes/eclipse/colors.json)
- [quickshell/themes/eclipse/theme.json](/home/Mw/Documents/Codex/Wizarch/quickshell/themes/eclipse/theme.json)
- [quickshell/themes/wizarch/colors.json](/home/Mw/Documents/Codex/Wizarch/quickshell/themes/wizarch/colors.json)
- [quickshell/themes/wizarch/theme.json](/home/Mw/Documents/Codex/Wizarch/quickshell/themes/wizarch/theme.json)
- [tests/fixtures/material-legacy/eclipse.json](/home/Mw/Documents/Codex/Wizarch/tests/fixtures/material-legacy/eclipse.json)
- [tests/fixtures/material-legacy/wizarch.json](/home/Mw/Documents/Codex/Wizarch/tests/fixtures/material-legacy/wizarch.json)
- [tests/material-color-coverage.py](/home/Mw/Documents/Codex/Wizarch/tests/material-color-coverage.py)
- [tests/material-controls-wayland.py](/home/Mw/Documents/Codex/Wizarch/tests/material-controls-wayland.py)
- [tests/material-overrides-wayland.py](/home/Mw/Documents/Codex/Wizarch/tests/material-overrides-wayland.py)
- [tests/material-pointer.c](/home/Mw/Documents/Codex/Wizarch/tests/material-pointer.c)
- [tests/material-review.py](/home/Mw/Documents/Codex/Wizarch/tests/material-review.py)
- [tests/material-themes.py](/home/Mw/Documents/Codex/Wizarch/tests/material-themes.py)
- [tests/material-wayland.py](/home/Mw/Documents/Codex/Wizarch/tests/material-wayland.py)
- [tests/quick-wheel-qt.py](/home/Mw/Documents/Codex/Wizarch/tests/quick-wheel-qt.py)
- [tests/settings-window-qt.py](/home/Mw/Documents/Codex/Wizarch/tests/settings-window-qt.py)
- [tests/theme-fixture.py](/home/Mw/Documents/Codex/Wizarch/tests/theme-fixture.py)

### Exact live-installed targets

The 55 entries below include 51 selectively installed shell files and targeted theme integration/selection files. Runtime venv/cache/state directories are separate artifacts. [deployment.json](evidence/deployment.json) contains prior existence, original backup paths and before/after SHA256.

- [/home/Mw/.config/quickshell/README.md](/home/Mw/.config/quickshell/README.md)
- [/home/Mw/.config/quickshell/components/ControlTile.qml](/home/Mw/.config/quickshell/components/ControlTile.qml)
- [/home/Mw/.config/quickshell/components/Glyph.qml](/home/Mw/.config/quickshell/components/Glyph.qml)
- [/home/Mw/.config/quickshell/components/Pill.qml](/home/Mw/.config/quickshell/components/Pill.qml)
- [/home/Mw/.config/quickshell/components/QuickWheel.qml](/home/Mw/.config/quickshell/components/QuickWheel.qml)
- [/home/Mw/.config/quickshell/components/ScrollingStack.qml](/home/Mw/.config/quickshell/components/ScrollingStack.qml)
- [/home/Mw/.config/quickshell/components/SettingsButton.qml](/home/Mw/.config/quickshell/components/SettingsButton.qml)
- [/home/Mw/.config/quickshell/components/SettingsChoice.qml](/home/Mw/.config/quickshell/components/SettingsChoice.qml)
- [/home/Mw/.config/quickshell/components/SettingsSwitch.qml](/home/Mw/.config/quickshell/components/SettingsSwitch.qml)
- [/home/Mw/.config/quickshell/components/SettingsThemeCard.qml](/home/Mw/.config/quickshell/components/SettingsThemeCard.qml)
- [/home/Mw/.config/quickshell/components/SettingsWindow.qml](/home/Mw/.config/quickshell/components/SettingsWindow.qml)
- [/home/Mw/.config/quickshell/components/ThemeLogo.qml](/home/Mw/.config/quickshell/components/ThemeLogo.qml)
- [/home/Mw/.config/quickshell/components/ThemedScrollBar.qml](/home/Mw/.config/quickshell/components/ThemedScrollBar.qml)
- [/home/Mw/.config/quickshell/components/ThemedToolTip.qml](/home/Mw/.config/quickshell/components/ThemedToolTip.qml)
- [/home/Mw/.config/quickshell/components/Wallpaper.qml](/home/Mw/.config/quickshell/components/Wallpaper.qml)
- [/home/Mw/.config/quickshell/core/Fallback.js](/home/Mw/.config/quickshell/core/Fallback.js)
- [/home/Mw/.config/quickshell/core/Theme.qml](/home/Mw/.config/quickshell/core/Theme.qml)
- [/home/Mw/.config/quickshell/panels/ConnectivityView.qml](/home/Mw/.config/quickshell/panels/ConnectivityView.qml)
- [/home/Mw/.config/quickshell/panels/InputPicker.qml](/home/Mw/.config/quickshell/panels/InputPicker.qml)
- [/home/Mw/.config/quickshell/panels/LauncherView.qml](/home/Mw/.config/quickshell/panels/LauncherView.qml)
- [/home/Mw/.config/quickshell/panels/NotificationCenter.qml](/home/Mw/.config/quickshell/panels/NotificationCenter.qml)
- [/home/Mw/.config/quickshell/panels/QuickSettings.qml](/home/Mw/.config/quickshell/panels/QuickSettings.qml)
- [/home/Mw/.config/quickshell/panels/SettingsConnectivity.qml](/home/Mw/.config/quickshell/panels/SettingsConnectivity.qml)
- [/home/Mw/.config/quickshell/panels/SettingsView.qml](/home/Mw/.config/quickshell/panels/SettingsView.qml)
- [/home/Mw/.config/quickshell/requirements-theme.lock](/home/Mw/.config/quickshell/requirements-theme.lock)
- [/home/Mw/.config/quickshell/requirements-theme.txt](/home/Mw/.config/quickshell/requirements-theme.txt)
- [/home/Mw/.config/quickshell/schemas/catalog.schema.json](/home/Mw/.config/quickshell/schemas/catalog.schema.json)
- [/home/Mw/.config/quickshell/schemas/material-export.schema.json](/home/Mw/.config/quickshell/schemas/material-export.schema.json)
- [/home/Mw/.config/quickshell/schemas/overrides.schema.json](/home/Mw/.config/quickshell/schemas/overrides.schema.json)
- [/home/Mw/.config/quickshell/schemas/pack.schema.json](/home/Mw/.config/quickshell/schemas/pack.schema.json)
- [/home/Mw/.config/quickshell/schemas/palette.schema.json](/home/Mw/.config/quickshell/schemas/palette.schema.json)
- [/home/Mw/.config/quickshell/schemas/selection.schema.json](/home/Mw/.config/quickshell/schemas/selection.schema.json)
- [/home/Mw/.config/quickshell/schemas/snapshot.schema.json](/home/Mw/.config/quickshell/schemas/snapshot.schema.json)
- [/home/Mw/.config/quickshell/schemas/sources.schema.json](/home/Mw/.config/quickshell/schemas/sources.schema.json)
- [/home/Mw/.config/quickshell/services/preferences.py](/home/Mw/.config/quickshell/services/preferences.py)
- [/home/Mw/.config/quickshell/services/themes.py](/home/Mw/.config/quickshell/services/themes.py)
- [/home/Mw/.config/quickshell/services/theming/__init__.py](/home/Mw/.config/quickshell/services/theming/__init__.py)
- [/home/Mw/.config/quickshell/services/theming/activation.py](/home/Mw/.config/quickshell/services/theming/activation.py)
- [/home/Mw/.config/quickshell/services/theming/catalog.py](/home/Mw/.config/quickshell/services/theming/catalog.py)
- [/home/Mw/.config/quickshell/services/theming/color.py](/home/Mw/.config/quickshell/services/theming/color.py)
- [/home/Mw/.config/quickshell/services/theming/migration.py](/home/Mw/.config/quickshell/services/theming/migration.py)
- [/home/Mw/.config/quickshell/services/theming/paths.py](/home/Mw/.config/quickshell/services/theming/paths.py)
- [/home/Mw/.config/quickshell/services/theming/providers.py](/home/Mw/.config/quickshell/services/theming/providers.py)
- [/home/Mw/.config/quickshell/services/theming/storage.py](/home/Mw/.config/quickshell/services/theming/storage.py)
- [/home/Mw/.config/quickshell/services/theming/validation.py](/home/Mw/.config/quickshell/services/theming/validation.py)
- [/home/Mw/.config/quickshell/services/theming/watch.py](/home/Mw/.config/quickshell/services/theming/watch.py)
- [/home/Mw/.config/quickshell/themes/eclipse/colors.json](/home/Mw/.config/quickshell/themes/eclipse/colors.json)
- [/home/Mw/.config/quickshell/themes/eclipse/theme.json](/home/Mw/.config/quickshell/themes/eclipse/theme.json)
- [/home/Mw/.config/quickshell/themes/wizarch/colors.json](/home/Mw/.config/quickshell/themes/wizarch/colors.json)
- [/home/Mw/.config/quickshell/themes/wizarch/theme.json](/home/Mw/.config/quickshell/themes/wizarch/theme.json)
- [/home/Mw/.config/hypr/hyprland.lua](/home/Mw/.config/hypr/hyprland.lua)
- [/home/Mw/.config/hypr/wizarch-theme.lua](/home/Mw/.config/hypr/wizarch-theme.lua)
- [/home/Mw/.config/hypr/wizarch-theme-geometry.lua](/home/Mw/.config/hypr/wizarch-theme-geometry.lua)
- [/home/Mw/.config/wizarch/theme-selection.json](/home/Mw/.config/wizarch/theme-selection.json)
- [/home/Mw/.config/quickshell/panels/ThemePicker.qml](/home/Mw/.config/quickshell/panels/ThemePicker.qml)

### Review-only installed targets and restore point

Only these eight source files were installed in this follow-up. [review-deployment.json](evidence/review-deployment.json) records original and resulting hashes; `/home/Mw/Documents/Codex/Wizarch/work/material-review-backup/manifest.json` preserves their exact before-fix bytes and current committed theme state. The earlier complete-migration backup is separate.

- [quickshell/services/theming/storage.py](/home/Mw/.config/quickshell/services/theming/storage.py)
- [quickshell/services/theming/color.py](/home/Mw/.config/quickshell/services/theming/color.py)
- [quickshell/services/theming/catalog.py](/home/Mw/.config/quickshell/services/theming/catalog.py)
- [quickshell/services/theming/providers.py](/home/Mw/.config/quickshell/services/theming/providers.py)
- [quickshell/services/theming/watch.py](/home/Mw/.config/quickshell/services/theming/watch.py)
- [quickshell/services/themes.py](/home/Mw/.config/quickshell/services/themes.py)
- [quickshell/core/Theme.qml](/home/Mw/.config/quickshell/core/Theme.qml)
- [quickshell/panels/SettingsView.qml](/home/Mw/.config/quickshell/panels/SettingsView.qml)
