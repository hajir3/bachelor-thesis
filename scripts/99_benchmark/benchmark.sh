#!/usr/bin/env bash
# benchmark.sh — Run the full pipeline for a single distro in an isolated temp
#                directory and report per-step timings.  Results are appended to
#                an XLSX file via collect_results.py.
# Usage: benchmark.sh [codename]  (default: bookworm)
set -euo pipefail

BENCH_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_DIR="$(cd "$BENCH_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$SCRIPT_DIR/config/releases.conf"

CODENAME="${1:-bookworm}"

# Resolve the release line from config
RELEASE_LINE=$(awk -F'\t' -v cn="$CODENAME" '!/^#/ && $1==cn {print; exit}' "$CONFIG")
if [[ -z "$RELEASE_LINE" ]]; then
    echo "ERROR: Unknown release '$CODENAME'. Available:" >&2
    awk -F'\t' '!/^#/ && NF>0 {print "  " $1}' "$CONFIG" >&2
    exit 1
fi

IFS=$'\t' read -r _ _ _ _ _ has_sources <<< "$RELEASE_LINE"

# Create a temp releases.conf with only the chosen distro (+ header comment)
BENCH_CONF=$(mktemp)
grep '^#' "$CONFIG" > "$BENCH_CONF"
echo "$RELEASE_LINE" >> "$BENCH_CONF"

# --- Isolated temp directory for all benchmark data ---
BENCH_TMP="$BENCH_DIR/tmp"
mkdir -p "$BENCH_TMP/data" "$BENCH_TMP/results"

export DATA_DIR="$BENCH_TMP/data"
export RESULTS_DIR="$BENCH_TMP/results"

cleanup() {
    rm -rf "$BENCH_TMP"
    rm -f "$BENCH_CONF"
}
trap cleanup EXIT

# Pick the best available time source
if command -v gdate &>/dev/null; then
    _now() { gdate +%s.%N; }
elif date +%s.%N 2>/dev/null | grep -q '\.'; then
    _now() { date +%s.%N; }
else
    _now() { date +%s; }
fi

# Timing helper
declare -a STEP_NAMES=()
declare -a STEP_TIMES=()

run_step() {
    local name="$1"
    shift
    local start end elapsed
    start=$(_now)
    RELEASES_CONF="$BENCH_CONF" "$@"
    end=$(_now)
    elapsed=$(awk "BEGIN {printf \"%.3f\", $end - $start}")
    STEP_NAMES+=("$name")
    STEP_TIMES+=("$elapsed")
    echo "[BENCH] $name: ${elapsed}s" >&2
}

echo ""
echo "=== Benchmark: running full pipeline for '$CODENAME' ==="
echo ""

# --- Download Phase ---
run_step "download_packages" \
    bash "$SCRIPT_DIR/01_download/download_packages.sh"

if [[ "$has_sources" == "yes" ]]; then
    run_step "download_sources_idx" \
        bash "$SCRIPT_DIR/01_download/download_sources_idx.sh"
fi

# --- Parse Phase ---
run_step "parse_packages" \
    bash "$SCRIPT_DIR/02_parse/parse_packages.sh"

if [[ "$has_sources" == "yes" ]]; then
    run_step "parse_sources" \
        bash "$SCRIPT_DIR/02_parse/parse_sources.sh"
fi

run_step "find_persistent" \
    bash "$SCRIPT_DIR/02_parse/find_persistent.sh"

# --- Source Tarball Download ---
if [[ "$has_sources" == "yes" ]]; then
    run_step "download_tarballs" \
        bash "$SCRIPT_DIR/01_download/download_source_tarballs.sh"
fi

# --- Analysis Phase ---
run_step "analyze_installed_size" \
    bash "$SCRIPT_DIR/03_analyze/analyze_installed_size.sh"

run_step "analyze_dependencies" \
    bash "$SCRIPT_DIR/03_analyze/analyze_dependencies.sh"

if [[ "$has_sources" == "yes" ]]; then
    run_step "analyze_tokei" \
        bash "$SCRIPT_DIR/03_analyze/analyze_tokei.sh"

    run_step "aggregate_tokei" \
        bash "$SCRIPT_DIR/03_analyze/aggregate_tokei.sh"

    run_step "analyze_patches" \
        bash "$SCRIPT_DIR/03_analyze/analyze_patches.sh"

    run_step "analyze_complexity" \
        bash "$SCRIPT_DIR/03_analyze/analyze_complexity.sh"
fi

# --- Summary ---
echo ""
echo "=== Benchmark Results ($CODENAME) ==="
echo ""
printf "%-38s %10s\n" "Step" "Time (s)"
printf "%-38s %10s\n" "------------------------------" "----------"

total=0
for i in "${!STEP_NAMES[@]}"; do
    printf "%-38s %10s\n" "${STEP_NAMES[$i]}" "${STEP_TIMES[$i]}"
    total=$(awk "BEGIN {printf \"%.3f\", $total + ${STEP_TIMES[$i]}}")
done

printf "%-38s %10s\n" "------------------------------" "----------"
printf "%-38s %10s\n" "TOTAL" "$total"
echo ""

# --- Collect results into XLSX ---
# Build a comma-separated list of step_name:time pairs
TIMING_PAIRS=""
for i in "${!STEP_NAMES[@]}"; do
    [[ -n "$TIMING_PAIRS" ]] && TIMING_PAIRS+=","
    TIMING_PAIRS+="${STEP_NAMES[$i]}:${STEP_TIMES[$i]}"
done

python3 "$BENCH_DIR/collect_results.py" \
    --output "$BENCH_DIR/benchmark_results.xlsx" \
    --codename "$CODENAME" \
    --total "$total" \
    --timings "$TIMING_PAIRS"

echo "Results saved to scripts/99_benchmark/benchmark_results.xlsx"
