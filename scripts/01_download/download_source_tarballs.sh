#!/usr/bin/env bash
# download_source_tarballs.sh — Download .orig.tar.* and .debian.tar.* for
# every persistent source package across all releases that publish Sources
# indices. Reads the work list from $RESULTS_DIR/persistent_packages.csv.
source "$(dirname "$0")/../lib/common.sh"

PERSISTENT_CSV="$RESULTS_DIR/persistent_packages.csv"

if [[ ! -f "$PERSISTENT_CSV" ]]; then
    log_error "Missing $PERSISTENT_CSV — run find_persistent.sh first"
    exit 1
fi

# Optional dry-run mode
DRY_RUN="${DRY_RUN:-0}"
total_size=0
download_count=0

while IFS=$'\t' read -r codename version year arch base_url has_sources; do
    [[ "$codename" =~ ^#.*$ || -z "$codename" ]] && continue
    [[ "$has_sources" == "yes" ]] || continue

    sources_csv="$DATA_DIR/parsed/${codename}_sources.csv"
    if [[ ! -f "$sources_csv" ]]; then
        log_warn "No parsed Sources CSV for $codename, skipping"
        continue
    fi

    dest_dir="$DATA_DIR/source_tarballs/$codename"
    ensure_dir "$dest_dir"

    n_pkgs=$(awk -F',' 'NR>1 {print $1}' "$PERSISTENT_CSV" | sort -u | grep -c . || true)
    log_info "=== $codename: ${n_pkgs} persistent source packages ==="

    while IFS=',' read -r src_pkg rest; do
        [[ "$src_pkg" == "source_package" || -z "$src_pkg" ]] && continue

        # Look up the package in the parsed Sources CSV. Try the canonical
        # name first, then any historical alias that maps to this canonical
        # (so looking up "glibc" in squeeze/wheezy falls through to the
        # actual source package "eglibc").
        # CSV: source_package,version,directory,orig_file,orig_size,debian_file,debian_size,native_file,native_size
        match=""
        for candidate in "$src_pkg" $(reverse_aliases "$src_pkg"); do
            match=$(awk -F',' -v pkg="$candidate" '$1==pkg {print; exit}' "$sources_csv")
            [[ -n "$match" ]] && break
        done
        [[ -z "$match" ]] && { log_warn "$codename: no Sources entry for $src_pkg"; continue; }

        IFS=',' read -r _pkg _ver directory orig_file orig_size debian_file debian_size native_file native_size <<< "$match"

        # Download .orig.tar.*
        if [[ -n "$orig_file" && "$orig_file" != "" ]]; then
            if [[ "$DRY_RUN" == "1" ]]; then
                total_size=$((total_size + ${orig_size:-0}))
                download_count=$((download_count + 1))
            else
                download_if_missing "${base_url}/${directory}/${orig_file}" "$dest_dir/$orig_file" || true
            fi
        fi

        # Download .debian.tar.* or .diff.gz
        if [[ -n "$debian_file" && "$debian_file" != "" ]]; then
            if [[ "$DRY_RUN" == "1" ]]; then
                total_size=$((total_size + ${debian_size:-0}))
                download_count=$((download_count + 1))
            else
                download_if_missing "${base_url}/${directory}/${debian_file}" "$dest_dir/$debian_file" || true
            fi
        fi

        # Download the single native tarball for Debian-native packages, which
        # have no .orig/.debian split (e.g. dpkg, debconf, hostname). Without
        # this the NLOC/complexity analyzers find no source and skip the
        # package entirely.
        if [[ -n "$native_file" && "$native_file" != "" ]]; then
            if [[ "$DRY_RUN" == "1" ]]; then
                total_size=$((total_size + ${native_size:-0}))
                download_count=$((download_count + 1))
            else
                download_if_missing "${base_url}/${directory}/${native_file}" "$dest_dir/$native_file" || true
            fi
        fi
    done < "$PERSISTENT_CSV"

    log_info "Processed: $codename"
done < "$RELEASES_CONF"

if [[ "$DRY_RUN" == "1" ]]; then
    total_mb=$((total_size / 1024 / 1024))
    log_info "=== DRY RUN: Would download $download_count files, estimated ${total_mb} MB ==="
fi
log_info "=== Done ==="
