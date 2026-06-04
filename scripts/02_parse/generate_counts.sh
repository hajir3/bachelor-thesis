#!/usr/bin/env bash
# generate_counts.sh — Generate aggregate package_counts.csv using minbase lists
# Must run AFTER generate_minbase_lists.sh
source "$(dirname "$0")/../lib/common.sh"

ensure_dir "$RESULTS_DIR"

COUNTS_CSV="$RESULTS_DIR/package_counts.csv"
echo "codename,year,total_packages,minbase_count,minbase_installed_kb" > "$COUNTS_CSV"

while IFS=$'\t' read -r codename version year arch base_url has_sources; do
    [[ "$codename" =~ ^#.*$ || -z "$codename" ]] && continue
    csv="$DATA_DIR/parsed/${codename}_packages.csv"
    [[ -f "$csv" ]] || continue

    total=$(tail -n +2 "$csv" | wc -l | tr -d ' ')

    minbase_list="$DATA_DIR/parsed/${codename}_minbase.txt"
    [[ -f "$minbase_list" ]] || { log_warn "No minbase list for $codename"; continue; }

    minbase_count=$(awk -F',' -v listfile="$minbase_list" '
    BEGIN { while ((getline pkg < listfile) > 0) minbase[pkg] = 1 }
    NR == 1 { next }
    $1 in minbase { c++ }
    END { print c+0 }
    ' "$csv")
    minbase_kb=$(awk -F',' -v listfile="$minbase_list" '
    BEGIN { while ((getline pkg < listfile) > 0) minbase[pkg] = 1 }
    NR == 1 { next }
    ($1 in minbase) && $6!="" { s+=$6 }
    END { print s+0 }
    ' "$csv")

    echo "$codename,$year,$total,$minbase_count,$minbase_kb" >> "$COUNTS_CSV"
done < "$RELEASES_CONF"

log_info "Generated: $COUNTS_CSV"
