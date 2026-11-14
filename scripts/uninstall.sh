#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
MANIFEST_OVERRIDE=""

usage() {
    cat <<'EOF'
Usage: scripts/uninstall.sh [OPTIONS]

Safely remove only files added by scripts/install.sh and restore backups
recorded in the installer manifest.

Options:
  -n, --dry-run         Preview every removal and restoration without modifying disk
  -m, --manifest PATH   Use a specific install backup manifest.tsv
  -h, --help            Show this help message and exit
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -n|--dry-run)
            DRY_RUN=1
            ;;
        -m|--manifest)
            if [ "$#" -lt 2 ]; then
                printf 'Option %s requires a file path\n' "$1" >&2
                exit 2
            fi
            shift
            MANIFEST_OVERRIDE="$1"
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
    printf 'Do not run uninstall.sh as root or with sudo; restore runs against your user config.\n' >&2
    exit 1
fi

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
BACKUP_ROOT="$STATE_HOME/wizarch/install-backups"
LATEST_FILE="$BACKUP_ROOT/latest"
MANIFEST="$MANIFEST_OVERRIDE"

if [ -z "$MANIFEST" ] && [ -f "$LATEST_FILE" ]; then
    MANIFEST="$(cat "$LATEST_FILE")"
fi

if [ -z "$MANIFEST" ] || [ ! -f "$MANIFEST" ]; then
    printf 'No Wizarch installer manifest found (%s).\n' "${MANIFEST:-$LATEST_FILE}" >&2
    printf 'Refusing to remove files blindly without an install record.\n' >&2
    exit 1
fi

BACKUP_DIR="$(cd -- "$(dirname -- "$MANIFEST")" && pwd -P)"

log() {
    printf '%s\n' "$*"
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

strip_wizarch_block() {
    local file_path="$1"
    local tmp_file=""
    tmp_file="$(mktemp)"
    awk '
        /^-- >>> wizarch-managed-start >>>$/ { skip = 1; next }
        /^-- <<< wizarch-managed-end <<<$/ { skip = 0; next }
        !skip { print }
    ' "$file_path" > "$tmp_file"
    # Trim trailing blank lines only if the block was appended at EOF
    mv -- "$tmp_file" "$file_path"
}

restore_entry() {
    local kind="$1"
    local target="$2"
    local backup_rel="$3"
    local backup_path="$BACKUP_DIR/$backup_rel"

    case "$kind" in
        dir)
            if [ ! -e "$backup_path" ]; then
                printf 'Missing backup directory for %s at %s; leaving target untouched.\n' "$target" "$backup_path" >&2
                return 0
            fi
            if [ "$DRY_RUN" -eq 1 ]; then
                dry_note "Would remove $target and restore backup $backup_path -> $target"
                return 0
            fi
            rm -rf -- "$target"
            mkdir -p -- "$(dirname -- "$target")"
            cp -a "$backup_path" "$target"
            log "Restored directory $target"
            ;;
        dir-new)
            if [ "$DRY_RUN" -eq 1 ]; then
                dry_note "Would remove installer-created directory $target"
                return 0
            fi
            rm -rf -- "$target"
            log "Removed $target"
            ;;
        file)
            if [ ! -e "$backup_path" ] && [ ! -L "$backup_path" ]; then
                printf 'Missing backup file for %s at %s; leaving target untouched.\n' "$target" "$backup_path" >&2
                return 0
            fi
            if [ "$DRY_RUN" -eq 1 ]; then
                dry_note "Would restore backup $backup_path -> $target"
                return 0
            fi
            mkdir -p -- "$(dirname -- "$target")"
            rm -rf -- "$target"
            cp -a "$backup_path" "$target"
            log "Restored file $target"
            ;;
        file-new)
            if [ -e "$target" ] || [ -L "$target" ]; then
                if [ "$DRY_RUN" -eq 1 ]; then
                    dry_note "Would remove installer-added file $target"
                else
                    rm -f -- "$target"
                    log "Removed $target"
                fi
            fi
            ;;
        hypr-block)
            if [ ! -f "$target" ]; then
                return 0
            fi
            if grep -q '^-- >>> wizarch-managed-start >>>$' "$target"; then
                if [ "$DRY_RUN" -eq 1 ]; then
                    dry_note "Would remove Wizarch loader block from $target"
                else
                    strip_wizarch_block "$target"
                    log "Removed Wizarch loader block from $target (preserving any other edits)"
                fi
            elif [ -f "$backup_path" ]; then
                if [ "$DRY_RUN" -eq 1 ]; then
                    dry_note "Would restore $target from $backup_path"
                else
                    cp -a "$backup_path" "$target"
                    log "Restored $target from backup"
                fi
            fi
            ;;
        *)
            printf 'Unknown manifest entry type: %s\n' "$kind" >&2
            ;;
    esac
}

main() {
    local entries_hypr=()
    local entries_bin=()
    local entries_qs=()
    local kind=""
    local target=""
    local backup_rel=""

    while IFS=$'\t' read -r kind target backup_rel; do
        [ -z "$kind" ] && continue
        if [ "$kind" = 'hypr-block' ] || [[ "$target" == */hypr/* ]]; then
            entries_hypr+=("$kind"$'\t'"$target"$'\t'"$backup_rel")
        elif [[ "$target" == */.local/bin/* ]]; then
            entries_bin+=("$kind"$'\t'"$target"$'\t'"$backup_rel")
        else
            entries_qs+=("$kind"$'\t'"$target"$'\t'"$backup_rel")
        fi
    done < "$MANIFEST"

    log "Using installer manifest: $MANIFEST"

    if [ "${#entries_hypr[@]}" -gt 0 ]; then
        log ''
        log '== Step 1: Revert Hyprland configuration additions and restore backups =='
        if confirm_step 'Remove Wizarch Hyprland fragments/loader block and restore backed-up Hyprland files?'; then
            local row=""
            for row in "${entries_hypr[@]}"; do
                IFS=$'\t' read -r kind target backup_rel <<<"$row"
                restore_entry "$kind" "$target" "$backup_rel"
            done
        else
            log 'Skipped Hyprland restoration.'
        fi
    fi

    if [ "${#entries_bin[@]}" -gt 0 ]; then
        log ''
        log '== Step 2: Remove Wizarch helper scripts and restore backups =='
        if confirm_step 'Remove Wizarch helper scripts from ~/.local/bin and restore any backed-up scripts?'; then
            local row=""
            for row in "${entries_bin[@]}"; do
                IFS=$'\t' read -r kind target backup_rel <<<"$row"
                restore_entry "$kind" "$target" "$backup_rel"
            done
        else
            log 'Skipped helper script restoration.'
        fi
    fi

    if [ "${#entries_qs[@]}" -gt 0 ]; then
        log ''
        log '== Step 3: Remove installed Quickshell files and restore backup =='
        if confirm_step 'Remove Wizarch Quickshell directory and restore any pre-existing Quickshell backup?'; then
            local row=""
            for row in "${entries_qs[@]}"; do
                IFS=$'\t' read -r kind target backup_rel <<<"$row"
                restore_entry "$kind" "$target" "$backup_rel"
            done
        else
            log 'Skipped Quickshell restoration.'
        fi
    fi

    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1; then
        log ''
        log '== Step 4: Reload live Hyprland session =='
        if confirm_step 'Reload Hyprland configuration now?'; then
            if [ "$DRY_RUN" -eq 1 ]; then
                dry_note 'Would run: hyprctl reload'
            else
                hyprctl reload || true
            fi
        fi
    fi

    log ''
    if confirm_step "Delete used backup snapshot directory \"$BACKUP_DIR\" now that restore is done?"; then
        if [ "$DRY_RUN" -eq 1 ]; then
            dry_note "Would remove backup snapshot $BACKUP_DIR"
        else
            rm -rf -- "$BACKUP_DIR"
            if [ -f "$LATEST_FILE" ] && [ "$(cat "$LATEST_FILE" 2>/dev/null || true)" = "$MANIFEST" ]; then
                rm -f -- "$LATEST_FILE"
            fi
            log "Removed backup snapshot $BACKUP_DIR"
        fi
    else
        log "Retained backup snapshot at $BACKUP_DIR"
    fi

    log ''
    if [ "$DRY_RUN" -eq 1 ]; then
        log 'Dry run complete. No files were modified.'
    else
        log 'Uninstall complete. Only Wizarch-installed items were reverted.'
    fi
}

main
