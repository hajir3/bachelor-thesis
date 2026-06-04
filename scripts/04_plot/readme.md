# Plots: Purpose and Thesis Relevance

This directory contains the gnuplot scripts that render the figures used in the
thesis *Software Bloat in Debian*. Each plot is tied to one of the dimensions of
the research question stated in
`thesis/parts/02_main_matter/01_introduction.tex` or to a metric defined in
`thesis/parts/02_main_matter/03_method.tex`. This file documents why each figure
exists and what it is meant to show in the results chapter.

## Research question addressed

The thesis is **exploratory-descriptive**. Its primary research question is
descriptive, not inferential: it asks what a reproducible release-wise analysis
of the persistent packages in Debian's minbase installation *reveals about their
development* across all stable releases from Potato (2000) to Trixie (2025),
characterised along **five co-equal dimensions**:

1. installed size,
2. dependency structure,
3. lines of code,
4. per-function cyclomatic complexity, and
5. distribution-specific patch volume.

A secondary question sharpens the primary one by asking **how the composition of
the minbase installation has changed** across releases (which packages entered,
which were removed, and which form the persistent core), and how the volume and
file-level structure of Debian's patches have evolved.

**Framing constraint.** The thesis explicitly does *not* claim that any
dimension is correlated with, caused by, or predictive of another. Each figure's
job is therefore to *clearly and honestly display one dimension across the 13
releases*; it is not to assert the direction or magnitude of a trend. Captions in
the results chapter must describe what is visible without smuggling in causal or
correlational claims. The five dimensions above are co-equal: dependency
structure and patch volume are full dimensions of the primary question, not
peripheral add-ons.

**Scope.** All persistent-core metrics are computed over the 25 persistent
*source* packages (Table~\ref{tab:persistent-packages} in the method chapter).
Three figures instead describe the *whole* minbase population, because their
metric is a property of the minbase as a whole rather than of the fixed
persistent core: `package_count`, `dependency_distribution`, and
`init_transition`. The figure captions should state which population each one
measures.

The plots below are grouped by the dimension they support.

---

## Installed size (primary dimension)

### `plot_installed_size.gp` — `installed_size.pdf`
Installed size (in MB) of the full minbase installation against the installed
size of only the *persistent subset* (the 25 source packages). The area between
the two lines is shaded to highlight the contribution of transient packages that
enter and leave the minbase across releases. Addresses the installed-size
dimension directly and simultaneously visualises how much of the base-system
footprint is carried by the long-lived core, which also touches the secondary
composition question. Zero-based single axis; no scaling caveats apply.

---

## Lines of code (primary dimension) — a coordinated trio

The next three figures all serve the lines-of-code dimension and should be
presented together as one coordinated view, not as three independent findings.
Each decomposes the same NLOC total along a different axis: by **line type**
(`nloc`), by **package** (`persistent_growth`), and by **language**
(`language_breakdown`). Presenting them as a trio avoids the impression that one
dimension is being counted three times.

### `plot_nloc.gp` — `nloc.pdf`
Total NLOC, comment lines, and blank lines across all persistent packages per
release, measured with `tokei`. This is the headline line-of-code chart and the
quantitative counterpart to Lehman's and Wirth's qualitative claims of
ever-growing systems cited in the introduction. Zero-based single axis.

### `plot_persistent_growth.gp` — `persistent_growth.pdf`
Per-package NLOC trajectory for the five largest persistent packages across all
releases. Where `nloc.gp` gives the aggregate, this plot makes individual growth
patterns visible and lets the discussion attribute the overall code-size trend to
specific packages (glibc and perl dominate; perl is absent in Potato, hence its
zero start). This is the only figure that decomposes NLOC by package.

### `plot_language_breakdown.gp` — `language_breakdown.pdf`
Stacked histogram of NLOC by programming language per release. It shows whether
the growth in `nloc.gp` is concentrated in one language (C dominance) or whether
newer releases add new languages to the base system, and it uniquely motivates
the C/C++-only restriction of the complexity analysis. Python is folded into the
`Other` band rather than drawn separately: it never exceeds ~0.4% of total LOC,
so a dedicated slice would be invisible in every bar and overstate a contribution
the figure cannot render. This is the only figure that decomposes NLOC by
language.

---

## Per-function cyclomatic complexity (primary dimension)

### `plot_complexity.gp` — `complexity.pdf`
Average and median cyclomatic complexity per function across all persistent
packages per release. The median is plotted alongside the mean because
function-level CC distributions are heavily right-skewed (see
`plot_cc_distribution.gp`); reporting both prevents a handful of outlier
functions from dominating the narrative. This figure owns the central-tendency
view of the complexity dimension. The descriptive observation it supports (the
average humps mildly and then declines while NLOC grows roughly fivefold, the
median staying flat at 3) echoes the Israeli and Feitelson kernel result cited in
the related-work chapter; the caption should report this as an observation, not as
a causal claim.

### `plot_cc_distribution.gp` — `cc_distribution.pdf`
Per-release boxplots of the per-function cyclomatic complexity, showing the
median, interquartile range, and whiskers. This is the figure that delivers the
"per-release distribution" deliverable named in the introduction: it shows the
*shape* of the distribution (its spread), which the central-tendency lines in
`complexity.pdf` cannot. Outliers are intentionally suppressed
(`set style boxplot nooutliers`): the distribution has a very long right tail (a
few functions exceed CC 1000), and plotting every outlier as a point produced an
opaque cloud that buried the boxes. The maximum and the long tail are instead
reported as a summary statistic in the text (the single most complex function in
every release after Potato is `perl`'s hand-written tokenizer, which is a
composition artefact rather than a property of the persistent core, so it is not
given its own figure). The boxplot makes visible that the bulk of the
distribution is remarkably stable across 25 years, with the interquartile range
narrowing slightly in the two most recent releases.

---

## Dependency structure (primary dimension)

### `plot_dependency_distribution.gp` — `dependency_distribution.pdf`
Per-release boxplots of per-package dependency counts in the minbase
installation. Inter-package coupling is a form of system-level complexity that
lines of code and cyclomatic complexity miss. The boxplot makes medians,
interquartile ranges, and outliers visible at once, so a rising maximum driven by
a small number of hub packages is distinguishable from a broad shift in central
tendency. The y-axis is deliberately not clipped: the high-dependency outliers
(such as the package with 17 dependencies in Jessie) are the coupling signal the
figure exists to surface, so trimming them to enlarge the boxes would hide the
finding. This is the sole visualisation of the dependency-count dimension, and it
is computed over the whole minbase (not the persistent subset) because dependency
structure is a graph-level property of the minbase as a whole.

---

## Distribution-specific patch volume (primary dimension)

### `plot_patch_size.gp` — `patch_size.pdf`
Total patch lines applied by Debian maintainers to the persistent packages per
release. The figure is drawn on a **single axis**; the former secondary
"packages with patches" axis was removed because it spanned only 14-18 packages
yet was auto-scaled to full plot height, manufacturing false volatility from a
near-flat series. Debian's source-package format changed from `1.0` (`.diff.gz`,
which bundles the entire `debian/` directory into one diff) to `3.0 (quilt)`
around Jessie (2015); patch-line counts are only comparable within the quilt era,
because `1.0`-format counts are inflated by non-code material (build caches,
embedded projects, completion scripts). The figure therefore draws the full
series in muted grey for historical context, marks the format boundary, and
overlays the comparable `3.0 (quilt)` era (Jessie onward) in solid colour. The
detailed decomposition of why the metric is not comparable across the boundary is
given for the `bash` case in the results chapter; this figure should be read
together with that discussion and interpreted only within the quilt era.

---

## Minbase composition (secondary question)

### `plot_package_count.gp` — `package_count.pdf`
Number of packages in the minbase installation for each release, drawn as a
line/dot plot. A bar chart was avoided: the series sits in a narrow band
(44-95) well above zero, so bars would have to either start at zero (compressing
the non-monotonic structure into near-identical heights) or use a truncated
baseline (misleading for bars, whose length encodes magnitude). A line/dot plot
legitimately need not start at zero and makes the release-to-release shape
readable, including the Jessie and Bullseye spikes. This figure establishes the
scope of the base system over 25 years and is the only figure carrying the raw
minbase package-count series; it is the denominator against which the persistent
subset is understood.

### `plot_init_transition.gp` — `init_transition.pdf`
Stacked-bar decomposition of the minbase composition across the
Wheezy -> Jessie -> Stretch window, the period of the systemd/init-system
transition. It explains the anomalous Jessie spike visible in `package_count.pdf`
by partitioning the minbase into set-membership categories: packages common to
Wheezy and Stretch, legacy packages dropped by Stretch, modern packages added by
Stretch, and transient packages present only in Jessie. `package_count` shows
*that* the spike exists; this figure shows *why*. Note that the green "common"
band (53 binary packages) is the Wheezy-Stretch minbase intersection, a broader
population than the 25 persistent *source* packages; it is labelled "common to
wheezy and stretch" rather than "persistent" to avoid colliding with that
definition. This figure is referenced in the results chapter
(`\autoref{fig:init-transition}` in `04_results.tex`) as the set-membership
interpretation of the `package_count` non-monotonicity at Jessie, and again in
the discussion (`05_discussion.tex`).

---

## Conventions shared by all scripts

- All scripts emit PDF via the `pdfcairo` terminal at 7in × 4.5in
  and Helvetica 11 pt, matching the typography of the LaTeX document.
- The input directory is overridable via the gnuplot variable `DATADIR`
  and the output directory via `OUTDIR`; both default to
  `../../output/results` and `../../output/figures` respectively, so the
  scripts run unchanged inside the Docker pipeline and from a shell.
  `run_plots.sh --latest` re-renders every `*.gp` into the newest run dir.
- Input CSVs come from `scripts/03_analyze/` and are documented in the
  header comment of each plot script.
- Release codenames and years are hard-coded consistently
  (`potato` 2000 through `trixie` 2025) to keep the x-axis identical
  across every figure in the thesis.
