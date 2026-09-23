# Wizarch

Project workspace copied from quickshell-astra-redesign.

- `quickshell/`: current installed Wizarch source, including flat surfaces and synchronized workspace support.
- `work/`: development files and earlier iterations; these are intentionally local and excluded from the public source repository.
- `outputs/`: deliverables, screenshots, and backups; these are intentionally local and excluded from the public source repository.

The live configuration is `~/.config/quickshell`; compare it with `quickshell/` before making changes. The shell uses Hyprland's Lua configuration at `~/.config/hypr/hyprland.lua`.

## Themes and assets

Wizarch includes its project-created logo and wallpaper exports. Eclipse's grayscale theme metadata is included, but its Berserk wallpaper is third-party artwork and is not redistributed here. To use Eclipse, provide your own image at `quickshell/themes/eclipse/assets/wallpaper.jpg` and ensure the theme's local asset path points to it.

`quickshell/state/active.json` is generated per-user runtime state and is excluded from version control. Theme state is created by the theme service when the shell runs.

## Public source

The public repository should contain the root README and `quickshell/` source only. Development environments, older prototypes, screenshots, backups, generated state, and third-party artwork remain local.
