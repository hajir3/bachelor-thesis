#!/usr/bin/env bash
# find_persistent.sh — Identify source packages present in a threshold of releases
# Usage: find_persistent.sh [threshold_percent]
# Default threshold: 80 (= present in >=80% of releases)
source "$(dirname "$0")/../lib/common.sh"

ensure_dir "$RESULTS_DIR"

THRESHOLD_PCT="${1:-80}"
OUT_CSV="$RESULTS_DIR/persistent_packages.csv"
TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

log_info "=== Finding persistent packages (threshold: ${THRESHOLD_PCT}%) ==="

# Count total releases
total_releases=0
while IFS=$'\t' read -r codename version year arch base_url has_sources; do
    [[ "$codename" =~ ^#.*$ || -z "$codename" ]] && continue
    total_releases=$((total_releases + 1))
done < "$RELEASES_CONF"

threshold_count=$(( (total_releases * THRESHOLD_PCT + 99) / 100 ))
log_info "Total releases: $total_releases, threshold count: >= $threshold_count"

# For each release, extract source package names from minbase package list
while IFS=$'\t' read -r codename version year arch base_url has_sources; do
    [[ "$codename" =~ ^#.*$ || -z "$codename" ]] && continue

    local_csv="$DATA_DIR/parsed/${codename}_packages.csv"
    minbase_list="$DATA_DIR/parsed/${codename}_minbase.txt"
    [[ -f "$local_csv" ]] || continue

    [[ -f "$minbase_list" ]] || { log_warn "$codename: no minbase list, skipping"; continue; }

    # Map binary package names from minbase list to source package names via parsed CSV
    awk -F',' -v listfile="$minbase_list" '
    BEGIN {
        while ((getline pkg < listfile) > 0) minbase[pkg] = 1
    }
    NR == 1 { next }
    $1 in minbase { print $2 }
    ' "$local_csv" | sort -u | while read -r src_pkg; do
        resolved=$(resolve_alias "$src_pkg")
        echo "$resolved"
    done | sort -u > "$TMPDIR_WORK/${codename}.txt"

    count=$(wc -l < "$TMPDIR_WORK/${codename}.txt" | tr -d ' ')
    log_info "$codename: $count source packages (minbase)"
done < "$RELEASES_CONF"

# Count how many releases each source package appears in
cat "$TMPDIR_WORK"/*.txt | sort | uniq -c | sort -rn > "$TMPDIR_WORK/counts.txt"

# Filter by threshold and generate output
echo "source_package,present_in_releases,total_releases,presence_pct" > "$OUT_CSV"

while read -r count pkg; do
    if (( count >= threshold_count )); then
        pct=$(( (count * 100) / total_releases ))
        echo "$pkg,$count,$total_releases,$pct" >> "$OUT_CSV"
    fi
done < "$TMPDIR_WORK/counts.txt"

persistent_count=$(tail -n +2 "$OUT_CSV" | wc -l | tr -d ' ')
log_info "Found $persistent_count persistent source packages (>= ${THRESHOLD_PCT}% presence)"
log_info "Generated: $OUT_CSV"
