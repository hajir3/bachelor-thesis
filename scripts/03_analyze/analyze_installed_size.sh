#!/usr/bin/env bash
# analyze_installed_size.sh — Aggregate installed sizes per release for minimal install packages
source "$(dirname "$0")/../lib/common.sh"

ensure_dir "$RESULTS_DIR"

PERSISTENT_CSV="$RESULTS_DIR/persistent_packages.csv"
OUT_CSV="$RESULTS_DIR/installed_sizes.csv"

echo "codename,year,minimal_install_kb,persistent_only_kb,num_minimal_packages,num_persistent_packages" > "$OUT_CSV"

while IFS=$'\t' read -r codename version year arch base_url has_sources; do
    [[ "$codename" =~ ^#.*$ || -z "$codename" ]] && continue

    local_csv="$DATA_DIR/parsed/${codename}_packages.csv"
    [[ -f "$local_csv" ]] || { log_warn "No parsed data for $codename"; continue; }

    # Minimal install = minbase package list
    minbase_list="$DATA_DIR/parsed/${codename}_minbase.txt"
    [[ -f "$minbase_list" ]] || { log_warn "No minbase list for $codename"; continue; }

    minimal_kb=$(awk -F',' -v listfile="$minbase_list" '
    BEGIN { while ((getline pkg < listfile) > 0) minbase[pkg] = 1 }
    NR == 1 { next }
    ($1 in minbase) && $6!="" { s+=$6 }
    END { print s+0 }
    ' "$local_csv")
    minimal_count=$(awk -F',' -v listfile="$minbase_list" '
    BEGIN { while ((getline pkg < listfile) > 0) minbase[pkg] = 1 }
    NR == 1 { next }
    $1 in minbase { c++ }
    END { print c+0 }
    ' "$local_csv")

    # Persistent packages (if list exists)
    persistent_kb=0
    persistent_count=0
    if [[ -f "$PERSISTENT_CSV" ]]; then
        while IFS=',' read -r src_pkg rest; do
            [[ "$src_pkg" == "source_package" ]] && continue
            kb=$(awk -F',' -v src="$src_pkg" -v listfile="$minbase_list" '
            BEGIN { while ((getline pkg < listfile) > 0) minbase[pkg] = 1 }
            NR == 1 { next }
            ($1 in minbase) && $2==src && $6!="" { s+=$6 }
            END { print s+0 }
            ' "$local_csv")
            if (( kb > 0 )); then
                persistent_kb=$((persistent_kb + kb))
                persistent_count=$((persistent_count + 1))
            fi
        done < "$PERSISTENT_CSV"
    fi

    echo "$codename,$year,$minimal_kb,$persistent_kb,$minimal_count,$persistent_count" >> "$OUT_CSV"
    log_info "$codename ($year): minimal=${minimal_kb}KB ($minimal_count pkgs), persistent=${persistent_kb}KB ($persistent_count pkgs)"
done < "$RELEASES_CONF"

log_info "Generated: $OUT_CSV"
