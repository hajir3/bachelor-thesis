#!/usr/bin/env bash
# analyze_dependencies.sh — Dependency analysis for minbase packages.
#
# Produces three CSVs in $RESULTS_DIR:
#   dependency_counts.csv     (codename,year,package,num_depends,num_pre_depends)
#   dependency_lists.csv      (codename,year,package,source,depends,pre_depends)
#   source_to_binaries.csv    (codename,year,source_package,binary_packages)
#
# The `depends` and `pre_depends` fields carry the raw Depends / Pre-Depends
# strings from the parsed Packages CSV (semicolons separate entries; version
# constraints and "|" alternatives are preserved verbatim). They are kept as
# distinct fields because Pre-Depends is a stronger relation (must be
# configured before unpacking) and some Essential-set packages (tar,
# perl-base, hostname) declare deps only via Pre-Depends. Neither field
# contains commas, so CSV quoting is unnecessary.
source "$(dirname "$0")/../lib/common.sh"

ensure_dir "$RESULTS_DIR"

COUNTS_CSV="$RESULTS_DIR/dependency_counts.csv"
LISTS_CSV="$RESULTS_DIR/dependency_lists.csv"
S2B_CSV="$RESULTS_DIR/source_to_binaries.csv"

echo "codename,year,package,num_depends,num_pre_depends" > "$COUNTS_CSV"
echo "codename,year,package,source,depends,pre_depends" > "$LISTS_CSV"
echo "codename,year,source_package,binary_packages" > "$S2B_CSV"

while IFS=$'\t' read -r codename version year arch base_url has_sources; do
    [[ "$codename" =~ ^#.*$ || -z "$codename" ]] && continue

    local_csv="$DATA_DIR/parsed/${codename}_packages.csv"
    [[ -f "$local_csv" ]] || { log_warn "No parsed data for $codename"; continue; }

    minbase_list="$DATA_DIR/parsed/${codename}_minbase.txt"
    [[ -f "$minbase_list" ]] || { log_warn "No minbase list for $codename"; continue; }

    # --- 1) dependency_counts.csv + dependency_lists.csv (minbase rows) ----
    # Packages CSV columns: package,source,version,priority,section,installed_size,size,depends,pre_depends
    awk -F',' -v cn="$codename" -v yr="$year" -v listfile="$minbase_list" \
        -v counts="$COUNTS_CSV" -v lists="$LISTS_CSV" '
    BEGIN { while ((getline pkg < listfile) > 0) minbase[pkg] = 1 }
    NR == 1 { next }
    $1 in minbase {
        # The parser replaced top-level commas in Depends / Pre-Depends with
        # ";", so each is a single comma-free field: $8 = depends,
        # $9 = pre_depends. Entry count = number of ";"-separated items.
        dep = $8
        predep = $9

        if (dep == "" || dep == " ") ndep = 0
        else                         ndep = gsub(/;/, ";", dep) + 1

        if (predep == "" || predep == " ") npre = 0
        else                               npre = gsub(/;/, ";", predep) + 1

        print cn "," yr "," $1 "," ndep "," npre >> counts

        src = ($2 == "" ? $1 : $2)
        print cn "," yr "," $1 "," src "," dep "," predep >> lists
    }
    ' "$local_csv"

    # --- 2) source_to_binaries.csv (per release: source -> list of binaries) -
    # Build a per-release mapping over *all* binary packages (not just
    # minbase), so the webapp can resolve any source name a user types.
    awk -F',' -v cn="$codename" -v yr="$year" '
    NR == 1 { next }
    {
        pkg = $1
        src = ($2 == "" ? $1 : $2)
        if (!(src in seen)) {
            order[++n] = src
            seen[src] = 1
        }
        if (bins[src] == "") {
            bins[src] = pkg
        } else if (index(";" bins[src] ";", ";" pkg ";") == 0) {
            bins[src] = bins[src] ";" pkg
        }
    }
    END {
        for (i = 1; i <= n; i++) {
            s = order[i]
            print cn "," yr "," s "," bins[s]
        }
    }
    ' "$local_csv" >> "$S2B_CSV"

    log_info "$codename ($year): dependency outputs written"
done < "$RELEASES_CONF"

log_info "Generated: $COUNTS_CSV"
log_info "Generated: $LISTS_CSV"
log_info "Generated: $S2B_CSV"
