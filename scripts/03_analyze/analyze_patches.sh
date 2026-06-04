#!/usr/bin/env bash
# analyze_patches.sh — Measure Debian patch sizes for every persistent source
# package across all releases. Per-package detail feeds the webapp / package
# explorer; release-level summary feeds `patch_size.pdf`.
source "$(dirname "$0")/../lib/common.sh"

ensure_dir "$RESULTS_DIR"

PERSISTENT_CSV="$RESULTS_DIR/persistent_packages.csv"
DETAIL_CSV="$RESULTS_DIR/patch_sizes.csv"
SUMMARY_CSV="$RESULTS_DIR/patch_summary.csv"
TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

if [[ ! -f "$PERSISTENT_CSV" ]]; then
    log_error "Missing $PERSISTENT_CSV — run find_persistent.sh first"
    exit 1
fi

echo "codename,year,source_package,debian_archive_bytes,patch_lines,num_patch_files" > "$DETAIL_CSV"
echo "codename,year,total_debian_bytes,total_patch_lines,avg_patch_lines_per_package,num_packages_with_patches" > "$SUMMARY_CSV"

while IFS=$'\t' read -r codename version year arch base_url has_sources; do
    [[ "$codename" =~ ^#.*$ || -z "$codename" ]] && continue
    [[ "$has_sources" == "yes" ]] || continue

    tarball_dir="$DATA_DIR/source_tarballs/$codename"
    [[ -d "$tarball_dir" ]] || { log_warn "No tarballs for $codename"; continue; }

    total_deb_bytes=0
    total_patch_lines=0
    pkg_with_patches=0

    while IFS=',' read -r src_pkg rest; do
        [[ "$src_pkg" == "source_package" || -z "$src_pkg" ]] && continue

        deb_bytes=0
        patch_lines=0
        num_patch_files=0

        # Try canonical name first then any historical alias.
        deb_file=""
        for candidate in "$src_pkg" $(reverse_aliases "$src_pkg"); do
            for ext in debian.tar.xz debian.tar.gz debian.tar.bz2 diff.gz; do
                found=$(find "$tarball_dir" -maxdepth 1 -name "${candidate}_*.${ext}" 2>/dev/null | head -1)
                if [[ -n "$found" ]]; then
                    deb_file="$found"
                    break 2
                fi
            done
        done

        if [[ -z "$deb_file" ]]; then
            echo "$codename,$year,$src_pkg,0,0,0" >> "$DETAIL_CSV"
            continue
        fi

        deb_bytes=$(stat -f%z "$deb_file" 2>/dev/null || stat --printf="%s" "$deb_file" 2>/dev/null || echo 0)

        extract_dir="$TMPDIR_WORK/extract_$$"
        mkdir -p "$extract_dir"

        if [[ "$deb_file" == *.diff.gz ]]; then
            patch_lines=$(gunzip -c "$deb_file" | wc -l | tr -d ' ')
            num_patch_files=1
        elif [[ "$deb_file" == *.tar.xz ]]; then
            tar -xf "$deb_file" -C "$extract_dir" 2>/dev/null || true
        elif [[ "$deb_file" == *.tar.gz ]]; then
            tar -xzf "$deb_file" -C "$extract_dir" 2>/dev/null || true
        elif [[ "$deb_file" == *.tar.bz2 ]]; then
            tar -xjf "$deb_file" -C "$extract_dir" 2>/dev/null || true
        fi

        if [[ "$deb_file" != *.diff.gz ]] && [[ -d "$extract_dir/debian/patches" ]]; then
            num_patch_files=$(find "$extract_dir/debian/patches" -name "*.patch" -o -name "*.diff" 2>/dev/null | wc -l | tr -d ' ')
            patch_lines=$(find "$extract_dir/debian/patches" \( -name "*.patch" -o -name "*.diff" \) -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
        fi

        rm -rf "$extract_dir"

        echo "$codename,$year,$src_pkg,$deb_bytes,$patch_lines,$num_patch_files" >> "$DETAIL_CSV"

        total_deb_bytes=$((total_deb_bytes + deb_bytes))
        total_patch_lines=$((total_patch_lines + patch_lines))
        if (( patch_lines > 0 )); then
            pkg_with_patches=$((pkg_with_patches + 1))
        fi
    done < "$PERSISTENT_CSV"

    avg_lines=0
    if (( pkg_with_patches > 0 )); then
        avg_lines=$((total_patch_lines / pkg_with_patches))
    fi

    echo "$codename,$year,$total_deb_bytes,$total_patch_lines,$avg_lines,$pkg_with_patches" >> "$SUMMARY_CSV"
    log_info "$codename ($year): ${total_patch_lines} patch lines across ${pkg_with_patches} packages"
done < "$RELEASES_CONF"

log_info "Generated: $DETAIL_CSV"
log_info "Generated: $SUMMARY_CSV"
