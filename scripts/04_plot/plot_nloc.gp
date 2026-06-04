# plot_nloc.gp — Total NLOC of persistent packages over Debian releases
reset

set terminal pdfcairo enhanced font "Helvetica,11" size 7in,4.5in
if (!exists("OUTDIR")) OUTDIR = '../../output/figures'
if (!exists("DATADIR")) DATADIR = '../../output/results'
set output OUTDIR.'/nloc.pdf'

set datafile separator ","
set style data linespoints
set pointsize 1.2

set title "Total Lines of Code in Persistent Base Packages"
set xlabel "Release (Year)" offset 0,-1
set ylabel "Lines of Code (thousands)"

set xtics rotate by -38 
set offsets 0, 0.8, 0, 0   # right x-pad so the rotated trixie label clears the page edge
set grid ytics
set key top left

plot DATADIR.'/tokei_by_release.csv' every ::1 \
    using 0:($6/1000.0):xtic(sprintf("%s\n(%s)", stringcolumn(1), stringcolumn(2))) \
    with linespoints pt 7 ps 1.0 lw 2 lc rgb "#2E86C1" \
    title "Code (NLOC)", \
    '' every ::1 using 0:($5/1000.0) with linespoints pt 5 ps 0.8 lw 1.5 lc rgb "#27AE60" \
    title "Comments", \
    '' every ::1 using 0:($4/1000.0) with linespoints pt 9 ps 0.8 lw 1.5 lc rgb "#95A5A6" \
    title "Blank Lines"
