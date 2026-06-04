#!/usr/bin/env bash
# convert_svg_to_pdf.sh — Convert every SVG in the thesis image directory to a
# vector PDF and delete the source SVG.
#
# pdflatex cannot embed SVG directly (\includegraphics accepts only PDF/PNG/JPG),
# so SVG figures exported from the webapp must be converted before use. The
# conversion is vector->vector, so quality is preserved.
#
# Safety: a SVG is removed ONLY after its PDF has been written and verified
# non-empty. Conversion writes to a temporary file that is moved into place on
# success, so a failed conversion never truncates or clobbers an existing PDF
# and always leaves the SVG untouched for a retry. A directory with no SVGs is a
# successful no-op, so the target is safe to re-run.
#
# Usage: convert_svg_to_pdf.sh [IMG_DIR]   (defaults to <script dir>/img)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMG_DIR="${1:-$SCRIPT_DIR/img}"

log() { printf '[svg2pdf] %s\n' "$*"; }
err() { printf '[svg2pdf] ERROR: %s\n' "$*" >&2; }

[[ -d "$IMG_DIR" ]] || { err "image directory not found: $IMG_DIR"; exit 1; }

# Select an available SVG->PDF converter. Each branch defines convert() as
# convert <in.svg> <out.pdf>; every backend is given an explicit "pdf" format
# flag so the output filename's extension is irrelevant (lets us write to a
# temp file). Priority: rsvg-convert (fast, headless), inkscape, cairosvg.
if command -v rsvg-convert >/dev/null 2>&1; then
    converter="rsvg-convert"
    convert() { rsvg-convert -f pdf -o "$2" "$1"; }
elif command -v inkscape >/dev/null 2>&1; then
    converter="inkscape"
    convert() { inkscape "$1" --export-type=pdf --export-filename="$2" >/dev/null 2>&1; }
elif command -v cairosvg >/dev/null 2>&1; then
    converter="cairosvg"
    convert() { cairosvg "$1" -f pdf -o "$2"; }
else
    err "no SVG->PDF converter found. Install one of:"
    err "  brew install librsvg          # provides rsvg-convert (recommended)"
    err "  brew install --cask inkscape"
    err "  pip install cairosvg"
    exit 1
fi

shopt -s nullglob
svgs=("$IMG_DIR"/*.svg)
shopt -u nullglob

if (( ${#svgs[@]} == 0 )); then
    log "no SVG files in $IMG_DIR — nothing to convert."
    exit 0
fi

log "using $converter on ${#svgs[@]} SVG file(s) in $IMG_DIR"

converted=0
failed=0
for svg in "${svgs[@]}"; do
    pdf="${svg%.svg}.pdf"
    tmp="${pdf}.part"
    log "converting $(basename "$svg") -> $(basename "$pdf")"
    if convert "$svg" "$tmp" && [[ -s "$tmp" ]]; then
        mv -f "$tmp" "$pdf"
        rm -f "$svg"
        converted=$((converted + 1))
    else
        err "conversion failed for $(basename "$svg"); keeping the SVG."
        rm -f "$tmp"
        failed=$((failed + 1))
    fi
done

log "done: converted $converted, failed $failed (of ${#svgs[@]})."
(( failed == 0 ))
