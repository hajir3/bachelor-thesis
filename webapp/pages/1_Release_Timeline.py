"""Release Timeline — one chart, many metrics across all releases."""
from __future__ import annotations

import pandas as pd
import streamlit as st

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lib.charts import (  # noqa: E402
    bar_over_releases,
    dual_axis_over_releases,
    line_over_releases,
    stacked_area_languages,
)
from lib.export import show_chart  # noqa: E402
from lib.data import (  # noqa: E402
    load_complexity_by_release,
    load_dependency_counts,
    load_installed_sizes,
    load_language_by_release,
    load_package_counts,
    load_patch_summary,
    load_tokei_by_release,
    max_cc_owner_by_release,
)

st.set_page_config(page_title="Release Timeline", layout="wide")
st.title("Release Timeline")
st.caption("Pick a metric and inspect its evolution across all Debian releases.")

# Metric registry: label -> (loader, column, y_label, chart, log_y, secondary_default)
METRICS: dict[str, dict] = {
    "Minbase package count": dict(
        loader=load_package_counts, y="minbase_count",
        y_label="Source packages in minbase", chart="bar", unit="Packages",
    ),
    "Minbase installed size (KiB)": dict(
        loader=load_package_counts, y="minbase_installed_kb",
        y_label="Installed size (KiB)", chart="line", unit="Installed size (KiB)",
    ),
    "Persistent-only installed size (KiB)": dict(
        loader=load_installed_sizes, y="persistent_only_kb",
        y_label="Installed size (KiB)", chart="line", unit="Installed size (KiB)",
    ),
    "Average cyclomatic complexity": dict(
        loader=load_complexity_by_release, y="avg_cc",
        y_label="Avg CC per function", chart="line", y_min=1, unit="CC per function",
    ),
    "Median cyclomatic complexity": dict(
        loader=load_complexity_by_release, y="median_cc",
        y_label="Median CC per function", chart="line", y_min=1, unit="CC per function",
    ),
    "Maximum cyclomatic complexity": dict(
        loader=load_complexity_by_release, y="max_cc",
        y_label="Max CC per function", chart="line", y_min=1, unit="CC per function",
    ),
    "Total functions analysed": dict(
        loader=load_complexity_by_release, y="total_functions",
        y_label="Functions", chart="line",
    ),
    "Total NLOC": dict(
        loader=load_tokei_by_release, y="total_code",
        y_label="Lines of code", chart="line",
    ),
    "Total patch lines": dict(
        loader=load_patch_summary, y="total_patch_lines",
        y_label="Patch lines", chart="bar",
    ),
    "Packages with Debian patches": dict(
        loader=load_patch_summary, y="num_packages_with_patches",
        y_label="Packages with patches", chart="bar", unit="Packages",
    ),
}

col_left, col_right = st.columns([1, 3])
with col_left:
    metric = st.selectbox("Primary metric", list(METRICS.keys()), index=3)
    show_secondary = st.checkbox("Compare against another metric (secondary axis)")
    secondary = None
    if show_secondary:
        options = [m for m in METRICS if m != metric]
        secondary = st.selectbox("Secondary metric", options, index=options.index("Total functions analysed") if "Total functions analysed" in options else 0)
    show_language_breakdown = st.checkbox("Show language breakdown (stacked area)")

with col_right:
    spec = METRICS[metric]
    df = spec["loader"]()
    if show_secondary and secondary:
        sec = METRICS[secondary]
        # Merge if loaders differ
        if sec["loader"] is spec["loader"]:
            merged = df
        else:
            right = sec["loader"]()[["codename", sec["y"]]]
            merged = df.merge(right, on="codename", how="inner")
        # Same unit -> one shared y-axis (honest magnitude comparison);
        # different units -> dual axis (trend comparison only).
        same_unit = spec.get("unit") is not None and spec.get("unit") == sec.get("unit")
        if same_unit:
            long = merged.melt(
                id_vars=["codename"],
                value_vars=[spec["y"], sec["y"]],
                var_name="metric",
                value_name="value",
            )
            long["metric"] = long["metric"].map({spec["y"]: metric, sec["y"]: secondary})
            fig = line_over_releases(
                long,
                y="value",
                color="metric",
                title=f"{metric} vs {secondary}",
                y_label=spec["unit"],
                log_y=spec.get("log_y", False),
                y_min=spec.get("y_min"),
                labels={"codename": "Release", "value": spec["unit"], "metric": "Metric"},
            )
        else:
            fig = dual_axis_over_releases(
                merged,
                y_primary=spec["y"],
                y_secondary=sec["y"],
                title=f"{metric} vs {secondary}",
                primary_label=spec["y_label"],
                secondary_label=sec["y_label"],
                log_primary=spec.get("log_y", False),
                y_min_primary=spec.get("y_min"),
            )
    elif spec["chart"] == "bar":
        fig = bar_over_releases(
            df, y=spec["y"], title=metric, y_label=spec["y_label"],
            labels={"codename": "Release", spec["y"]: spec["y_label"]},
        )
    else:
        df_plot = df
        labels = {"codename": "Release", spec["y"]: spec["y_label"]}
        hover_data = None
        # Enrich the Max-CC hover with the source package owning that release's
        # most complex function (perl in every release except potato/bash), plus
        # the file + function name when the pipeline has captured them.
        if metric == "Maximum cyclomatic complexity":
            owner = max_cc_owner_by_release()
            df_plot = df.merge(owner, on="codename", how="left")
            hover_data = ["max_cc_package"]
            labels["max_cc_package"] = "Package"
            if "max_cc_function" in owner.columns:
                hover_data.append("max_cc_function")
                labels["max_cc_function"] = "Function"
            if "max_cc_file" in owner.columns:
                hover_data.append("max_cc_file")
                labels["max_cc_file"] = "File"
        fig = line_over_releases(
            df_plot, y=spec["y"], title=metric, y_label=spec["y_label"],
            log_y=spec.get("log_y", False),
            y_min=spec.get("y_min"),
            hover_data=hover_data, labels=labels,
        )
    show_chart(fig, filename=f"timeline-{metric}")

    if show_language_breakdown:
        lang_df = load_language_by_release()
        show_chart(
            stacked_area_languages(lang_df, title="NLOC by language across releases"),
            filename="nloc-by-language",
        )
