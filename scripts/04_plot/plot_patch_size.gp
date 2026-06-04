# plot_patch_size.gp — Debian patch lines applied to persistent base packages.
#
# Single axis. The former secondary "packages with patches" axis was removed: it
# spanned only 14-18 packages yet was auto-scaled to full plot height, so a one-
# package change traversed the whole chart and manufactured false volatility.
#
# Debian's source-package format changed from 1.0 (.diff.gz, which bundles the
# entire debian/ directory into one diff) to 3.0 (quilt) around Jessie (2015).
# Patch-line counts are only comparable within the quilt era, because 1.0-format
# counts are inflated by non-code material (build caches, embedded projects,
# completion scripts). The pre-Jessie portion is therefore drawn muted and the
# format boundary is marked; see the bash patch-volume case in the results
# chapter for the detailed decomposition.
reset

set terminal pdfcairo enhanced font "Helvetica,11" size 7in,4.5in
if (!exists("OUTDIR")) OUTDIR = '../../output/figures'
if (!exists("DATADIR")) DATADIR = '../../output/results'
set output OUTDIR.'/patch_size.pdf'

set datafile separator ","
set style data linespoints
set pointsize 1.2

set title "Debian Patch Lines Applied to Persistent Base Packages"
set xlabel "Release (Year)" offset 0,-1
set ylabel "Total Patch Lines"

set xtics rotate by -38 
set offsets 0, 0.8, 0, 0   # right x-pad so the rotated trixie label clears the page edge
set grid ytics
set key top right

# Source-format boundary: 1.0 (.diff.gz) up to and including Wheezy (x=6);
# 3.0 (quilt) from Jessie (x=7) onward. Mark the break between them.
set arrow from 6.5, graph 0 to 6.5, graph 1 nohead dt 2 lw 1.5 lc rgb "#7F8C8D"
set label "1.0 (.diff.gz)" at 6.4, graph 0.95 right font "Helvetica,9" tc rgb "#7F8C8D"
set label "3.0 (quilt)"    at 6.6, graph 0.95 left  font "Helvetica,9" tc rgb "#7F8C8D"

# Full series in muted grey for context (all 13 releases, also carries the
# x-axis tics), then the comparable 3.0 (quilt) era (Jessie onward, x>=7)
# overlaid in solid colour.
plot DATADIR.'/patch_summary.csv' every ::1 \
    using 0:4:xtic(sprintf("%s\n(%s)", stringcolumn(1), stringcolumn(2))) \
    with linespoints pt 7 ps 0.9 lw 1.5 lc rgb "#BDC3C7" \
    title "All releases (1.0 era not comparable)", \
    '' every ::1 using 0:($0 >= 7 ? $4 : 1/0) \
    with linespoints pt 7 ps 1.3 lw 2.5 lc rgb "#8E44AD" \
    title "3.0 (quilt) era (comparable)"
