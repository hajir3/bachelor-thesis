# plot_installed_size.gp — Installed size of minbase installation vs persistent subset.
# The area between the two lines represents transient (non-persistent) packages
# present in the current release's minbase but not in the long-lived core.
reset

set terminal pdfcairo enhanced font "Helvetica,11" size 7in,4.5in
if (!exists("OUTDIR")) OUTDIR = '../../output/figures'
if (!exists("DATADIR")) DATADIR = '../../output/results'
set output OUTDIR.'/installed_size.pdf'

set datafile separator ","
set pointsize 1.2

set title "Installed Size of Debian Minbase Installation Over Time"
set xlabel "Release (Year)" offset 0,-1
set ylabel "Installed Size (MB)"

set xtics rotate by -38 
set offsets 0, 0.8, 0, 0   # right x-pad so the rotated trixie label clears the page edge
set grid ytics
set key top left

# Column 3: minimal_install_kb (total minbase), Column 4: persistent_only_kb.
# Draw the shaded gap first so the line series overlay cleanly.
plot DATADIR.'/installed_sizes.csv' every ::1 \
    using 0:($3/1024.0):($4/1024.0):xtic(sprintf("%s\n(%s)", stringcolumn(1), stringcolumn(2))) \
    with filledcurves lc rgb "#AED6F1" fs transparent solid 0.35 noborder \
    title "Non-persistent packages", \
    '' every ::1 using 0:($3/1024.0) \
    with linespoints pt 7 ps 1.0 lw 2 lc rgb "#2E86C1" \
    title "Minbase Installation", \
    '' every ::1 using 0:($4/1024.0) \
    with linespoints pt 5 ps 0.9 lw 2 lc rgb "#D35400" \
    title "Persistent Subset"
