#!/usr/bin/env bash
# generate_minbase_lists.sh — Generate minimal installation package lists per release
#
# Uses debootstrap --print-debs to resolve the true minimal package set via
# dependency resolution. Tries --variant=minbase first; falls back to no variant
# for older debootstrap scripts (potato/woody/sarge) that don't support it.
#
# Output: output/data/parsed/{codename}_minbase.txt (one binary package name per line, sorted)
source "$(dirname "$0")/../lib/common.sh"

ensure_dir "$DATA_DIR/parsed"

# Use debootstrap --print-debs to get the true minbase package set
generate_from_debootstrap() {
    local codename="$1"
    local arch="$2"
    local base_url="$3"
    local out="$DATA_DIR/parsed/${codename}_minbase.txt"
    local tmpdir

    log_info "$codename: running debootstrap --print-debs (arch=$arch)..."

    tmpdir=$(mktemp -d)

    # Use --no-check-gpg for archived releases (keys may not be in current keyring)
    # Try --variant=minbase first; fall back to no variant for older scripts that don't support it
    local debs
    if ! debs=$(debootstrap --print-debs --variant=minbase --arch="$arch" \
                --no-check-gpg "$codename" "$tmpdir/target" "$base_url" 2>&1); then
        # Retry without --variant for older debootstrap scripts (potato/woody/sarge)
        rm -rf "$tmpdir"; tmpdir=$(mktemp -d)
        if ! debs=$(debootstrap --print-debs --arch="$arch" \
                    --no-check-gpg "$codename" "$tmpdir/target" "$base_url" 2>&1); then
            log_error "$codename: debootstrap failed"
            log_error "debootstrap output: $(echo "$debs" | tail -3)"
            rm -rf "$tmpdir"
            return 1
        fi
    fi

    rm -rf "$tmpdir"

    # debootstrap --print-debs outputs one package per line; filter out log/info lines
    # Valid package names: lowercase alphanumeric, hyphens, dots, plus signs
    echo "$debs" | grep -E '^[a-z0-9][a-z0-9.+\-]*$' | sort -u > "$out"

    local count
    count=$(wc -l < "$out" | tr -d ' ')
    if (( count == 0 )); then
        log_error "$codename: debootstrap returned empty list"
        rm -f "$out"
        return 1
    fi
    log_info "$codename: $count packages (from debootstrap)"
}

# Main
log_info "=== Generating minbase package lists ==="

generate_release() {
    local codename="$1"
    local version="$2"
    local year="$3"
    local arch="$4"
    local base_url="$5"
    local has_sources="$6"

    local out="$DATA_DIR/parsed/${codename}_minbase.txt"

    if [[ -f "$out" ]]; then
        local count
        count=$(wc -l < "$out" | tr -d ' ')
        log_info "Already generated: $out ($count packages)"
        return 0
    fi

    generate_from_debootstrap "$codename" "$arch" "$base_url"
}

for_each_release generate_release

log_info "=== Done ==="
