# plot_cc_distribution.gp — Per-release distribution of per-function cyclomatic complexity.
# Reads complexity_functions.csv (codename, year, source_package, cc) and draws one
# boxplot per release showing the median, interquartile range and whiskers.
#
# Outliers are intentionally suppressed (`set style boxplot nooutliers`). The
# per-function CC distribution has a very long right tail (a few functions exceed
# CC 1000), and rendering every outlier as a point produced an opaque cloud that
# buried the boxes and made the figure unreadable. The maximum/tail is reported
# separately as a summary statistic in the text; this figure characterises the
# bulk of the distribution, i.e. the "per-release distribution" deliverable.
reset

set terminal pdfcairo enhanced font "Helvetica,11" size 7in,4.5in
if (!exists("OUTDIR")) OUTDIR = '../../output/figures'
if (!exists("DATADIR")) DATADIR = '../../output/results'
set output OUTDIR.'/cc_distribution.pdf'

set datafile separator ","

codenames = "potato woody sarge etch lenny squeeze wheezy jessie stretch buster bullseye bookworm trixie"
years     = "2000 2002 2005 2007 2009 2011 2013 2015 2017 2019 2021 2023 2025"

set title "Per-Function Cyclomatic Complexity Distribution per Release"
set xlabel "Release (Year)" offset 0,-1
set ylabel "Cyclomatic Complexity per Function"

# Cyclomatic complexity has a domain floor of 1 (a branch-free function is CC=1;
# CC=0 cannot occur), so the axis starts at 1 rather than 0.
set yrange [1:25]
set ytics add (1)   # label the domain floor; auto-ticks otherwise land on 5,10,...
set grid ytics

set xrange [0.3:13.7]
set xtics rotate by -38 nomirror  \
    ("potato\n(2000)" 1, "woody\n(2002)" 2, "sarge\n(2005)" 3, \
     "etch\n(2007)" 4,  "lenny\n(2009)" 5, "squeeze\n(2011)" 6, \
     "wheezy\n(2013)" 7, "jessie\n(2015)" 8, "stretch\n(2017)" 9, \
     "buster\n(2019)" 10, "bullseye\n(2021)" 11, "bookworm\n(2023)" 12, \
     "trixie\n(2025)" 13)

set style data boxplot
set style boxplot nooutliers
set style fill solid 0.25 border lc rgb "#34495E"
set boxwidth 0.55
unset key

plot for [i=1:13] DATADIR.'/complexity_functions.csv' every ::1 \
    using (i):(stringcolumn(1) eq word(codenames, i) ? column(4) : 1/0) \
    lc rgb "#8E44AD"
