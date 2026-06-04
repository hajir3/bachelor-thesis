"""Minbase Snapshot — filterable view of a single release's package set.

Rows are *binary* packages (the unit of `apt install`), with the upstream
source package as a column. Source-level metrics (NLOC, CC, patches) are
joined on the source name so a binary's row carries the metrics of the
source it was built from.
"""
from __future__ import annotations

import pandas as pd
import streamlit as st

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lib.config import RELEASE_ORDER  # noqa: E402
from lib.data import (  # noqa: E402
    load_complexity_detail,
    load_dependency_lists,
    load_patch_sizes,
    load_tokei_summary,
    package_nloc_by_release,
    persistent_set,
)

st.set_page_config(page_title="Minbase Snapshot", layout="wide")
st.title("Minbase Snapshot")
st.caption(
    "Every binary package in the selected release's minbase whose source is "
    "persistent across releases, joined with its source package's NLOC, "
    "complexity, and Debian patches. Filter and export."
)

# --- Sidebar filters --------------------------------------------------------
with st.sidebar:
    st.subheader("Filters")
    release = st.selectbox("Release", RELEASE_ORDER, index=RELEASE_ORDER.index("trixie"))
    has_patches = st.checkbox("Source has Debian patches only", value=False)

    cc_df_all = load_complexity_detail()
    cc_max = float(cc_df_all["avg_cc"].max()) if not cc_df_all.empty else 100.0
    cc_threshold = st.slider("Source avg CC ≥", 0.0, cc_max, 0.0, step=0.5)

    nloc_df_all = package_nloc_by_release()
    nloc_max = int(nloc_df_all["nloc"].max()) if not nloc_df_all.empty else 0
    nloc_threshold = st.slider("Source NLOC ≥", 0, nloc_max, 0, step=1000)

    tokei = load_tokei_summary()
    languages = sorted(tokei["language"].dropna().unique().tolist())
    selected_languages = st.multiselect(
        "Source contains language(s)", languages, default=[],
        help="Empty = no filter.",
    )

# --- Build snapshot ---------------------------------------------------------
deps = load_dependency_lists()
nloc = package_nloc_by_release()
cc = load_complexity_detail()
patches = load_patch_sizes()
tokei_r = tokei[tokei["codename"] == release][["source_package", "language"]]
persistent = persistent_set()

# Rows = every binary in this release's minbase.
deps_r = deps[deps["codename"] == release][
    ["package", "source", "depends", "pre_depends"]
].rename(columns={"package": "binary_package", "source": "source_package"})

# Source-level metric joins.
nloc_r = nloc[nloc["codename"] == release][["source_package", "nloc"]]
cc_r = cc[cc["codename"] == release][["source_package", "num_functions", "avg_cc", "max_cc"]]
patches_r = patches[patches["codename"] == release][["source_package", "patch_lines", "num_patch_files"]]
langs_per_pkg = (
    tokei_r.groupby("source_package")["language"]
    .apply(lambda s: ", ".join(sorted(set(s))))
    .reset_index()
    .rename(columns={"language": "languages"})
)

snapshot = deps_r.copy()
for right in (nloc_r, cc_r, patches_r, langs_per_pkg):
    snapshot = snapshot.merge(right, on="source_package", how="left")

# Only persistent sources carry computed metrics (NLOC, CC, patches); the
# remaining binaries are excluded entirely so every visible row is complete.
snapshot = snapshot[snapshot["source_package"].isin(persistent)].reset_index(drop=True)
snapshot["num_depends"] = snapshot["depends"].fillna("").apply(
    lambda s: 0 if not s else len([d for d in s.split(";") if d.strip()])
)
snapshot["num_pre_depends"] = snapshot["pre_depends"].fillna("").apply(
    lambda s: 0 if not s else len([d for d in s.split(";") if d.strip()])
)

# Apply filters
mask = pd.Series(True, index=snapshot.index)
if has_patches:
    mask &= snapshot["patch_lines"].fillna(0) > 0
if cc_threshold > 0:
    mask &= snapshot["avg_cc"].fillna(0) >= cc_threshold
if nloc_threshold > 0:
    mask &= snapshot["nloc"].fillna(0) >= nloc_threshold
if selected_languages:
    def has_all(s: str | float) -> bool:
        if not isinstance(s, str):
            return False
        present = {x.strip() for x in s.split(",")}
        return all(lang in present for lang in selected_languages)

    mask &= snapshot["languages"].apply(has_all)

filtered = snapshot[mask].reset_index(drop=True)

# --- Summary ---------------------------------------------------------------
c1, c2, c3 = st.columns(3)
c1.metric("Binaries in view", len(filtered))
c2.metric("Distinct sources", filtered["source_package"].nunique())
c3.metric("Σ source patch lines", f"{int(filtered['patch_lines'].fillna(0).sum()):,}")

display = filtered[[
    "binary_package", "source_package",
    "num_depends", "depends",
    "num_pre_depends", "pre_depends",
    "nloc", "num_functions", "avg_cc", "max_cc",
    "patch_lines", "num_patch_files", "languages",
]]
st.dataframe(
    display.sort_values("nloc", ascending=False, na_position="last"),
    width="stretch",
    hide_index=True,
)
