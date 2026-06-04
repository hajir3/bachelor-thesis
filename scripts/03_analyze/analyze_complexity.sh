#!/usr/bin/env bash
# analyze_complexity.sh — Compute cyclomatic complexity (pmccabe) for every
# persistent source package across all releases. Per-release aggregates feed
# `complexity.pdf` (avg/median) and `cc_distribution.pdf` (distribution).
# Also records, per (release, package), the single most complex function
# (file + name) in `complexity_max_functions.csv` so the webapp can name what
# drives each release's maximum CC.
source "$(dirname "$0")/../lib/common.sh"

ensure_dir "$RESULTS_DIR"

PERSISTENT_CSV="$RESULTS_DIR/persistent_packages.csv"
DETAIL_CSV="$RESULTS_DIR/complexity_detail.csv"
RELEASE_CSV="$RESULTS_DIR/complexity_by_release.csv"
FUNCTIONS_CSV="$RESULTS_DIR/complexity_functions.csv"
MAXFUNC_CSV="$RESULTS_DIR/complexity_max_functions.csv"
TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

if [[ ! -f "$PERSISTENT_CSV" ]]; then
    log_error "Missing $PERSISTENT_CSV — run find_persistent.sh first"
    exit 1
fi

echo "codename,year,source_package,num_functions,avg_cc,max_cc,sum_cc" > "$DETAIL_CSV"
echo "codename,year,total_functions,avg_cc,max_cc,median_cc" > "$RELEASE_CSV"
echo "codename,year,source_package,cc" > "$FUNCTIONS_CSV"
echo "codename,year,source_package,max_cc,file,func_line,function" > "$MAXFUNC_CSV"

while IFS=$'\t' read -r codename version year arch base_url has_sources; do
    [[ "$codename" =~ ^#.*$ || -z "$codename" ]] && continue
    [[ "$has_sources" == "yes" ]] || continue

    tarball_dir="$DATA_DIR/source_tarballs/$codename"
    [[ -d "$tarball_dir" ]] || { log_warn "No tarballs for $codename"; continue; }

    # Per-function CC values for this release — drives the release-level
    # avg/max/median that thesis figures consume.
    release_cc_file="$TMPDIR_WORK/release_cc_${codename}.txt"
    : > "$release_cc_file"

    while IFS=',' read -r src_pkg rest; do
        [[ "$src_pkg" == "source_package" || -z "$src_pkg" ]] && continue

        # Find the .orig.tar.* file (canonical name + historical aliases).
        orig_file=""
        for candidate in "$src_pkg" $(reverse_aliases "$src_pkg"); do
            found=$(find "$tarball_dir" -maxdepth 1 -name "${candidate}_*.orig.tar.*" ! -name "*.asc" 2>/dev/null | head -1)
            # Fall back to the single native tarball for Debian-native
            # packages (no .orig/.debian split, e.g. dpkg, debconf, hostname).
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
        extract_dir="$TMPDIR_WORK/cc_$$"
        mkdir -p "$extract_dir"

        log_info "  complexity: $codename / $src_pkg extracting"
        case "$orig_file" in
            *.tar.xz)  tar -xf "$orig_file" -C "$extract_dir" 2>/dev/null ;;
            *.tar.gz)  tar -xzf "$orig_file" -C "$extract_dir" 2>/dev/null ;;
            *.tar.bz2) tar -xjf "$orig_file" -C "$extract_dir" 2>/dev/null ;;
            *) log_warn "Unknown format: $orig_file"; rm -rf "$extract_dir"; continue ;;
        esac

        # Handle dfsg-repacked nested tarballs (mirrors analyze_tokei.sh).
        log_info "  complexity: $codename / $src_pkg unwrapping nested"
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
        # bundles the debian/ packaging directory; non-native packages keep
        # that in a separate .debian.tar this script never extracts. Strip the
        # source-root debian/ (maxdepth 2) for native packages only, so the
        # measurement matches non-native packages while leaving their numbers
        # untouched and preserving deeper upstream test fixtures named
        # "debian".
        if [[ "$is_native" == "1" ]]; then
            find "$extract_dir" -maxdepth 2 -type d -name debian -prune -exec rm -rf {} + 2>/dev/null || true
        fi

        # Run pmccabe over C/C++ sources in parallel. xargs -P $(nproc) fans
        # out across cores; -n 50 keeps each batch small so one slow file in
        # one worker doesn't stall the pool. stdbuf -oL forces line-buffered
        # stdout so each pmccabe line is one atomic write to cc_out —
        # concurrent workers interleave by line but never within a line
        # (write() of <PIPE_BUF bytes is atomic on Linux), so downstream awk
        # sees well-formed records. timeout stays as a safety net against a
        # genuinely stuck pmccabe.
        # Output columns: Modified_CC Traditional_CC Statements Lines_in_function Filename(Line): Function
        cc_out="$TMPDIR_WORK/cc_result.txt"
        : > "$cc_out"
        nproc_val=$(nproc 2>/dev/null || echo 4)
        log_info "  complexity: $codename / $src_pkg running pmccabe (-P $nproc_val)"
        if ! timeout 600 bash -c '
            find "$1" \( -name "*.c" -o -name "*.h" -o -name "*.cc" -o -name "*.cpp" -o -name "*.cxx" \) -print0 \
                | xargs -0 -P "$2" -n 50 stdbuf -oL pmccabe 2>/dev/null
        ' _ "$extract_dir" "$nproc_val" > "$cc_out"; then
            log_warn "  complexity: $codename / $src_pkg pmccabe timed out — skipping"
            rm -rf "$extract_dir" "$cc_out"
            continue
        fi

        log_info "  complexity: $codename / $src_pkg aggregating"
        if [[ -s "$cc_out" ]]; then
            stats=$(awk '
            {
                cc = $1 + 0
                if (cc > 0) {
                    sum += cc; n++
                    if (cc > max) max = cc
                }
            }
            END {
                if (n > 0) printf "%d,%.2f,%d,%d\n", n, sum/n, max, sum
                else print "0,0,0,0"
            }' "$cc_out")

            IFS=',' read -r nfunc avg max sumcc <<< "$stats"
            echo "$codename,$year,$src_pkg,$nfunc,$avg,$max,$sumcc" >> "$DETAIL_CSV"

            awk -v cn="$codename" -v yr="$year" -v pkg="$src_pkg" '
                { cc = $1 + 0; if (cc > 0) print cn "," yr "," pkg "," cc }
            ' "$cc_out" >> "$FUNCTIONS_CSV"

            awk '{print $1}' "$cc_out" >> "$release_cc_file"

            # Record this package's single most complex function (CC, file,
            # line, name). pmccabe's last field is "path/file.c(line): name";
            # the first five fields are numeric, so rejoining fields 6..NF
            # reconstructs the location regardless of tab/space separation.
            # Commas are stripped from file/name so the CSV row stays well
            # formed (C++ template names can contain them).
            maxfunc=$(awk -v root="$extract_dir/" '
                { cc = $1 + 0
                  if (cc > maxcc) {
                      maxcc = cc
                      loc = ""
                      for (i = 6; i <= NF; i++) loc = loc (i > 6 ? " " : "") $i
                      maxloc = loc
                  } }
                END {
                  if (maxcc > 0) {
                      fname = ""; fline = ""; file = maxloc
                      p = index(maxloc, "):")
                      if (p > 0) {
                          fname = substr(maxloc, p + 2); sub(/^[ \t]+/, "", fname)
                          head = substr(maxloc, 1, p)
                      } else head = maxloc
                      if (match(head, /\([0-9]+\)$/)) {
                          paren = substr(head, RSTART); file = substr(head, 1, RSTART - 1)
                          gsub(/[()]/, "", paren); fline = paren
                      } else file = head
                      # Drop the ephemeral extraction prefix so the stored path
                      # is relative to the source root (e.g. perl-5.10.0/toke.c).
                      if (index(file, root) == 1) file = substr(file, length(root) + 1)
                      gsub(/,/, " ", file); gsub(/,/, " ", fname)
                      printf "%d\t%s\t%s\t%s", maxcc, file, fline, fname
                  }
                }' "$cc_out")
            if [[ -n "$maxfunc" ]]; then
                IFS=$'\t' read -r mf_cc mf_file mf_line mf_func <<< "$maxfunc"
                echo "$codename,$year,$src_pkg,$mf_cc,$mf_file,$mf_line,$mf_func" >> "$MAXFUNC_CSV"
            fi
        fi

        rm -rf "$extract_dir" "$cc_out"
        log_info "  complexity: $codename / $src_pkg done"
    done < "$PERSISTENT_CSV"

    # Release-level aggregates over the persistent slice.
    if [[ -s "$release_cc_file" ]]; then
        release_stats=$(sort -n "$release_cc_file" | awk '
        {
            vals[NR] = $1 + 0
            sum += vals[NR]
            n++
            if (vals[NR] > max) max = vals[NR]
        }
        END {
            if (n > 0) {
                avg = sum / n
                if (n % 2 == 1) median = vals[int(n/2)+1]
                else median = (vals[n/2] + vals[n/2+1]) / 2.0
                printf "%d,%.2f,%d,%.1f\n", n, avg, max, median
            } else {
                print "0,0,0,0"
            }
        }')
        IFS=',' read -r total_func avg_cc max_cc median_cc <<< "$release_stats"
        echo "$codename,$year,$total_func,$avg_cc,$max_cc,$median_cc" >> "$RELEASE_CSV"
        log_info "$codename ($year): ${total_func} functions, avg CC=${avg_cc}, median CC=${median_cc}, max CC=${max_cc}"
    fi

    rm -f "$release_cc_file"
done < "$RELEASES_CONF"

log_info "Generated: $DETAIL_CSV"
log_info "Generated: $RELEASE_CSV"
log_info "Generated: $FUNCTIONS_CSV"
log_info "Generated: $MAXFUNC_CSV"
