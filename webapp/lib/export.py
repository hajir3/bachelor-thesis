"""Render a Plotly chart full-width with a vector-SVG download button.

The in-browser modebar camera button defaults to raster PNG; here it is
reconfigured to emit vector SVG, which scales losslessly and converts to PDF
for LaTeX inclusion (see `make pdf` / `thesis/convert_svg_to_pdf.sh`). Routing
every chart through `show_chart` keeps that download configuration consistent
across all pages.
"""
from __future__ import annotations

import re

import plotly.graph_objects as go
import streamlit as st


def _slug(text: str) -> str:
    """Filesystem-safe download stem (lowercase, dashes, no exotic chars)."""
    s = re.sub(r"[^A-Za-z0-9._-]+", "-", str(text).strip().lower())
    return s.strip("-._") or "chart"


def show_chart(fig: go.Figure, *, filename: str) -> None:
    """Render `fig` full-width; its modebar download button emits SVG.

    `filename` is the SVG download stem (without extension); it is slugified.
    """
    st.plotly_chart(
        fig,
        width="stretch",
        config={
            "displaylogo": False,
            "toImageButtonOptions": {"format": "svg", "filename": _slug(filename)},
        },
    )
