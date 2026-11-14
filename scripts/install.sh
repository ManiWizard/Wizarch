#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: scripts/install.sh [OPTIONS]

Safely install Wizarch into user XDG/local directories with interactive
step-by-step confirmation and timestamped backups.

Options:
  -n, --dry-run   Preview every check, backup, and file change without modifying disk
  -h, --help      Show this help message and exit
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -n|--dry-run)
            DRY_RUN=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    printf 'Do not run install.sh as root or with sudo; Wizarch installs into user config directories.\n' >&2
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

if [ ! -f "$REPO_ROOT/quickshell/shell.qml" ] || [ ! -f "$REPO_ROOT/examples/hyprland-wizarch.lua" ]; then
    printf 'Error: could not locate Wizarch repository files under %s\n' "$REPO_ROOT" >&2
    exit 1
fi

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
BIN_DIR="$HOME/.local/bin"

QS_TARGET="$CONFIG_HOME/quickshell"
HYPR_DIR="$CONFIG_HOME/hypr"
HYPR_MAIN="$HYPR_DIR/hyprland.lua"
BACKUP_ROOT="$STATE_HOME/wizarch/install-backups"
STAMP="$(date +%Y%m%d-%H%M%S)-$$"
BACKUP_DIR="$BACKUP_ROOT/$STAMP"
MANIFEST="$BACKUP_DIR/manifest.tsv"
LATEST_FILE="$BACKUP_ROOT/latest"
MANIFEST_READY=0

log() {
    printf '%s\n' "$*"
}

warn() {
    printf 'Warning: %s\n' "$*" >&2
}

dry_note() {
    printf '[dry-run] %s\n' "$*"
}

confirm_step() {
    local prompt="$1"
    local reply=""
    if [ "$DRY_RUN" -eq 1 ]; then
        dry_note "Would ask: $prompt [y/N] (continuing preview)"
        return 0
    fi
    if ! IFS= read -r -p "$prompt [y/N]: " reply; then
        printf '\nInput closed; skipping step.\n'
        return 1
    fi
    case "$reply" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

init_manifest() {
    if [ "$DRY_RUN" -eq 1 ]; then
        dry_note "Would initialize backup directory $BACKUP_DIR"
        return 0
    fi
    if [ "$MANIFEST_READY" -eq 0 ]; then
        mkdir -p "$BACKUP_DIR"
        : > "$MANIFEST"
        printf '%s\n' "$MANIFEST" > "$LATEST_FILE"
        MANIFEST_READY=1
    fi
}

record_entry() {
    local kind="$1"
    local target="$2"
    local backup_rel="$3"
    if [ "$DRY_RUN" -eq 1 ]; then
        return 0
    fi
    init_manifest
    printf '%s\t%s\t%s\n' "$kind" "$target" "$backup_rel" >> "$MANIFEST"
}

backup_existing_path() {
    local target="$1"
    local rel="$2"
    local dest="$BACKUP_DIR/$rel"
    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
        return 1
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        dry_note "Would back up existing $target -> $dest"
        return 0
    fi
    init_manifest
    mkdir -p "$(dirname -- "$dest")"
    rm -rf -- "$dest"
    cp -a "$target" "$dest"
    return 0
}

find_theme_python() {
    if [ -n "${WIZARCH_THEME_PYTHON:-}" ] && [ -x "$WIZARCH_THEME_PYTHON" ]; then
        printf '%s\n' "$WIZARCH_THEME_PYTHON"
        return 0
    fi
    if [ -x "$DATA_HOME/wizarch/theme-runtime/bin/python" ]; then
        printf '%s\n' "$DATA_HOME/wizarch/theme-runtime/bin/python"
        return 0
    fi
    command -v python3 2>/dev/null || return 1
}

check_dependencies() {
    log '== Step 1: Checking dependencies =='
    local missing_core=()
    local missing_optional=()
    local cmd=""

    for cmd in hyprctl qs python3 kitty wpctl upower wl-copy cliphist; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_core+=("$cmd")
        fi
    done

    for cmd in hyprlock grim slurp satty nmcli rfkill powerprofilesctl wf-recorder gsettings; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_optional+=("$cmd")
        fi
    done

    if [ "${#missing_core[@]}" -eq 0 ]; then
        log 'All core runtime commands found.'
    else
        warn "Missing core commands: ${missing_core[*]}"
        log 'Install core Arch packages manually before starting the shell:'
        log '  sudo pacman -S --needed git hyprland quickshell python util-linux kitty pipewire wireplumber upower wl-clipboard cliphist'
    fi

    if [ "${#missing_optional[@]}" -eq 0 ]; then
        log 'All optional desktop/screenshot commands found.'
    else
        log "Optional commands not found (corresponding controls stay disabled/unavailable): ${missing_optional[*]}"
        log 'Optional packages for lock, screenshots, Wi-Fi, power profiles, and recording:'
        log '  sudo pacman -S --needed hyprlock grim slurp satty networkmanager power-profiles-daemon wf-recorder glib2'
    fi

    local theme_py=""
    if theme_py="$(find_theme_python)" && "$theme_py" -c 'import PIL, jsonschema' >/dev/null 2>&1; then
        log "Theme validation dependencies ready in: $theme_py"
    else
        log 'Note: Pillow / jsonschema were not detected for the active Python interpreter.'
        log "Without them, Wizarch still starts with its built-in fallback palette; to enable full Material themes, create \"$DATA_HOME/wizarch/theme-runtime\" with quickshell/requirements-theme.lock."
    fi

    if [ "${#missing_core[@]}" -gt 0 ]; then
        if ! confirm_step 'Continue installation despite missing core commands?'; then
            log 'Aborted cleanly before making any file changes.'
            exit 0
        fi
    fi
}

install_quickshell() {
    log ''
    log '== Step 2: Back up and install Quickshell files =='
    if ! confirm_step "Back up any existing \"$QS_TARGET\" and install Wizarch Quickshell files?"; then
        log 'Skipped Quickshell installation.'
        return 0
    fi

    if backup_existing_path "$QS_TARGET" 'quickshell'; then
        record_entry 'dir' "$QS_TARGET" 'quickshell'
        [ "$DRY_RUN" -eq 0 ] && log "Backed up existing $QS_TARGET"
    else
        record_entry 'dir-new' "$QS_TARGET" '-'
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        dry_note "Would install $REPO_ROOT/quickshell -> $QS_TARGET"
        return 0
    fi

    mkdir -p "$CONFIG_HOME"
    rm -rf -- "$QS_TARGET"
    cp -a "$REPO_ROOT/quickshell" "$QS_TARGET"
    log "Installed Quickshell files to $QS_TARGET"
}

install_bin_scripts() {
    log ''
    log '== Step 3: Install helper scripts =='
    if ! confirm_step "Install wizarch-open, hypr-desktop, and hypr-screenshot into \"$BIN_DIR\"?"; then
        log 'Skipped helper script installation.'
        return 0
    fi

    local script=""
    local target=""
    for script in wizarch-open hypr-desktop hypr-screenshot; do
        target="$BIN_DIR/$script"
        if backup_existing_path "$target" "bin/$script"; then
            record_entry 'file' "$target" "bin/$script"
            [ "$DRY_RUN" -eq 0 ] && log "Backed up existing $target"
        else
            record_entry 'file-new' "$target" '-'
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            dry_note "Would install -Dm755 $REPO_ROOT/scripts/$script -> $target"
        else
            install -Dm755 "$REPO_ROOT/scripts/$script" "$target"
            log "Installed $target"
        fi
    done
}

install_hyprland_files() {
    log ''
    log '== Step 4: Back up and install Hyprland Lua fragments and hyprlock.conf =='
    if ! confirm_step "Install wizarch-bindings.lua, wizarch-windows.lua, and hyprlock.conf into \"$HYPR_DIR\"?"; then
        log 'Skipped Hyprland fragment installation.'
        return 0
    fi

    local pairs=(
        "examples/hyprland-wizarch.lua:wizarch-bindings.lua"
        "examples/wizarch-windows.lua:wizarch-windows.lua"
        "examples/hyprlock.conf:hyprlock.conf"
    )
    local pair=""
    local src=""
    local dst_name=""
    local dst=""

    for pair in "${pairs[@]}"; do
        src="$REPO_ROOT/${pair%%:*}"
        dst_name="${pair#*:}"
        dst="$HYPR_DIR/$dst_name"
        if backup_existing_path "$dst" "hypr/$dst_name"; then
            record_entry 'file' "$dst" "hypr/$dst_name"
            [ "$DRY_RUN" -eq 0 ] && log "Backed up existing $dst"
        else
            record_entry 'file-new' "$dst" '-'
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            dry_note "Would install -Dm644 $src -> $dst"
        else
            install -Dm644 "$src" "$dst"
            log "Installed $dst"
        fi
    done

    # Record generated Hyprland Lua fragments so uninstall only touches what didn't pre-exist
    local gen_name=""
    local gen_path=""
    for gen_name in wizarch-theme.lua wizarch-spacing.lua wizarch-workspaces.lua wizarch-layouts.lua; do
        gen_path="$HYPR_DIR/$gen_name"
        if backup_existing_path "$gen_path" "hypr/$gen_name"; then
            record_entry 'file' "$gen_path" "hypr/$gen_name"
        else
            record_entry 'file-new' "$gen_path" '-'
        fi
    done

    if [ -f "$HYPR_MAIN" ]; then
        if grep -q 'wizarch-bindings\.lua' "$HYPR_MAIN"; then
            log "$HYPR_MAIN already references wizarch-bindings.lua; leaving it untouched."
        elif confirm_step "Back up \"$HYPR_MAIN\" and append the Wizarch loader block?"; then
            if backup_existing_path "$HYPR_MAIN" 'hypr/hyprland.lua'; then
                record_entry 'hypr-block' "$HYPR_MAIN" 'hypr/hyprland.lua'
            fi
            if [ "$DRY_RUN" -eq 1 ]; then
                dry_note "Would append guarded wizarch-bindings.lua dofile block to $HYPR_MAIN"
            else
                if [ -s "$HYPR_MAIN" ] && [ -n "$(tail -c 1 "$HYPR_MAIN")" ]; then
                    printf '\n' >> "$HYPR_MAIN"
                fi
                cat >> "$HYPR_MAIN" <<'EOF'
-- >>> wizarch-managed-start >>>
do
    local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
    local bindings = config_home .. "/hypr/wizarch-bindings.lua"
    local file = io.open(bindings, "r")
    if file then file:close(); dofile(bindings) end
end
-- <<< wizarch-managed-end <<<
EOF
                log "Updated $HYPR_MAIN with guarded Wizarch loader block."
            fi
        else
            log "Skipped modifying $HYPR_MAIN. Load \"$HYPR_DIR/wizarch-bindings.lua\" manually when ready."
        fi
    else
        log "Note: $HYPR_MAIN does not exist yet. Create a Hyprland Lua config and add:"
        log '  dofile((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/wizarch-bindings.lua")'
    fi
}

initialize_theme() {
    log ''
    log '== Step 5: Initialize default Wizarch theme state =='
    local themes_script="$QS_TARGET/services/themes.py"
    if [ "$DRY_RUN" -eq 0 ] && [ ! -f "$themes_script" ]; then
        log 'Skipping theme init because Quickshell files are not installed yet.'
        return 0
    fi
    if ! confirm_step 'Initialize default Wizarch theme state offline (themes.py init wizarch)?'; then
        log 'Skipped theme initialization.'
        return 0
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        dry_note "Would run: themes.py init wizarch (creates state under $STATE_HOME/wizarch/theme and $HYPR_DIR/wizarch-theme.lua)"
        return 0
    fi

    local theme_py=""
    local theme_state_dir="$STATE_HOME/wizarch/theme"
    local theme_sel_file="$CONFIG_HOME/wizarch/theme-selection.json"
    if backup_existing_path "$theme_state_dir" 'state/theme'; then
        record_entry 'dir' "$theme_state_dir" 'state/theme'
    else
        record_entry 'dir-new' "$theme_state_dir" '-'
    fi
    if backup_existing_path "$theme_sel_file" 'wizarch/theme-selection.json'; then
        record_entry 'file' "$theme_sel_file" 'wizarch/theme-selection.json'
    else
        record_entry 'file-new' "$theme_sel_file" '-'
    fi
    if theme_py="$(find_theme_python)" && "$theme_py" "$themes_script" init wizarch; then
        log 'Initialized Wizarch theme snapshot and Hyprland theme colors.'
    else
        warn 'Could not initialize theme snapshot cleanly (missing Pillow/jsonschema or theme runtime).'
        log 'Wizarch will fall back cleanly on startup; see docs/material-theme/AUTHORING.md to set up theme-runtime.'
    fi
}

reload_live_session() {
    log ''
    log '== Step 6: Live Hyprland / Quickshell reload =='
    if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        log 'No active Hyprland session detected (HYPRLAND_INSTANCE_SIGNATURE is unset); skipping live reload.'
        return 0
    fi
    if ! command -v hyprctl >/dev/null 2>&1 || ! command -v qs >/dev/null 2>&1; then
        log 'hyprctl or qs is unavailable; skipping live reload.'
        return 0
    fi
    if ! confirm_step 'Reload Hyprland configuration and start Quickshell now?'; then
        log 'Skipped live reload.'
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        dry_note 'Would run: hyprctl reload && qs --no-duplicate --daemonize'
        return 0
    fi
    hyprctl reload
    qs --no-duplicate --daemonize
    log 'Reloaded Hyprland and started Quickshell.'
}

main() {
    if [ -f "$LATEST_FILE" ]; then
        local previous_manifest=""
        previous_manifest="$(cat "$LATEST_FILE" 2>/dev/null || true)"
        if [ -n "$previous_manifest" ] && [ -f "$previous_manifest" ]; then
            warn "Existing Wizarch backup manifest found at $previous_manifest."
            log 'Continuing creates a new timestamped backup snapshot; run scripts/uninstall.sh first if you want to restore your earlier backup.'
        fi
    fi

    check_dependencies
    install_quickshell
    install_bin_scripts
    install_hyprland_files
    initialize_theme
    reload_live_session

    log ''
    if [ "$DRY_RUN" -eq 1 ]; then
        log 'Dry run complete. No files were modified.'
    elif [ "$MANIFEST_READY" -eq 1 ]; then
        log "Installation complete. Backup manifest saved at: $MANIFEST"
        log 'To revert only what Wizarch installed and restore backups, run: bash scripts/uninstall.sh'
    else
        log 'No changes were applied.'
    fi
}

main
