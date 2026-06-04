"""Path resolution and release ordering for the webapp."""
from __future__ import annotations

import os
from pathlib import Path

WEBAPP_ROOT = Path(__file__).resolve().parent.parent
REPO_ROOT = WEBAPP_ROOT.parent

# The run this app is pinned to when no explicit override is given. The thesis
# references the deployed app, so it must keep serving the exact data the
# thesis was written against (the final submission run), not whatever run
# happens to be newest on disk.
PINNED_RUN = "BA-Submission"

RELEASE_ORDER: list[str] = [
    "potato", "woody", "sarge", "etch", "lenny", "squeeze",
    "wheezy", "jessie", "stretch", "buster", "bullseye", "bookworm", "trixie",
]

RELEASE_YEAR: dict[str, int] = {
    "potato": 2000, "woody": 2002, "sarge": 2005, "etch": 2007, "lenny": 2009,
    "squeeze": 2011, "wheezy": 2013, "jessie": 2015, "stretch": 2017,
    "buster": 2019, "bullseye": 2021, "bookworm": 2023, "trixie": 2025,
}


def resolve_data_dir() -> Path:
    """Return the directory holding the pipeline CSVs.

    Resolution order:
      1. $BA_DATA_DIR
      2. webapp/data symlink (created by `make webapp-link`)
      3. output/results/BA-Submission (the pinned thesis run; the only
         path that exists on a fresh clone, e.g. on Streamlit Cloud,
         where the gitignored symlink is absent)
      4. newest output/results/<N>_<commit>_*/ in the repo
    """
    env = os.environ.get("BA_DATA_DIR")
    if env:
        p = Path(env).expanduser().resolve()
        if p.is_dir():
            return p

    symlink = WEBAPP_ROOT / "data"
    if symlink.exists():
        return symlink.resolve()

    results = REPO_ROOT / "output" / "results"
    pinned = results / PINNED_RUN
    if pinned.is_dir():
        return pinned

    if results.is_dir():
        candidates = sorted(
            (d for d in results.iterdir() if d.is_dir()),
            key=lambda d: d.stat().st_mtime,
            reverse=True,
        )
        if candidates:
            return candidates[0]

    raise FileNotFoundError(
        "No pipeline data found. Run `make webapp-link` or set BA_DATA_DIR."
    )
