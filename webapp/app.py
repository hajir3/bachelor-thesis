"""Debian Bloat Explorer — Streamlit landing page.

Run with `make webapp` from the repo root, or `streamlit run app.py` from
inside `webapp/`.
"""
from __future__ import annotations

import streamlit as st

from lib.config import resolve_data_dir
from lib.data import (
    load_package_counts,
    load_persistent_packages,
)

st.set_page_config(
    page_title="Debian Bloat Explorer",
    page_icon=":bar_chart:",
    layout="wide",
)

st.title("Debian Bloat Explorer")
st.caption(
    "Interactive companion to the BA thesis on software bloat in Debian. "
    "Reads the same CSVs the gnuplot pipeline produces."
)

try:
    data_dir = resolve_data_dir()
except FileNotFoundError as e:
    st.error(str(e))
    st.stop()

st.sidebar.header("Data source")
st.sidebar.code(data_dir.name, language="text")
st.sidebar.caption(
    "Override with `BA_DATA_DIR` or run `make webapp-link` to point at the "
    "most recent pipeline run."
)

pkg = load_package_counts()
persistent = load_persistent_packages()

col1, col2, col3, col4 = st.columns(4)
col1.metric("Releases covered", len(pkg))
col2.metric("Earliest", f"{pkg.iloc[0]['codename']} ({pkg.iloc[0]['year']})")
col3.metric("Latest", f"{pkg.iloc[-1]['codename']} ({pkg.iloc[-1]['year']})")
col4.metric("Persistent packages", len(persistent))

st.divider()
st.subheader("Views")
st.markdown(
    """
- **Release Timeline** — pick any metric (NLOC, cyclomatic complexity, patch
  volume, minbase size, …) and see it across all 13 releases.
- **Package Explorer** — choose a single source package and trace its NLOC,
  complexity, patch lines, and dependencies across releases.
- **Minbase Snapshot** — pick a release and filter the minbase package set by
  persistence, patches, complexity, NLOC, or language. Export the filtered
  view as CSV.
- **Release Diff** — compare two releases side-by-side: package additions and
  removals, summary deltas, and per-package metric scatter.
"""
)

st.info(
    "Use the page selector in the sidebar to navigate. Hover charts for "
    "exact values, drag to zoom, double-click to reset."
)
