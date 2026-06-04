#!/usr/bin/env bash
# analyze_tokei.sh — Run tokei on source tarballs for every persistent source
# package across all releases. Per-package detail feeds `tokei_summary.csv`;
# per-release totals feed `tokei_by_release.csv` which drives `nloc.pdf`,
# `language_breakdown.pdf`, and `persistent_growth.pdf`.
source "$(dirname "$0")/../lib/common.sh"

ensure_dir "$RESULTS_DIR"

PERSISTENT_CSV="$RESULTS_DIR/persistent_packages.csv"
DETAIL_CSV="$RESULTS_DIR/tokei_summary.csv"
RELEASE_CSV="$RESULTS_DIR/tokei_by_release.csv"
TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

if [[ ! -f "$PERSISTENT_CSV" ]]; then
    log_error "Missing $PERSISTENT_CSV — run find_persistent.sh first"
    exit 1
fi

echo "codename,year,source_package,language,files,blank,comment,code" > "$DETAIL_CSV"
echo "codename,year,total_files,total_blank,total_comment,total_code,num_languages" > "$RELEASE_CSV"

while IFS=$'\t' read -r codename version year arch base_url has_sources; do
    [[ "$codename" =~ ^#.*$ || -z "$codename" ]] && continue
    [[ "$has_sources" == "yes" ]] || continue

    tarball_dir="$DATA_DIR/source_tarballs/$codename"
    [[ -d "$tarball_dir" ]] || { log_warn "No tarballs for $codename"; continue; }

    release_files=0
    release_blank=0
    release_comment=0
    release_code=0

    while IFS=',' read -r src_pkg rest; do
        [[ "$src_pkg" == "source_package" || -z "$src_pkg" ]] && continue

        # Find the .orig.tar.* file for this source package. Try the
        # canonical name first, then any historical alias mapping to it
        # (e.g. shellutils/fileutils/textutils -> coreutils, eglibc -> glibc).
        orig_file=""
        for candidate in "$src_pkg" $(reverse_aliases "$src_pkg"); do
            found=$(find "$tarball_dir" -maxdepth 1 -name "${candidate}_*.orig.tar.*" ! -name "*.asc" 2>/dev/null | head -1)
            # Fall back to the single native tarball for Debian-native
            # packages (no .orig/.debian split, e.g. dpkg, debconf, hostname).
            # Exclude .orig/.debian/.diff/.asc and multi-component .orig-* so
            # we pick the actual source tarball.
            if [[ -z "$found" ]]; then
                found=$(find "$tarball_dir" -maxdepth 1 -name "${candidate}_*.tar.*" \
                    ! -name "*.orig.tar.*" ! -name "*.orig-*" ! -name "*.debian.tar.*" \
                    ! -name "*.diff.*" ! -name "*.asc" 2>/dev/null | head -1)
            fi
            if [[ -n "$found" ]]; then
                orig_file="$found"
                break
            fi
        done

        if [[ -z "$orig_file" ]]; then
            continue
        fi

        # A native package was selected when the chosen tarball is not an
        # upstream .orig tarball (the native fallback fired). Used below to
        # decide whether to strip the bundled debian/ packaging directory.
        is_native=0
        [[ "$orig_file" != *.orig.tar.* ]] && is_native=1

        # Extract to temp dir
        extract_dir="$TMPDIR_WORK/tokei_$$"
        mkdir -p "$extract_dir"

        case "$orig_file" in
            *.tar.xz)  tar -xf "$orig_file" -C "$extract_dir" 2>/dev/null ;;
            *.tar.gz)  tar -xzf "$orig_file" -C "$extract_dir" 2>/dev/null ;;
            *.tar.bz2) tar -xjf "$orig_file" -C "$extract_dir" 2>/dev/null ;;
            *) log_warn "Unknown format: $orig_file"; rm -rf "$extract_dir"; continue ;;
        esac

        # Handle Debian's "dfsg-repacked" nested tarball layout (common in
        # the 2003-2013 era): some .orig.tar.* archives contain only a
        # wrapper directory and a single nested .tar.gz/.tar.xz/.tar.bz2
        # with the actual source. Extract any such nested tarball in place
        # so tokei finds real source files.
        while IFS= read -r nested; do
            nested_dir="$(dirname "$nested")"
            case "$nested" in
                *.tar.xz)  tar -xf  "$nested" -C "$nested_dir" 2>/dev/null || continue ;;
                *.tar.gz)  tar -xzf "$nested" -C "$nested_dir" 2>/dev/null || continue ;;
                *.tar.bz2) tar -xjf "$nested" -C "$nested_dir" 2>/dev/null || continue ;;
                *) continue ;;
            esac
            rm -f "$nested"
        done < <(find "$extract_dir" -maxdepth 3 -type f \( -name '*.tar.gz' -o -name '*.tar.xz' -o -name '*.tar.bz2' \))

        # Measure upstream code only. For native packages the single tarball
        # bundles the debian/ packaging directory (control, rules, changelog,
        # maintainer scripts); non-native packages keep that in a separate
        # .debian.tar this script never extracts. Strip the source-root
        # debian/ (maxdepth 2) for native packages only, so the measurement
        # is consistent with non-native packages while leaving their numbers
        # untouched. maxdepth 2 targets the packaging dir and preserves any
        # upstream test fixtures named "debian" that live deeper in the tree.
        if [[ "$is_native" == "1" ]]; then
            find "$extract_dir" -maxdepth 2 -type d -name debian -prune -exec rm -rf {} + 2>/dev/null || true
        fi

        # Run tokei with JSON output
        tokei_out="$TMPDIR_WORK/tokei_result.json"
        tokei --output json "$extract_dir" > "$tokei_out" 2>/dev/null || true

        if [[ -s "$tokei_out" ]]; then
            # Parse tokei JSON: each top-level key is a language with
            # .blanks, .code, .comments, .reports[]. Skip tokei's synthetic
            # "Total" pseudo-language entry to avoid double counting.
            jq -r --arg cn "$codename" --arg yr "$year" --arg pkg "$src_pkg" '
                to_entries[]
                | select(.key != "Total")
                | select(.value.code > 0)
                | [$cn, $yr, $pkg, .key,
                   (.value.reports | length),
                   .value.blanks,
                   .value.comments,
                   .value.code]
                | @csv
            ' "$tokei_out" | tr -d '"' >> "$DETAIL_CSV"

            # Per-release totals over the persistent slice.
            read -r pkg_files pkg_blank pkg_comment pkg_code < <(
                jq -r '
                    [to_entries[] | select(.key != "Total") | .value]
                    | {
                        files: (map(.reports | length) | add // 0),
                        blanks: (map(.blanks) | add // 0),
                        comments: (map(.comments) | add // 0),
                        code: (map(.code) | add // 0)
                      }
                    | "\(.files) \(.blanks) \(.comments) \(.code)"
                ' "$tokei_out"
            )
            release_files=$((release_files + ${pkg_files:-0}))
            release_blank=$((release_blank + ${pkg_blank:-0}))
            release_comment=$((release_comment + ${pkg_comment:-0}))
            release_code=$((release_code + ${pkg_code:-0}))
        fi

        rm -rf "$extract_dir" "$tokei_out"
        log_info "  tokei: $codename / $src_pkg done"
    done < "$PERSISTENT_CSV"

    # Count unique languages in this release.
    release_unique_langs=$(awk -F',' -v cn="$codename" '$1==cn {print $4}' "$DETAIL_CSV" | sort -u | wc -l | tr -d ' ')

    echo "$codename,$year,$release_files,$release_blank,$release_comment,$release_code,$release_unique_langs" >> "$RELEASE_CSV"
    log_info "$codename ($year): ${release_code} NLOC, ${release_files} files, ${release_unique_langs} languages"
done < "$RELEASES_CONF"

log_info "Generated: $DETAIL_CSV"
log_info "Generated: $RELEASE_CSV"
