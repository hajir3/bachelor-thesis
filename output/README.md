# Output directory

All pipeline artifacts live under `output/`. The pipeline is orchestrated by the top-level `Makefile` and `scripts/lib/common.sh::init_run()`.

## Layout

```
output/
├── data/                  # intermediate downloads and parsed inputs (cleaned by `make clean`)
│   ├── packages/<release>/{Packages,Packages.gz}      # binary package indices
│   ├── sources_idx/<release>/{Sources,Sources.gz}     # source package indices
│   ├── source_tarballs/<release>/                     # upstream .orig.tar.* and Debian .debian.tar.* / .diff.gz; Debian-native packages (e.g. dpkg, debconf) ship one combined <name>_<ver>.tar.* with no .orig/.debian split
│   └── parsed/<release>_{packages,sources}.csv, <release>_minbase.txt
├── results/<N>_<commit>_<dd.mm.yyyy>_<hh.mm>/         # versioned analysis CSVs (preserved across cleans)
└── figures/<N>_<commit>_<dd.mm.yyyy>_<hh.mm>/         # versioned gnuplot PDFs    (preserved across cleans)
```

- **data/** — regeneratable from Debian mirrors; safe to delete. `make clean` removes this subtree and the `output/.current_run` marker, leaving `results/` and `figures/` intact.
- **results/** and **figures/** — one versioned subdirectory per pipeline run, preserved as historical record.

## Run-directory naming

Each `make all` creates a new subdirectory under both `results/` and `figures/` named:

```
<N>_<commit>_<dd.mm.yyyy>_<hh.mm>
```

- **N** — globally incrementing run counter across `results/` and `figures/`; never reused.
- **commit** — short Git hash (`git rev-parse --short HEAD`) of the code that produced the run.
- **dd.mm.yyyy_hh.mm** — local date and time when `init_run` created the directory.

Example: `9_640d985_22.04.2026_13.43` is run #9, built from commit `640d985`, started on 22 April 2026 at 13:43.

Older directories may use the legacy `<N>_<commit>` form without the timestamp suffix. The naming logic lives in `init_run()` in `scripts/lib/common.sh`.

The final thesis run shipped in this repository was renamed from its auto-generated name to `BA-Submission`; it is the only run directory present under `results/` and `figures/`.
