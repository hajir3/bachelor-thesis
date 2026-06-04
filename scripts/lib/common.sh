#!/usr/bin/env bash
# common.sh — Shared functions for Debian complexity analysis pipeline
# Source this file from other scripts: source "$(dirname "$0")/../lib/common.sh"

set -euo pipefail

# --- Path Constants ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/output"
DATA_DIR="${DATA_DIR:-$OUTPUT_DIR/data}"

# If a run directory file exists, use the versioned paths from it
_RUN_FILE="$OUTPUT_DIR/.current_run"
if [[ -f "$_RUN_FILE" ]]; then
    RESULTS_DIR="${RESULTS_DIR:-$(sed -n '1p' "$_RUN_FILE")}"
    FIGURES_DIR="${FIGURES_DIR:-$(sed -n '2p' "$_RUN_FILE")}"
else
    RESULTS_DIR="${RESULTS_DIR:-$OUTPUT_DIR/results}"
    FIGURES_DIR="${FIGURES_DIR:-$OUTPUT_DIR/figures}"
fi
CONFIG_DIR="$SCRIPT_DIR/config"
RELEASES_CONF="${RELEASES_CONF:-$CONFIG_DIR/releases.conf}"
ALIASES_CONF="$CONFIG_DIR/package_aliases.conf"

# --- Logging ---
log_info()  { echo "[INFO]  $*" >&2; }
log_warn()  { echo "[WARN]  $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# --- Directory Helper ---
ensure_dir() {
    mkdir -p "$1"
}

# --- Download Helper ---
# Downloads a URL to a local path if the file does not already exist.
# Usage: download_if_missing <url> <dest_path>
download_if_missing() {
    local url="$1"
    local dest="$2"
    local max_retries=3

    if [[ -f "$dest" ]]; then
        log_info "Already exists: $dest"
        return 0
    fi

    ensure_dir "$(dirname "$dest")"

    local attempt=0
    while (( attempt < max_retries )); do
        attempt=$((attempt + 1))
        log_info "Downloading (attempt $attempt/$max_retries): $url"
        if curl -sSL --fail --retry 2 --max-time 120 -o "$dest.tmp" "$url"; then
            mv "$dest.tmp" "$dest"
            log_info "Saved: $dest"
            return 0
        else
            log_warn "Download failed (attempt $attempt/$max_retries): $url"
            rm -f "$dest.tmp"
            if (( attempt < max_retries )); then
                sleep $((attempt * 2))
            fi
        fi
    done

    log_error "Failed to download after $max_retries attempts: $url"
    return 1
}

# --- Release Iterator ---
# Reads releases.conf and calls a callback function for each release.
# Callback receives: codename version year arch base_url has_sources
# Usage: for_each_release my_callback_function
for_each_release() {
    local callback="$1"
    while IFS=$'\t' read -r codename version year arch base_url has_sources; do
        [[ "$codename" =~ ^#.*$ || -z "$codename" ]] && continue
        "$callback" "$codename" "$version" "$year" "$arch" "$base_url" "$has_sources"
    done < "$RELEASES_CONF"
}

# --- Package Alias Resolution ---
# Resolves a source package name to its canonical name using aliases.
# Usage: resolve_alias "shellutils" -> "coreutils"
resolve_alias() {
    local name="$1"
    if [[ -f "$ALIASES_CONF" ]]; then
        local canonical
        canonical=$(awk -v pkg="$name" 'BEGIN{FS="\t"} !/^#/ && $1==pkg {print $2; exit}' "$ALIASES_CONF")
        if [[ -n "$canonical" ]]; then
            echo "$canonical"
            return
        fi
    fi
    echo "$name"
}

# Prints every historical source-package name that maps TO the given
# canonical name (reverse of resolve_alias). One name per line.
# Usage: reverse_aliases "coreutils" -> "shellutils\nfileutils\ntextutils"
reverse_aliases() {
    local canonical="$1"
    [[ -f "$ALIASES_CONF" ]] || return 0
    awk -v canon="$canonical" 'BEGIN{FS="\t"} !/^#/ && $2==canon {print $1}' "$ALIASES_CONF"
}

# --- Versioned Output Directories ---
# Creates output/results/<N>_<commit>_<dd.mm.yyyy>_<hh.mm> and the matching
# output/figures/ run directory, writes both paths to output/.current_run so
# all scripts use them.
# Usage: init_run (call once at pipeline start)
init_run() {
    local commit="${GIT_HASH:-}"
    if [[ -z "$commit" ]]; then
        commit=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    fi
    local base_results="$OUTPUT_DIR/results"
    local base_figures="$OUTPUT_DIR/figures"
    local n=1
    while ls -d "$base_results/${n}_"* >/dev/null 2>&1 || \
          ls -d "$base_figures/${n}_"* >/dev/null 2>&1; do
        n=$((n + 1))
    done
    # Naming: <N>_<commit>_<dd.mm.yyyy>_<hh.mm>
    local timestamp
    timestamp=$(date +"%d.%m.%Y_%H.%M")
    local run_results="$base_results/${n}_${commit}_${timestamp}"
    local run_figures="$base_figures/${n}_${commit}_${timestamp}"
    mkdir -p "$run_results" "$run_figures"
    # Write paths so all scripts pick them up via common.sh
    printf '%s\n%s\n' "$run_results" "$run_figures" > "$OUTPUT_DIR/.current_run"
    # Update current shell's variables
    RESULTS_DIR="$run_results"
    FIGURES_DIR="$run_figures"
    echo "Run directories: $run_results, $run_figures" >&2
}

# --- Decompress Helper ---
# Decompresses .gz files, keeping the original.
# Usage: decompress_gz <file.gz>
decompress_gz() {
    local gz_file="$1"
    local plain_file="${gz_file%.gz}"
    if [[ -f "$plain_file" ]]; then
        return 0
    fi
    gunzip -k "$gz_file"
}
