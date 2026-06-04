#!/usr/bin/env bash
# check_tools.sh — Verify that all required external tools are installed
source "$(dirname "$0")/../lib/common.sh"

# Tools that are not part of a standard POSIX/macOS install
EXTRA_TOOLS=(
    "curl:brew install curl"
    "gunzip:brew install gzip"
    "xz:brew install xz (or apt install xz-utils; tar needs it for .tar.xz)"
    "bzip2:brew install bzip2 (or apt install bzip2; tar needs it for .tar.bz2)"
    "jq:brew install jq"
    "tokei:brew install tokei (or cargo install tokei)"
    "pmccabe:brew install pmccabe (or apt install pmccabe)"
    "gnuplot:brew install gnuplot"
    "debootstrap:apt install debootstrap (runs inside Docker)"
    "python3:apt install python3 (used by make benchmark; needs the openpyxl module)"
)

# Standard POSIX tools (should always be present, but check anyway)
POSIX_TOOLS=(awk tar find sort wc tr head tail cat uniq mktemp stat)

missing=()

# Check non-standard tools
for entry in "${EXTRA_TOOLS[@]}"; do
    tool="${entry%%:*}"
    hint="${entry#*:}"
    if ! command -v "$tool" &>/dev/null; then
        missing+=("$tool  —  install with: $hint")
    fi
done

# Check standard POSIX tools
for tool in "${POSIX_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        missing+=("$tool  —  standard POSIX tool (check your PATH)")
    fi
done

if (( ${#missing[@]} == 0 )); then
    log_info "All required tools are installed."
    exit 0
else
    log_error "Missing ${#missing[@]} required tool(s):"
    for m in "${missing[@]}"; do
        echo "  • $m" >&2
    done
    exit 1
fi
