#!/usr/bin/env bash
# download_sources_idx.sh — Download Sources.gz for all Debian releases that have it
source "$(dirname "$0")/../lib/common.sh"

download_release_sources() {
    local codename="$1" version="$2" year="$3" arch="$4" base_url="$5" has_sources="$6"

    if [[ "$has_sources" != "yes" ]]; then
        log_info "Skipping $codename — no Sources.gz available"
        return 0
    fi

    local url="${base_url}/dists/${codename}/main/source/Sources.gz"
    local dest_dir="$DATA_DIR/sources_idx/$codename"
    local dest_gz="$dest_dir/Sources.gz"

    download_if_missing "$url" "$dest_gz" || {
        log_warn "Skipping $codename — download failed"
        return 0
    }

    decompress_gz "$dest_gz"
    log_info "Ready: $dest_dir/Sources ($codename $version, $year)"
}

log_info "=== Downloading Sources.gz for all Debian releases ==="
for_each_release download_release_sources
log_info "=== Done ==="
