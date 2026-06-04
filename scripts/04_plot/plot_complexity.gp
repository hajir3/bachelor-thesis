# plot_complexity.gp — Central tendency (avg, median) of cyclomatic complexity over Debian releases.
# The full per-function distribution is shown in plot_cc_distribution.gp; the maximum CC
# is reported as a text statistic (it is dominated by perl's tokenizer, an excluded package).
reset

set terminal pdfcairo enhanced font "Helvetica,11" size 7in,4.5in
if (!exists("OUTDIR")) OUTDIR = '../../output/figures'
if (!exists("DATADIR")) DATADIR = '../../output/results'
set output OUTDIR.'/complexity.pdf'

set datafile separator ","
set style data linespoints
set pointsize 1.2

set title "Cyclomatic Complexity of Persistent Base Packages"
set xlabel "Release (Year)" offset 0,-1
set ylabel "Cyclomatic Complexity"

set xtics rotate by -38 
set offsets 0, 0.8, 0, 0   # right x-pad so the rotated trixie label clears the page edge
set grid ytics
set key top left
set yrange [1:*]

plot DATADIR.'/complexity_by_release.csv' every ::1 \
    using 0:4:xtic(sprintf("%s\n(%s)", stringcolumn(1), stringcolumn(2))) \
    with linespoints pt 7 ps 1.0 lw 2 lc rgb "#E74C3C" \
    title "Average CC", \
    '' every ::1 using 0:6 with linespoints pt 5 ps 0.8 lw 1.5 lc rgb "#8E44AD" \
    title "Median CC"
