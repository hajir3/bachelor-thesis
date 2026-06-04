# Debian Bloat Explorer (webapp)

Interactive companion to the BA thesis on software bloat in Debian. Reads the
CSVs that the gnuplot pipeline produces and exposes them through four
Streamlit pages.

This is a **companion artifact**: the thesis itself relies on the static
PDFs in `output/figures/`. The webapp adds drill-down and filtering for
readers who want to explore the data themselves.

## Stack

- Streamlit (multi-page app)
- Plotly (interactive charts)
- pandas (CSV loading + filtering)

No backend, no database. Pure Python reading the same CSV files as gnuplot.

## Quick start

From the repo root:

```bash
make webapp-install   # one-time: create venv at webapp/.venv, install deps
make webapp-link      # symlink webapp/data to the latest output/results/<N>_*/
make webapp           # launch Streamlit at http://localhost:8501
```

`make webapp` runs `webapp-install` and `webapp-link` automatically when
needed; you can call it directly the first time.

### Pointing at a different pipeline run

Either re-run `make webapp-link` after a new pipeline run, or set
`BA_DATA_DIR` to an absolute path:

```bash
BA_DATA_DIR=/path/to/output/results/16_35e4c92_13.05.2026_07.14 \
  webapp/.venv/bin/streamlit run webapp/app.py
```

## Deployment (Streamlit Community Cloud)

The public instance serves the pinned thesis run
`output/results/BA-Submission/` so the numbers match the thesis
permanently, independent of any later pipeline runs. Resolution order in
`lib/config.py::resolve_data_dir()`: `$BA_DATA_DIR` → `webapp/data`
symlink → pinned `BA-Submission` → newest run. On a fresh clone (as on
Streamlit Cloud, where the gitignored symlink does not exist) the pinned
run is what resolves.

Deploy settings:

- **Repository**: this repo (must be public)
- **Main file path**: `webapp/app.py`
- **Python version**: 3.12 (advanced settings)
- Dependencies come from the root `requirements.txt`, which includes
  `webapp/requirements.txt` (pinned versions for reproducibility).

## Pages

| Page                | What it shows                                                    |
|---------------------|------------------------------------------------------------------|
| Release Timeline    | Any metric (NLOC, CC, patches, sizes, deps) across 13 releases  |
| Package Explorer    | Per-package history: NLOC, CC, patches, dependencies, languages |
| Minbase Snapshot    | One release, filterable table with CSV export                   |
| Release Diff        | Two-release comparison: adds/removes, deltas, scatter           |

## Data contract

The webapp reads the following CSVs from the resolved data directory.
Column names are mirrored in `webapp/lib/data.py` — update both together if
the pipeline schema changes.

```
complexity_by_release.csv    complexity_detail.csv     complexity_functions.csv
complexity_max_functions.csv dependency_counts.csv     dependency_lists.csv
installed_sizes.csv          language_by_release.csv   package_counts.csv
patch_sizes.csv              patch_summary.csv         persistent_packages.csv
persistent_top5_nloc.csv     source_to_binaries.csv    tokei_by_release.csv
tokei_summary.csv
```

## Out of scope

- No authentication. Runs locally via `streamlit run` or as a public
  read-only instance on Streamlit Community Cloud (see Deployment).
- No new analysis or new CSVs — consumes pipeline output as-is.
- No dependency-graph network visualisation (only counts are available).
- Mentioned in the thesis (introduction deliverables and conclusion) as a
  companion artifact; the thesis argument itself relies only on the static
  figures.
