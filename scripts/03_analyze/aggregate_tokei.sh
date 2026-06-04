#!/usr/bin/env bash
# aggregate_tokei.sh — Build derived CSVs from tokei_summary.csv for plotting.
#
# Produces:
#   language_by_release.csv     — language breakdown per release
#   persistent_top5_nloc.csv    — top 5 persistent packages by total NLOC
source "$(dirname "$0")/../lib/common.sh"

ensure_dir "$RESULTS_DIR"

DETAIL_CSV="$RESULTS_DIR/tokei_summary.csv"
if [[ ! -f "$DETAIL_CSV" ]]; then
    log_error "Missing $DETAIL_CSV — run analyze_tokei.sh first"
    exit 1
fi

# tokei_summary.csv columns:
#   1 codename, 2 year, 3 source_package, 4 language, 5 files,
#   6 blank, 7 comment, 8 code

# --- 1. Language breakdown per release ---
LANG_CSV="$RESULTS_DIR/language_by_release.csv"
echo "codename,year,C,Shell,Assembly,Python,Perl,Other" > "$LANG_CSV"

while IFS=$'\t' read -r codename version year arch base_url has_sources; do
    [[ "$codename" =~ ^#.*$ || -z "$codename" ]] && continue
    [[ "$has_sources" == "yes" ]] || continue

    c_code=$(awk -F',' -v cn="$codename" '$1==cn && ($4=="C" || $4=="C Header") {s+=$8} END {print s+0}' "$DETAIL_CSV")
    sh_code=$(awk -F',' -v cn="$codename" '$1==cn && ($4=="Shell" || $4=="Bash" || $4=="BASH" || $4=="Zsh") {s+=$8} END {print s+0}' "$DETAIL_CSV")
    asm_code=$(awk -F',' -v cn="$codename" '$1==cn && ($4=="Assembly" || $4=="GNU Style Assembly") {s+=$8} END {print s+0}' "$DETAIL_CSV")
    py_code=$(awk -F',' -v cn="$codename" '$1==cn && $4=="Python" {s+=$8} END {print s+0}' "$DETAIL_CSV")
    pl_code=$(awk -F',' -v cn="$codename" '$1==cn && $4=="Perl" {s+=$8} END {print s+0}' "$DETAIL_CSV")
    total=$(awk -F',' -v cn="$codename" '$1==cn && $4!="Total" {s+=$8} END {print s+0}' "$DETAIL_CSV")
    other=$((total - c_code - sh_code - asm_code - py_code - pl_code))
    if (( other < 0 )); then other=0; fi

    echo "$codename,$year,$c_code,$sh_code,$asm_code,$py_code,$pl_code,$other" >> "$LANG_CSV"
done < "$RELEASES_CONF"

log_info "Generated: $LANG_CSV"

# --- 2. Top 5 persistent packages by total NLOC ---
TOP5_CSV="$RESULTS_DIR/persistent_top5_nloc.csv"

top5=$(awk -F',' '
NR == 1 { next }
$4 == "Total" { next }
{
    pkg = $3
    code = $8
    total[pkg] += code
}
END {
    for (p in total) print total[p], p
}
' "$DETAIL_CSV" | sort -rn | head -5 | awk '{print $2}')

header="codename,year"
for pkg in $top5; do
    header="$header,$pkg"
done
echo "$header" > "$TOP5_CSV"

while IFS=$'\t' read -r codename version year arch base_url has_sources; do
    [[ "$codename" =~ ^#.*$ || -z "$codename" ]] && continue
    [[ "$has_sources" == "yes" ]] || continue

    line="$codename,$year"
    for pkg in $top5; do
        nloc=$(awk -F',' -v cn="$codename" -v p="$pkg" '$1==cn && $3==p && $4!="Total" {s+=$8} END {print s+0}' "$DETAIL_CSV")
        line="$line,$nloc"
    done
    echo "$line" >> "$TOP5_CSV"
done < "$RELEASES_CONF"

log_info "Generated: $TOP5_CSV"
