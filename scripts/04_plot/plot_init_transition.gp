# plot_init_transition.gp — Minbase composition across the wheezy → jessie → stretch
# init-system (systemd) transition, decomposed into four set-based categories.
# Companion to package_count.pdf; explains the anomalous jessie minbase-count spike.
#
# Categories are defined purely by set membership over the WHOLE minbase:
#   common      = wheezy ∩ stretch  (stable across the transition; CSV column "persistent")
#   legacy      = wheezy − stretch  (dropped by stretch)
#   modern      = stretch − wheezy  (added by stretch)
#   jessie_only = jessie − (wheezy ∪ stretch)  (transient, present only in jessie)
# NB: the "common" band is the wheezy∩stretch minbase set (53 binary packages), a
# different and broader population than the thesis's 25 persistent SOURCE packages;
# it is labelled "common to wheezy & stretch" rather than "persistent" to avoid
# colliding with that definition.
reset

set terminal pdfcairo enhanced font "Helvetica,11" size 7in,4.5in
if (!exists("OUTDIR"))  OUTDIR  = '../../output/figures'
if (!exists("DATADIR")) DATADIR = '../../output/results'
set output OUTDIR.'/init_transition.pdf'

set datafile separator ","
set style data histograms
set style histogram rowstacked
set style fill solid 0.8 border -1
set boxwidth 0.5

set title "Init-System Transition: Minbase Composition, Wheezy {/Symbol \256} Jessie {/Symbol \256} Stretch"
set ylabel "Number of Minbase Packages"
set xlabel "Release (Year)" offset 0,-1

set yrange [0:*]
set grid ytics
set key outside right top

set xtics rotate by -38 

# Columns of init_transition.csv:
#   1 codename, 2 year, 3 persistent (the "common" band), 4 legacy, 5 modern, 6 jessie_only
# Stack order (bottom to top): common, legacy, jessie_only, modern. The columns
# are read 3,4,6,5 so the transient jessie-only band (col 6) sits between the
# dropped (legacy, col 4) and added (modern, col 5) bands; keep this order if
# the CSV layout changes.
plot DATADIR.'/init_transition.csv' every ::1 \
    using 3:xtic(sprintf("%s\n(%s)", stringcolumn(1), stringcolumn(2))) \
    title "Common to wheezy and stretch" lc rgb "#27AE60", \
    '' every ::1 using 4 title "Legacy (wheezy only)"    lc rgb "#E74C3C", \
    '' every ::1 using 6 title "Jessie-only churn"       lc rgb "#95A5A6", \
    '' every ::1 using 5 title "Modern (stretch onward)" lc rgb "#3498DB"
