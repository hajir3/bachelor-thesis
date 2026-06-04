"""Cached CSV loaders for pipeline outputs.

Every loader returns a pandas DataFrame whose `codename` column (when present)
is a categorical ordered by `RELEASE_ORDER` so charts and tables sort
chronologically without extra logic.
"""
from __future__ import annotations

from pathlib import Path

import pandas as pd
import streamlit as st

from .config import RELEASE_ORDER, resolve_data_dir


def _csv(name: str) -> Path:
    return resolve_data_dir() / name


def _order_releases(df: pd.DataFrame) -> pd.DataFrame:
    if "codename" in df.columns:
        df["codename"] = pd.Categorical(
            df["codename"], categories=RELEASE_ORDER, ordered=True
        )
        df = df.sort_values("codename").reset_index(drop=True)
    return df


@st.cache_data(show_spinner=False)
def load_complexity_by_release() -> pd.DataFrame:
    return _order_releases(pd.read_csv(_csv("complexity_by_release.csv")))


@st.cache_data(show_spinner=False)
def load_complexity_detail() -> pd.DataFrame:
    return _order_releases(pd.read_csv(_csv("complexity_detail.csv")))


@st.cache_data(show_spinner=False)
def load_complexity_functions() -> pd.DataFrame:
    return _order_releases(pd.read_csv(_csv("complexity_functions.csv")))


@st.cache_data(show_spinner=False)
def load_patch_sizes() -> pd.DataFrame:
    return _order_releases(pd.read_csv(_csv("patch_sizes.csv")))


@st.cache_data(show_spinner=False)
def load_patch_summary() -> pd.DataFrame:
    return _order_releases(pd.read_csv(_csv("patch_summary.csv")))


@st.cache_data(show_spinner=False)
def load_installed_sizes() -> pd.DataFrame:
    return _order_releases(pd.read_csv(_csv("installed_sizes.csv")))


@st.cache_data(show_spinner=False)
def load_persistent_packages() -> pd.DataFrame:
    return pd.read_csv(_csv("persistent_packages.csv"))


@st.cache_data(show_spinner=False)
def load_dependency_counts() -> pd.DataFrame:
    return _order_releases(pd.read_csv(_csv("dependency_counts.csv")))


@st.cache_data(show_spinner=False)
def load_tokei_summary() -> pd.DataFrame:
    return _order_releases(pd.read_csv(_csv("tokei_summary.csv")))


@st.cache_data(show_spinner=False)
def load_tokei_by_release() -> pd.DataFrame:
    return _order_releases(pd.read_csv(_csv("tokei_by_release.csv")))


@st.cache_data(show_spinner=False)
def load_language_by_release() -> pd.DataFrame:
    return _order_releases(pd.read_csv(_csv("language_by_release.csv")))


@st.cache_data(show_spinner=False)
def load_package_counts() -> pd.DataFrame:
    return _order_releases(pd.read_csv(_csv("package_counts.csv")))


@st.cache_data(show_spinner=False)
def load_persistent_top5_nloc() -> pd.DataFrame:
    return _order_releases(pd.read_csv(_csv("persistent_top5_nloc.csv")))


@st.cache_data(show_spinner=False)
def load_dependency_lists() -> pd.DataFrame:
    """Per-minbase-binary dependency strings (with names + version constraints)."""
    return _order_releases(pd.read_csv(_csv("dependency_lists.csv")))


@st.cache_data(show_spinner=False)
def load_source_to_binaries() -> pd.DataFrame:
    """Per-release mapping from source package -> semicolon-joined binaries."""
    return _order_releases(pd.read_csv(_csv("source_to_binaries.csv")))


# --- Derived views ----------------------------------------------------------

@st.cache_data(show_spinner=False)
def all_known_packages() -> list[str]:
    """Sorted union of every source_package seen anywhere in the dataset.

    Unions the source-keyed detail tables (which carry the persistent set
    after the step-36 revert) with `dependency_lists.csv`'s `source` column
    (which still covers every minbase binary's upstream source), so the
    picker covers both the persistent core (with full metrics) and the
    wider minbase sources (with dependency data only).
    """
    names: set[str] = set()
    for loader in (load_complexity_detail, load_patch_sizes, load_tokei_summary):
        try:
            df = loader()
        except FileNotFoundError:
            continue
        if "source_package" in df.columns:
            names.update(df["source_package"].dropna().astype(str).unique())
    try:
        deps = load_dependency_lists()
        if "source" in deps.columns:
            names.update(deps["source"].dropna().astype(str).unique())
    except FileNotFoundError:
        pass
    return sorted(names)


@st.cache_data(show_spinner=False)
def load_complexity_max_functions() -> pd.DataFrame | None:
    """Per (release, package) most complex function: file + function name.

    Produced by `analyze_complexity.sh` (columns: codename, year,
    source_package, max_cc, file, func_line, function). Returns None when the
    CSV is absent (data predating the function-capture pipeline step), so
    callers can fall back to package-only enrichment.
    """
    path = _csv("complexity_max_functions.csv")
    if not path.exists():
        return None
    return _order_releases(pd.read_csv(path))


@st.cache_data(show_spinner=False)
def max_cc_owner_by_release() -> pd.DataFrame:
    """Per release, the source package owning the most complex function.

    Returns one row per codename naming the source package whose function
    attains that release's maximum CC (which equals `max_cc` in
    `complexity_by_release.csv` by construction). Always carries column
    `max_cc_package`; when `complexity_max_functions.csv` is present it also
    carries `max_cc_file` and `max_cc_function`. Ties resolve to the first
    package encountered.

    Prefers `complexity_max_functions.csv` (file + function); falls back to
    `complexity_functions.csv` (package only) when that file is absent.
    """
    mf = load_complexity_max_functions()
    if mf is not None and not mf.empty:
        idx = mf.groupby("codename", observed=True)["max_cc"].idxmax()
        owner = (
            mf.loc[idx, ["codename", "source_package", "file", "function"]]
            .rename(
                columns={
                    "source_package": "max_cc_package",
                    "file": "max_cc_file",
                    "function": "max_cc_function",
                }
            )
            .reset_index(drop=True)
        )
        # Strip the ephemeral extraction prefix (/tmp/.../cc_<pid>/) that older
        # pipeline runs stored, leaving a clean "<source>-<version>/path/file.c".
        # No-op once the pipeline writes paths relative to the extraction root.
        owner["max_cc_file"] = (
            owner["max_cc_file"].astype(str).str.replace(r"^.*?/cc_\d+/", "", regex=True)
        )
        return _order_releases(owner)

    df = load_complexity_functions()
    idx = df.groupby("codename", observed=True)["cc"].idxmax()
    owner = (
        df.loc[idx, ["codename", "source_package"]]
        .rename(columns={"source_package": "max_cc_package"})
        .reset_index(drop=True)
    )
    return _order_releases(owner)


@st.cache_data(show_spinner=False)
def package_nloc_by_release() -> pd.DataFrame:
    """Per-package NLOC summed across languages, one row per (codename, package)."""
    df = load_tokei_summary()
    g = (
        df.groupby(["codename", "year", "source_package"], observed=True)["code"]
        .sum()
        .reset_index()
        .rename(columns={"code": "nloc"})
    )
    return _order_releases(g)


@st.cache_data(show_spinner=False)
def binary_minbase_set_by_release() -> pd.DataFrame:
    """Binary packages present in each release's minbase (set membership).

    The diff page uses this to compute the actual added/removed binaries
    between two releases. Source: dependency_counts.csv (one row per
    minbase binary per release).
    """
    df = load_dependency_counts().rename(columns={"package": "binary_package"})
    return df


@st.cache_data(show_spinner=False)
def binaries_for_source(codename: str, source: str) -> list[str]:
    """Look up the binary packages built from `source` in `codename`.

    Returns [] if the source is not present in that release.
    """
    s2b = load_source_to_binaries()
    row = s2b[(s2b["codename"] == codename) & (s2b["source_package"] == source)]
    if row.empty:
        return []
    raw = str(row.iloc[0]["binary_packages"])
    return [b.strip() for b in raw.split(";") if b.strip()]


@st.cache_data(show_spinner=False)
def deps_for_binary(codename: str, binary: str) -> list[str]:
    """Return the dependency strings for a binary package in a release.

    Each list item is one Depends entry with its version constraint preserved
    (e.g. 'libc6 (>= 2.34)'). Returns [] if the binary is not in that
    release's minbase.
    """
    lists = load_dependency_lists()
    row = lists[(lists["codename"] == codename) & (lists["package"] == binary)]
    if row.empty:
        return []
    raw = str(row.iloc[0]["depends"])
    if not raw or raw.strip() in {"", "nan"}:
        return []
    return [d.strip() for d in raw.split(";") if d.strip()]


@st.cache_data(show_spinner=False)
def predeps_for_binary(codename: str, binary: str) -> list[str]:
    """Return the Pre-Depends strings for a binary package in a release.

    Mirrors `deps_for_binary` but reads the `pre_depends` column. Returns []
    if the binary is absent or has no Pre-Depends. Pre-Depends is tracked
    separately from Depends because it is a stronger relation and some
    Essential-set packages (tar, perl-base, hostname) declare dependencies
    only via Pre-Depends.
    """
    lists = load_dependency_lists()
    row = lists[(lists["codename"] == codename) & (lists["package"] == binary)]
    if row.empty:
        return []
    raw = str(row.iloc[0]["pre_depends"])
    if not raw or raw.strip() in {"", "nan"}:
        return []
    return [d.strip() for d in raw.split(";") if d.strip()]


@st.cache_data(show_spinner=False)
def persistent_set() -> set[str]:
    df = load_persistent_packages()
    return set(df["source_package"].astype(str).tolist())
