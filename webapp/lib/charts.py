"""Reusable Plotly figure builders."""
from __future__ import annotations

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go

from .config import RELEASE_ORDER


def line_over_releases(
    df: pd.DataFrame,
    y: str,
    *,
    title: str = "",
    y_label: str | None = None,
    color: str | None = None,
    log_y: bool = False,
    y_min: float | None = None,
    hover_data: list[str] | dict | None = None,
    labels: dict | None = None,
) -> go.Figure:
    """Single line (or grouped lines via `color`) across the release axis.

    `hover_data` adds extra columns to the hover box; `labels` renames fields
    (e.g. {"codename": "Release"}) in the hover and legend. Axis titles are set
    explicitly below, so `labels` only affects hover/legend text, not the axes.
    """
    fig = px.line(
        df,
        x="codename",
        y=y,
        color=color,
        markers=True,
        category_orders={"codename": RELEASE_ORDER},
        title=title,
        hover_data=hover_data,
        labels=labels,
    )
    fig.update_layout(
        xaxis_title="Debian release",
        yaxis_title=y_label or y,
        legend_title_text=color or "",
        margin=dict(l=10, r=10, t=40, b=10),
    )
    if log_y:
        fig.update_yaxes(type="log")
    if y_min is not None:
        fig.update_yaxes(autorangeoptions=dict(minallowed=y_min))
    # Disable y-axis pan/zoom (scroll); the categorical x-axis stays interactive.
    fig.update_yaxes(fixedrange=True)
    return fig


def bar_over_releases(
    df: pd.DataFrame,
    y: str,
    *,
    title: str = "",
    y_label: str | None = None,
    hover_data: list[str] | dict | None = None,
    labels: dict | None = None,
) -> go.Figure:
    fig = px.bar(
        df,
        x="codename",
        y=y,
        category_orders={"codename": RELEASE_ORDER},
        title=title,
        hover_data=hover_data,
        labels=labels,
    )
    fig.update_layout(
        xaxis_title="Debian release",
        yaxis_title=y_label or y,
        margin=dict(l=10, r=10, t=40, b=10),
    )
    fig.update_yaxes(fixedrange=True)
    return fig


def dual_axis_over_releases(
    df: pd.DataFrame,
    y_primary: str,
    y_secondary: str,
    *,
    title: str = "",
    primary_label: str | None = None,
    secondary_label: str | None = None,
    log_primary: bool = False,
    y_min_primary: float | None = None,
) -> go.Figure:
    """Two y-axes against the same release x-axis."""
    fig = go.Figure()
    fig.add_trace(
        go.Scatter(
            x=df["codename"],
            y=df[y_primary],
            name=primary_label or y_primary,
            mode="lines+markers",
        )
    )
    fig.add_trace(
        go.Scatter(
            x=df["codename"],
            y=df[y_secondary],
            name=secondary_label or y_secondary,
            mode="lines+markers",
            yaxis="y2",
        )
    )
    fig.update_layout(
        title=title,
        xaxis=dict(title="Debian release", categoryorder="array", categoryarray=RELEASE_ORDER),
        yaxis=dict(
            title=primary_label or y_primary,
            type="log" if log_primary else "linear",
            fixedrange=True,
            **({"autorangeoptions": dict(minallowed=y_min_primary)} if y_min_primary is not None else {}),
        ),
        yaxis2=dict(
            title=secondary_label or y_secondary,
            overlaying="y",
            side="right",
            fixedrange=True,
        ),
        margin=dict(l=10, r=10, t=40, b=10),
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
    )
    return fig


def stacked_area_languages(df: pd.DataFrame, *, title: str = "") -> go.Figure:
    """`language_by_release` wide-form -> stacked area chart."""
    langs = [c for c in df.columns if c not in {"codename", "year"}]
    long = df.melt(
        id_vars=["codename", "year"],
        value_vars=langs,
        var_name="language",
        value_name="nloc",
    )
    fig = px.area(
        long,
        x="codename",
        y="nloc",
        color="language",
        category_orders={"codename": RELEASE_ORDER},
        title=title,
    )
    fig.update_layout(
        xaxis_title="Debian release",
        yaxis_title="NLOC",
        margin=dict(l=10, r=10, t=40, b=10),
    )
    fig.update_yaxes(fixedrange=True)
    return fig
