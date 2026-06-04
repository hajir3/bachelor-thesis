#!/usr/bin/env bash
# run_plots.sh — Render every plot under scripts/04_plot/*.gp
#
# Two modes:
#   (default)   Reads RESULTS_DIR and FIGURES_DIR from output/.current_run via
#               common.sh — used by the in-pipeline _plot Makefile target.
#               Removes output/.current_run after the loop completes.
#   --latest    Resolves the highest-N run dir under output/results/ and
#               output/figures/ and re-renders into it in place. Used by the
#               _plot-only Makefile target (make plot).
#
# Usage:
#   bash scripts/04_plot/run_plots.sh
#   bash scripts/04_plot/run_plots.sh --latest

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

mode="default"
if [[ $# -gt 0 ]]; then
    case "$1" in
        --latest) mode="latest" ;;
        *) log_error "Unknown argument: $1"; exit 2 ;;
    esac
fi

if [[ "$mode" == "latest" ]]; then
    results_dir=$(ls -1d "$OUTPUT_DIR/results"/[0-9]*_*/ 2>/dev/null | sort -V -r | head -n1 || true)
    figures_dir=$(ls -1d "$OUTPUT_DIR/figures"/[0-9]*_*/ 2>/dev/null | sort -V -r | head -n1 || true)
    results_dir="${results_dir%/}"
    figures_dir="${figures_dir%/}"
    if [[ -z "$results_dir" || -z "$figures_dir" ]]; then
        log_error "No existing run directories found under $OUTPUT_DIR. Run \"make all\" first."
        exit 1
    fi
    RESULTS_DIR="$results_dir"
    FIGURES_DIR="$figures_dir"
    echo "=== Re-plotting into $FIGURES_DIR from $RESULTS_DIR ==="
else
    echo "=== Generating plots in $FIGURES_DIR ==="
fi

plot_dir="$SCRIPT_DIR/04_plot"
for gp in "$plot_dir"/*.gp; do
    echo "Plotting: $gp"
    (cd "$plot_dir" && gnuplot -e "OUTDIR='$FIGURES_DIR'; DATADIR='$RESULTS_DIR'" "$(basename "$gp")")
done

echo "=== Done: $RESULTS_DIR ==="
echo "=== Done: $FIGURES_DIR ==="

if [[ "$mode" == "default" ]]; then
    rm -f "$OUTPUT_DIR/.current_run"
fi
