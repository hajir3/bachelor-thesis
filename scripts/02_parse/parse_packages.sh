#!/usr/bin/env bash
# parse_packages.sh — Parse Packages files into normalized CSVs
source "$(dirname "$0")/../lib/common.sh"

ensure_dir "$DATA_DIR/parsed"
ensure_dir "$RESULTS_DIR"

# Parse a single Packages file into CSV
parse_one() {
    local codename="$1"
    local packages_file="$DATA_DIR/packages/$codename/Packages"
    local out_csv="$DATA_DIR/parsed/${codename}_packages.csv"

    if [[ ! -f "$packages_file" ]]; then
        log_warn "No Packages file for $codename, skipping"
        return 0
    fi

    if [[ -f "$out_csv" ]]; then
        log_info "Already parsed: $out_csv"
        return 0
    fi

    log_info "Parsing $codename..."

    # Header
    echo "package,source,version,priority,section,installed_size,size,depends,pre_depends" > "$out_csv"

    # Parse stanza format with awk (case-insensitive field matching for older releases with inconsistent field-name casing)
    LC_ALL=C awk '
    BEGIN { OFS="," }

    # Empty line = end of stanza
    /^[[:space:]]*$/ {
        if (pkg != "") {
            # If no Source field, source = package name
            if (src == "") src = pkg
            # Escape commas in depends / pre-depends (top-level separators
            # become ";" so each stays a single comma-free CSV field).
            gsub(/,/, ";", dep)
            gsub(/,/, ";", predep)
            print pkg, src, ver, pri, sec, isize, sz, dep, predep
        }
        pkg=""; src=""; ver=""; pri=""; sec=""; isize=""; sz=""; dep=""; predep=""
        next
    }

    {
        # Normalize field name to lowercase for matching
        field = tolower($1)
    }

    field == "package:"       { pkg = $2 }
    field == "source:"        { src = $2; gsub(/ .*/, "", src) }
    field == "version:"       { ver = $2 }
    field == "priority:"      { pri = tolower($2) }
    field == "section:"       { sec = $2 }
    field == "installed-size:" { isize = $2 }
    field == "size:"          { sz = $2 }
    field == "depends:"       {
        dep = $0
        sub(/^[^:]+:[[:space:]]*/, "", dep)
    }
    field == "pre-depends:"   {
        predep = $0
        sub(/^[^:]+:[[:space:]]*/, "", predep)
    }

    END {
        # Flush last stanza
        if (pkg != "") {
            if (src == "") src = pkg
            gsub(/,/, ";", dep)
            gsub(/,/, ";", predep)
            print pkg, src, ver, pri, sec, isize, sz, dep, predep
        }
    }
    ' "$packages_file" >> "$out_csv"

    local count
    count=$(tail -n +2 "$out_csv" | wc -l | tr -d ' ')
    log_info "Parsed $codename: $count packages"
}

# Main
log_info "=== Parsing Packages files ==="
parse_release() {
    local codename="$1"
    shift 5
    parse_one "$codename"
}
for_each_release parse_release
log_info "=== Done ==="
