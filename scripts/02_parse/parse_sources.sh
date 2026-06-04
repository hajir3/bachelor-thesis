#!/usr/bin/env bash
# parse_sources.sh — Parse Sources files into normalized CSVs
source "$(dirname "$0")/../lib/common.sh"

ensure_dir "$DATA_DIR/parsed"

parse_one() {
    local codename="$1"
    local sources_file="$DATA_DIR/sources_idx/$codename/Sources"
    local out_csv="$DATA_DIR/parsed/${codename}_sources.csv"

    if [[ ! -f "$sources_file" ]]; then
        log_warn "No Sources file for $codename, skipping"
        return 0
    fi

    if [[ -f "$out_csv" ]]; then
        log_info "Already parsed: $out_csv"
        return 0
    fi

    log_info "Parsing sources for $codename..."

    echo "source_package,version,directory,orig_file,orig_size,debian_file,debian_size,native_file,native_size" > "$out_csv"

    # Parse the stanza-based Sources format
    # Files field is multi-line: lines starting with space after "Files:" belong to it
    LC_ALL=C awk '
    BEGIN { OFS=","; pkg=""; ver=""; dir="" }

    /^[[:space:]]*$/ {
        if (pkg != "") {
            print pkg, ver, dir, orig_file, orig_size, deb_file, deb_size, native_file, native_size
        }
        pkg=""; ver=""; dir=""
        orig_file=""; orig_size=""
        deb_file=""; deb_size=""
        native_file=""; native_size=""
        in_files=0
        next
    }

    /^Package:/ { pkg=$2; in_files=0 }
    /^Version:/ { ver=$2; in_files=0 }
    /^Directory:/ { dir=$2; in_files=0 }

    /^Files:/ { in_files=1; next }
    /^[A-Za-z]/ { in_files=0 }

    in_files && /^[[:space:]]/ {
        # Format: md5sum size filename
        n = split($0, parts)
        if (n >= 3) {
            fsize = parts[2]
            fname = parts[3]
            # Exclude detached GPG signatures (*.orig.tar.xz.asc) which
            # also contain the substring ".orig.tar" and would otherwise
            # overwrite the real tarball entry (they are typically listed
            # after the tarball in the Files stanza).
            if (fname ~ /\.orig\.tar/ && fname !~ /\.asc$/) {
                orig_file = fname
                orig_size = fsize
            } else if (fname ~ /\.debian\.tar/ || fname ~ /\.diff\.gz/) {
                deb_file = fname
                deb_size = fsize
            } else if (fname ~ /\.tar\.(gz|xz|bz2)$/ && fname !~ /\.orig[.-]/ \
                       && fname !~ /\.debian\./ && fname !~ /\.asc$/) {
                # Debian-native packages (Format "3.0 (native)" or "1.0"
                # native) ship a single <pkg>_<ver>.tar.* with no .orig/.debian
                # split. Record it separately so the downloader and analyzers
                # can still fetch and measure these packages (e.g. dpkg,
                # debconf, hostname, base-files, base-passwd). The guards
                # exclude multi-component orig tarballs (".orig-foo.tar.*").
                native_file = fname
                native_size = fsize
            }
        }
    }

    END {
        if (pkg != "") {
            print pkg, ver, dir, orig_file, orig_size, deb_file, deb_size, native_file, native_size
        }
    }
    ' "$sources_file" >> "$out_csv"

    local count
    count=$(tail -n +2 "$out_csv" | wc -l | tr -d ' ')
    log_info "Parsed sources for $codename: $count source packages"
}

log_info "=== Parsing Sources files ==="
while IFS=$'\t' read -r codename version year arch base_url has_sources; do
    [[ "$codename" =~ ^#.*$ || -z "$codename" ]] && continue
    [[ "$has_sources" == "yes" ]] || continue
    parse_one "$codename"
done < "$RELEASES_CONF"
log_info "=== Done ==="
