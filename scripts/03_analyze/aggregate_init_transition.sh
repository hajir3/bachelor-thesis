#!/usr/bin/env bash
# aggregate_init_transition.sh — Decompose wheezy/jessie/stretch minbase into
# four set-based categories illustrating the systemd transition:
#   persistent  — in wheezy ∩ stretch (long-lived core)
#   legacy      — in wheezy − stretch (dropped by stretch)
#   modern      — in stretch − wheezy (arrived during the transition)
#   jessie_only — in jessie but in neither wheezy nor stretch (transient churn)
# Per-release counts of category members present in that release's minbase are
# emitted so each row's sum equals minbase_count in package_counts.csv.
source "$(dirname "$0")/../lib/common.sh"

ensure_dir "$RESULTS_DIR"

OUT_CSV="$RESULTS_DIR/init_transition.csv"

WHEEZY_LIST="$DATA_DIR/parsed/wheezy_minbase.txt"
JESSIE_LIST="$DATA_DIR/parsed/jessie_minbase.txt"
STRETCH_LIST="$DATA_DIR/parsed/stretch_minbase.txt"

for f in "$WHEEZY_LIST" "$JESSIE_LIST" "$STRETCH_LIST"; do
    [[ -f "$f" ]] || { log_error "Missing minbase list: $f"; exit 1; }
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

sort -u "$WHEEZY_LIST"  > "$TMP/wheezy"
sort -u "$JESSIE_LIST"  > "$TMP/jessie"
sort -u "$STRETCH_LIST" > "$TMP/stretch"

# Set-based category definitions (each line is a single package name)
comm -12 "$TMP/wheezy" "$TMP/stretch" > "$TMP/persistent"
comm -23 "$TMP/wheezy" "$TMP/stretch" > "$TMP/legacy"
comm -13 "$TMP/wheezy" "$TMP/stretch" > "$TMP/modern"
sort -u "$TMP/wheezy" "$TMP/stretch"   > "$TMP/wheezy_or_stretch"
comm -23 "$TMP/jessie" "$TMP/wheezy_or_stretch" > "$TMP/jessie_only"

# Count how many members of each category are present in a given release's minbase.
count_in() {
    local release_list="$1" category_list="$2"
    comm -12 "$release_list" "$category_list" | wc -l | tr -d ' '
}

# Year lookup for the three releases
year_for() {
    awk -F'\t' -v c="$1" '!/^#/ && $1==c {print $3; exit}' "$RELEASES_CONF"
}

echo "codename,year,persistent,legacy,modern,jessie_only" > "$OUT_CSV"

for codename in wheezy jessie stretch; do
    list="$TMP/$codename"
    year=$(year_for "$codename")
    persistent=$(count_in "$list" "$TMP/persistent")
    legacy=$(count_in "$list" "$TMP/legacy")
    modern=$(count_in "$list" "$TMP/modern")
    jessie_only=$(count_in "$list" "$TMP/jessie_only")
    total=$((persistent + legacy + modern + jessie_only))
    actual=$(wc -l < "$list" | tr -d ' ')
    if (( total != actual )); then
        log_warn "$codename: category sum $total != minbase total $actual"
    fi
    echo "$codename,$year,$persistent,$legacy,$modern,$jessie_only" >> "$OUT_CSV"
    log_info "$codename ($year): persistent=$persistent legacy=$legacy modern=$modern jessie_only=$jessie_only (sum=$total)"
done

log_info "Generated: $OUT_CSV"
