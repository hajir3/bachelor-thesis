# plot_package_count.gp — Number of minbase packages per release
#
# Drawn as a line/dot plot rather than a bar chart. The series sits in a narrow
# band (44-95) well above zero, so a bar chart would have to either start at zero
# (compressing the non-monotonic structure into near-identical bars) or use a
# truncated baseline (misleading for bars, whose length is meant to encode
# magnitude). A line/dot plot legitimately need not start at zero and makes the
# release-to-release shape, including the jessie and bullseye spikes, readable.
reset

set terminal pdfcairo enhanced font "Helvetica,11" size 7in,4.5in
if (!exists("OUTDIR")) OUTDIR = '../../output/figures'
if (!exists("DATADIR")) DATADIR = '../../output/results'
set output OUTDIR.'/package_count.pdf'

set datafile separator ","
set style data linespoints
set pointsize 1.2

set title "Number of Minbase Installation Packages per Debian Release"
set xlabel "Release (Year)" offset 0,-1
set ylabel "Package Count"

set xtics rotate by -38 
set offsets 0, 0.8, 0, 0   # right x-pad so the rotated trixie label clears the page edge
set grid ytics
set key top left

plot DATADIR.'/package_counts.csv' every ::1 \
    using 0:4:xtic(sprintf("%s\n(%s)", stringcolumn(1), stringcolumn(2))) \
    with linespoints pt 7 ps 1.2 lw 2 lc rgb "#F39C12" title "Minbase Packages"
