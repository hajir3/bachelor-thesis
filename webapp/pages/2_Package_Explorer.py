"""Package Explorer — per-package history across releases."""
from __future__ import annotations

import pandas as pd
import plotly.express as px
import streamlit as st

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lib.charts import line_over_releases  # noqa: E402
from lib.config import RELEASE_ORDER  # noqa: E402
from lib.export import show_chart  # noqa: E402
from lib.data import (  # noqa: E402
    all_known_packages,
    binaries_for_source,
    deps_for_binary,
    predeps_for_binary,
    load_complexity_detail,
    load_dependency_lists,
    load_patch_sizes,
    load_persistent_packages,
    load_tokei_summary,
    package_nloc_by_release,
    persistent_set,
)

st.set_page_config(page_title="Package Explorer", layout="wide")
st.title("Package Explorer")
st.caption(
    "Pick a persistent source package and trace its metrics across all releases."
)

# This explorer is scoped to the persistent-package core (sources present in
# every release's minbase). The wider set of minbase sources that
# all_known_packages() also returns is filtered out so the picker only offers
# packages the thesis actually analyses.
persistent = persistent_set()
packages = [p for p in all_known_packages() if p in persistent]
default_idx = packages.index("bash") if "bash" in packages else 0
package = st.selectbox("Source package", packages, index=default_idx)

# --- Persistence badge -----------------------------------------------------
persistent_df = load_persistent_packages()
match = persistent_df[persistent_df["source_package"] == package]
if not match.empty:
    row = match.iloc[0]
    st.success(
        f"Persistent: present in {int(row['present_in_releases'])}/"
        f"{int(row['total_releases'])} releases ({row['presence_pct']}%)."
    )
else:
    st.info("Not in the persistent-package set (does not appear in every minbase).")

# --- Per-metric history ---------------------------------------------------
nloc = package_nloc_by_release()
cc = load_complexity_detail()
patches = load_patch_sizes()
dep_lists = load_dependency_lists()

nloc_p = nloc[nloc["source_package"] == package].sort_values("codename")
cc_p = cc[cc["source_package"] == package].sort_values("codename")
patches_p = patches[patches["source_package"] == package].sort_values("codename")

# Dependency history is the *sum* over all binary packages built from this
# source (one source can ship several binaries). Depends and Pre-Depends are
# tracked as separate series: Pre-Depends is a stronger relation, and some
# Essential-set sources (tar, perl, hostname) declare dependencies only via
# Pre-Depends, so collapsing them would understate (or zero out) their
# dependency footprint.
def _count_entries(s: str) -> int:
    return 0 if not s else len([x for x in s.split(";") if x.strip()])

_dep_src = dep_lists[dep_lists["source"] == package].copy()
_dep_src["Depends"] = _dep_src["depends"].fillna("").apply(_count_entries)
_dep_src["Pre-Depends"] = _dep_src["pre_depends"].fillna("").apply(_count_entries)
deps_p = (
    _dep_src.groupby(["codename", "year"], observed=True)[["Depends", "Pre-Depends"]]
    .sum()
    .reset_index()
    .sort_values("codename")
)
deps_p["total"] = deps_p["Depends"] + deps_p["Pre-Depends"]

col1, col2 = st.columns(2)
with col1:
    if not nloc_p.empty:
        show_chart(
            line_over_releases(nloc_p, y="nloc", title="NLOC", y_label="Lines of code"),
            filename=f"{package}-nloc",
        )
    else:
        st.warning("No NLOC data for this package.")

with col2:
    if not cc_p.empty:
        cc_long = cc_p.melt(
            id_vars=["codename"], value_vars=["avg_cc", "max_cc"],
            var_name="metric", value_name="value",
        )
        show_chart(
            line_over_releases(cc_long, y="value", color="metric",
                               title="Cyclomatic complexity", y_label="CC",
                               y_min=1),
            filename=f"{package}-complexity",
        )
    else:
        # Cyclomatic complexity is computed by pmccabe, which parses only
        # C/C++. A package whose source contains no C/C++ (e.g. debconf is
        # Perl, base-files is shell and static data) produces no complexity
        # row at all: this is N/A by construction, not missing data. Mirror
        # the native-package patch caption below by stating that explicitly,
        # naming the languages the package actually ships.
        C_LANGS = {"C", "C++", "C Header", "C++ Header"}
        pkg_langs = sorted(
            load_tokei_summary()
            .loc[lambda d: d["source_package"] == package, "language"]
            .dropna()
            .unique()
            .tolist()
        )
        if pkg_langs and not (C_LANGS & set(pkg_langs)):
            st.info(
                "Cyclomatic complexity is measured only for C/C++ source "
                "(pmccabe). This package ships no C/C++ — its source is "
                f"{', '.join(pkg_langs)} — so complexity is not applicable "
                "to it, rather than missing."
            )
        else:
            st.warning("No complexity data for this package.")

col3, col4 = st.columns(2)
with col3:
    if not patches_p.empty:
        show_chart(
            line_over_releases(patches_p, y="patch_lines",
                               title="Debian patch lines", y_label="Lines"),
            filename=f"{package}-patch-lines",
        )
        # Debian-native packages have no .orig/.debian split, hence no patch
        # set: a flat zero here is "not applicable", not missing data. Detect
        # them by a Debian-archive size of zero across every release.
        if (patches_p["debian_archive_bytes"].fillna(0) == 0).all():
            st.caption(
                "Debian-native package: no separate upstream/Debian split, so "
                "there is no patch set. Zero is correct by construction, not "
                "missing data."
            )
    else:
        st.warning("No Debian patches recorded for this package.")

with col4:
    if not deps_p.empty and deps_p["total"].sum() > 0:
        dep_long = deps_p.melt(
            id_vars=["codename"], value_vars=["Depends", "Pre-Depends"],
            var_name="relation", value_name="entries",
        )
        show_chart(
            line_over_releases(dep_long, y="entries", color="relation",
                               title="Σ dependency entries across all binaries",
                               y_label="# entries"),
            filename=f"{package}-dependencies",
        )
        st.caption(
            "Sum of Depends and Pre-Depends entries across every binary built "
            "from this source in each release's minbase. Pre-Depends is a "
            "stronger relation (configured before unpacking); some "
            "Essential-set packages declare dependencies only via Pre-Depends."
        )
    else:
        st.warning("Not present in minbase dependency data.")

# --- Binaries built from this source (with dependency names) --------------
st.subheader("Binary packages built from this source")
releases_with_binaries = sorted(
    {r for r in dep_lists[dep_lists["source"] == package]["codename"].astype(str).unique()},
    key=lambda c: RELEASE_ORDER.index(c) if c in RELEASE_ORDER else -1,
)
if not releases_with_binaries:
    st.info(
        f"`{package}` is not the upstream of any binary package present in "
        "any release's minbase. (Source-only packages like dpkg-dev, "
        "build-only packages, and a few non-minbase sources fall here.)"
    )
else:
    default_idx = len(releases_with_binaries) - 1  # most recent
    chosen_release = st.selectbox(
        "Release", releases_with_binaries, index=default_idx,
        key="binaries_release",
    )
    binaries = binaries_for_source(chosen_release, package)
    rows = []
    for b in binaries:
        deps = deps_for_binary(chosen_release, b)
        predeps = predeps_for_binary(chosen_release, b)
        rows.append({
            "binary_package": b,
            "num_depends": len(deps),
            "num_pre_depends": len(predeps),
            "depends": "; ".join(deps) if deps else "",
            "pre_depends": "; ".join(predeps) if predeps else "",
        })
    if rows:
        st.dataframe(
            pd.DataFrame(rows).sort_values("num_depends", ascending=False),
            width="stretch",
            hide_index=True,
        )
    else:
        st.info(f"No minbase binaries from `{package}` in `{chosen_release}`.")

# --- Language breakdown for the latest release the package appears in -----
tokei = load_tokei_summary()
pkg_tokei = tokei[tokei["source_package"] == package]
if not pkg_tokei.empty:
    latest = pkg_tokei["codename"].max()
    latest_df = pkg_tokei[pkg_tokei["codename"] == latest].sort_values("code", ascending=False)
    fig = px.bar(
        latest_df, x="language", y="code",
        title=f"Language breakdown in {latest} (NLOC)",
    )
    fig.update_layout(
        xaxis_title="Language", yaxis_title="Lines of code",
        margin=dict(l=10, r=10, t=40, b=10),
    )
    show_chart(fig, filename=f"{package}-language-breakdown")
