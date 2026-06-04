# plot_dependency_distribution.gp — Per-release distribution of per-package
# dependency edge counts in the minbase installation. This is the sole
# visualization of the dependency-count metric defined in method section 3.7.2.
# Reads dependency_counts.csv: codename, year, package, num_depends
reset

set terminal pdfcairo enhanced font "Helvetica,11" size 7in,4.5in
if (!exists("OUTDIR")) OUTDIR = '../../output/figures'
if (!exists("DATADIR")) DATADIR = '../../output/results'
set output OUTDIR.'/dependency_distribution.pdf'

set datafile separator ","

codenames = "potato woody sarge etch lenny squeeze wheezy jessie stretch buster bullseye bookworm trixie"

set title "Per-Package Dependency Count Distribution per Release"
set xlabel "Release (Year)" offset 0,-1
set ylabel "Dependencies per Package"

set grid ytics
set yrange [-0.5:*]

set xrange [0.3:13.7]
set xtics rotate by -38 nomirror  \
    ("potato\n(2000)" 1, "woody\n(2002)" 2, "sarge\n(2005)" 3, \
     "etch\n(2007)" 4,  "lenny\n(2009)" 5, "squeeze\n(2011)" 6, \
     "wheezy\n(2013)" 7, "jessie\n(2015)" 8, "stretch\n(2017)" 9, \
     "buster\n(2019)" 10, "bullseye\n(2021)" 11, "bookworm\n(2023)" 12, \
     "trixie\n(2025)" 13)

set style data boxplot
set style boxplot outliers pointtype 7
set style fill solid 0.25 border lc rgb "#34495E"
set boxwidth 0.55
unset key

plot for [i=1:13] DATADIR.'/dependency_counts.csv' every ::1 \
    using (i):(stringcolumn(1) eq word(codenames, i) ? column(4) : 1/0) \
    lc rgb "#27AE60"
