# plot_persistent_growth.gp — NLOC growth of top-5 persistent packages
# Requires: results/persistent_top5_nloc.csv
# Format: codename,year,pkg1_nloc,pkg2_nloc,pkg3_nloc,pkg4_nloc,pkg5_nloc
# The header line contains the package names
reset

set terminal pdfcairo enhanced font "Helvetica,11" size 7in,4.5in
if (!exists("OUTDIR")) OUTDIR = '../../output/figures'
if (!exists("DATADIR")) DATADIR = '../../output/results'
set output OUTDIR.'/persistent_growth.pdf'

set datafile separator ","
set style data linespoints
set pointsize 1.0

set title "Code Growth of Top 5 Persistent Base Packages"
set xlabel "Release (Year)" offset 0,-1
set ylabel "Lines of Code (thousands)"

set xtics rotate by -38 
set offsets 0, 0.8, 0, 0   # right x-pad so the rotated trixie label clears the page edge
set grid ytics
set key outside right top

# Read package names from header
plot DATADIR.'/persistent_top5_nloc.csv' \
    using 0:($3/1000.0):xtic(sprintf("%s\n(%s)", stringcolumn(1), stringcolumn(2))) \
    with linespoints pt 7 lw 2 title columnheader(3), \
    '' using 0:($4/1000.0) with linespoints pt 5 lw 2 title columnheader(4), \
    '' using 0:($5/1000.0) with linespoints pt 9 lw 2 title columnheader(5), \
    '' using 0:($6/1000.0) with linespoints pt 11 lw 2 title columnheader(6), \
    '' using 0:($7/1000.0) with linespoints pt 13 lw 2 title columnheader(7)
