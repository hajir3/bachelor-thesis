"""Release Diff — compare two releases side-by-side."""
from __future__ import annotations

import pandas as pd
import plotly.express as px
import streamlit as st

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lib.config import RELEASE_ORDER  # noqa: E402
from lib.export import show_chart  # noqa: E402
from lib.data import (  # noqa: E402
    load_complexity_by_release,
    load_complexity_detail,
    load_installed_sizes,
    load_package_counts,
    load_patch_summary,
    load_tokei_by_release,
    package_nloc_by_release,
)

st.set_page_config(page_title="Release Diff", layout="wide")
st.title("Release Diff")
st.caption("Compare two Debian releases and see what changed.")

col_l, col_r = st.columns(2)
with col_l:
    left = st.selectbox("Left release", RELEASE_ORDER,
                        index=RELEASE_ORDER.index("wheezy"))
with col_r:
    options_right = [r for r in RELEASE_ORDER if r != left]
    default = "jessie" if "jessie" in options_right else options_right[-1]
    right = st.selectbox("Right release", options_right,
                         index=options_right.index(default))

# --- Summary deltas --------------------------------------------------------
def pick(df: pd.DataFrame, codename: str) -> dict:
    row = df[df["codename"] == codename]
    return row.iloc[0].to_dict() if not row.empty else {}


pkg_counts = load_package_counts()
sizes = load_installed_sizes()
tokei = load_tokei_by_release()
cc_rel = load_complexity_by_release()
patches = load_patch_summary()

L = {
    "minbase_count": pick(pkg_counts, left).get("minbase_count"),
    "installed_kb": pick(pkg_counts, left).get("minbase_installed_kb"),
    "persistent_kb": pick(sizes, left).get("persistent_only_kb"),
    "total_code": pick(tokei, left).get("total_code"),
    "avg_cc": pick(cc_rel, left).get("avg_cc"),
    "patch_lines": pick(patches, left).get("total_patch_lines"),
}
R = {
    "minbase_count": pick(pkg_counts, right).get("minbase_count"),
    "installed_kb": pick(pkg_counts, right).get("minbase_installed_kb"),
    "persistent_kb": pick(sizes, right).get("persistent_only_kb"),
    "total_code": pick(tokei, right).get("total_code"),
    "avg_cc": pick(cc_rel, right).get("avg_cc"),
    "patch_lines": pick(patches, right).get("total_patch_lines"),
}


def _delta(a, b) -> str:
    if a is None or b is None:
        return "—"
    try:
        return f"{(b - a):+,.0f}"
    except (TypeError, ValueError):
        return "—"


st.subheader(f"{left} → {right}")
c1, c2, c3, c4, c5, c6 = st.columns(6)
c1.metric("Δ minbase packages", _delta(L["minbase_count"], R["minbase_count"]),
          help=f"{L['minbase_count']} → {R['minbase_count']}")
c2.metric("Δ installed KiB", _delta(L["installed_kb"], R["installed_kb"]))
c3.metric("Δ persistent-only KiB", _delta(L["persistent_kb"], R["persistent_kb"]))
c4.metric("Δ total NLOC", _delta(L["total_code"], R["total_code"]))
c5.metric("Δ avg CC",
          f"{(R['avg_cc'] - L['avg_cc']):+.2f}"
          if (L["avg_cc"] is not None and R["avg_cc"] is not None) else "—")
c6.metric("Δ patch lines", _delta(L["patch_lines"], R["patch_lines"]))

# --- Added / removed / intersection -----------------------------------------
# Use dependency_counts.csv as the source of truth for *minbase membership*
# per release — it lists every minbase binary package. tokei/CC data is
# keyed on *source* packages and would miss most of minbase.
from lib.data import binary_minbase_set_by_release  # noqa: E402

bin_all = binary_minbase_set_by_release()
left_pkgs = set(bin_all[bin_all["codename"] == left]["binary_package"].astype(str))
right_pkgs = set(bin_all[bin_all["codename"] == right]["binary_package"].astype(str))

# Per-source NLOC and CC are still needed for the Δ-scatter below.
nloc = package_nloc_by_release()

added = sorted(right_pkgs - left_pkgs)
removed = sorted(left_pkgs - right_pkgs)
common = sorted(left_pkgs & right_pkgs)

st.caption("Lists below are *binary* minbase packages — the same set that the Δ minbase packages metric above counts.")
a, b, c = st.columns(3)
with a:
    st.markdown(f"### Added in {right} ({len(added)})")
    st.dataframe(pd.DataFrame({"binary_package": added}),
                 hide_index=True, width="stretch", height=360)
with b:
    st.markdown(f"### Removed in {right} ({len(removed)})")
    st.dataframe(pd.DataFrame({"binary_package": removed}),
                 hide_index=True, width="stretch", height=360)
with c:
    st.markdown(f"### Present in both ({len(common)})")
    st.dataframe(pd.DataFrame({"binary_package": common}),
                 hide_index=True, width="stretch", height=360)

# --- Δ NLOC vs Δ avg CC scatter on overlapping source packages -------------
st.subheader("Per-source-package change")
st.caption(
    "Scatter is over *source* packages with both NLOC and CC data in both "
    "releases — independent of the minbase-binary set above."
)

cc = load_complexity_detail()
left_metrics = (
    nloc[nloc["codename"] == left][["source_package", "nloc"]]
    .merge(
        cc[cc["codename"] == left][["source_package", "avg_cc"]],
        on="source_package", how="outer",
    )
)
right_metrics = (
    nloc[nloc["codename"] == right][["source_package", "nloc"]]
    .merge(
        cc[cc["codename"] == right][["source_package", "avg_cc"]],
        on="source_package", how="outer",
    )
)
joined = left_metrics.merge(
    right_metrics, on="source_package", how="inner",
    suffixes=(f"_{left}", f"_{right}"),
)
joined["delta_nloc"] = joined[f"nloc_{right}"] - joined[f"nloc_{left}"]
joined["delta_avg_cc"] = joined[f"avg_cc_{right}"] - joined[f"avg_cc_{left}"]
joined = joined.dropna(subset=["delta_nloc", "delta_avg_cc"])

if joined.empty:
    st.info("No overlapping packages with both NLOC and CC data for these releases.")
else:
    fig = px.scatter(
        joined,
        x="delta_nloc",
        y="delta_avg_cc",
        hover_name="source_package",
        title=f"Δ NLOC vs Δ avg CC ({left} → {right})",
    )
    fig.update_layout(
        xaxis_title=f"Δ NLOC ({right} − {left})",
        yaxis_title=f"Δ avg CC ({right} − {left})",
        margin=dict(l=10, r=10, t=40, b=10),
    )
    fig.add_hline(y=0, line_dash="dot", line_color="gray")
    fig.add_vline(x=0, line_dash="dot", line_color="gray")
    show_chart(fig, filename=f"diff-{left}-to-{right}")
