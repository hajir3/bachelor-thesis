#!/usr/bin/env bash
# download_packages.sh — Download Packages.gz for all Debian releases
source "$(dirname "$0")/../lib/common.sh"

download_release_packages() {
    local codename="$1" version="$2" year="$3" arch="$4" base_url="$5" has_sources="$6"

    local url="${base_url}/dists/${codename}/main/binary-${arch}/Packages.gz"
    local dest_dir="$DATA_DIR/packages/$codename"
    local dest_gz="$dest_dir/Packages.gz"

    download_if_missing "$url" "$dest_gz" || {
        log_warn "Skipping $codename — download failed"
        return 0
    }

    decompress_gz "$dest_gz"
    log_info "Ready: $dest_dir/Packages ($codename $version, $year)"
}

log_info "=== Downloading Packages.gz for all Debian releases ==="
for_each_release download_release_packages
log_info "=== Done ==="
