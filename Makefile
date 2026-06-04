#!/usr/bin/make -f
# Makefile — Orchestrates the Debian complexity analysis pipeline
# Usage (pipeline, runs in Docker):
#   make all            — Build Docker image and run the full pipeline
#   make rerun          — Re-run analyze and plot on cached data into a new run dir
#   make plot           — Re-plot only (PDFs only) into the most recent existing run dir
#   make clean          — Remove intermediate data (keeps results and figures)
#   make benchmark      — Run benchmark in Docker (bookworm)
#
# Thesis assets (local, no Docker):
#   make pdf            — Convert thesis/img/*.svg to PDF and delete the SVGs
#   make sync           — Copy the newest output/figures run into thesis/img
#
# Webapp (interactive companion, runs locally without Docker):
#   make webapp-install — Create webapp/.venv and install dependencies
#   make webapp-link    — Symlink webapp/data to the newest output/results run
#   make webapp         — Launch Streamlit (re-links data to the newest run; set BA_DATA_DIR to pin)
#
#   make help           — Show this command summary

SCRIPTS  := scripts
THESIS   := thesis
OUTPUT   := output
DATA     := $(OUTPUT)/data
RESULTS  := $(OUTPUT)/results
FIGURES  := $(OUTPUT)/figures
IMG      := $(THESIS)/img

# Container settings
DOCKER_IMAGE := debian-complexity
GIT_HASH     ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
DOCKER_RUN   := docker run --rm \
    -e GIT_HASH=$(GIT_HASH) \
    -v $(CURDIR)/$(OUTPUT):/workspace/$(OUTPUT) \
    -v $(CURDIR)/scripts/99_benchmark:/workspace/scripts/99_benchmark \
    $(DOCKER_IMAGE)

.PHONY: all rerun plot clean benchmark \
        _docker-build _check _init-run \
        _download _download-packages _download-sources-idx _download-tarballs \
        _parse _parse-packages _parse-sources _minbase _counts _persistent \
        _analyze _analyze-sizes _analyze-deps _analyze-tokei _analyze-tokei-agg \
        _analyze-patches _analyze-complexity _analyze-init-transition \
        _plot _plot-only _pipeline _benchmark help \
        webapp webapp-link webapp-install pdf sync

# ============================================================
# User-facing targets
# ============================================================

all: _docker-build
	$(DOCKER_RUN) make _pipeline

rerun: _docker-build
	$(DOCKER_RUN) make _pipeline

plot: _docker-build
	$(DOCKER_RUN) make _plot-only

clean:
	rm -rf $(DATA)
	rm -f $(OUTPUT)/.current_run

benchmark: _docker-build
	$(DOCKER_RUN) make _benchmark

# Convert thesis/img/*.svg to vector PDF and delete the SVGs (pdflatex cannot
# embed SVG). Runs on the host, no Docker. No-op when there are no SVGs.
pdf:
	@bash $(THESIS)/scripts/convert_svg_to_pdf.sh

# Copy the newest generated figures into thesis/img/. Resolves the highest-N
# output/figures/<N>_*/ run dir (same "latest" convention as `make plot`) and
# overwrites the same-named PDFs in thesis/img. Manually-maintained figures the
# pipeline does not produce (e.g. bash-patch-lines.pdf, persistent_growth_artefact.pdf)
# are left untouched. Runs on the host, no Docker.
sync:
	@latest=$$(ls -1d $(FIGURES)/[0-9]*_*/ 2>/dev/null | sort -V -r | head -n1); \
	if [ -z "$$latest" ]; then \
		echo "[ERROR] No figure runs found under $(FIGURES). Run 'make all' or 'make plot' first." >&2; \
		exit 1; \
	fi; \
	latest=$${latest%/}; \
	count=$$(ls -1 "$$latest"/*.pdf 2>/dev/null | wc -l | tr -d ' '); \
	if [ "$$count" = "0" ]; then \
		echo "[ERROR] No PDF figures found in $$latest" >&2; \
		exit 1; \
	fi; \
	mkdir -p $(IMG); \
	echo "Copying $$count figure(s) from $$latest -> $(IMG)/"; \
	for f in "$$latest"/*.pdf; do \
		cp -f "$$f" $(IMG)/ && echo "  $$(basename "$$f")"; \
	done; \
	echo "Done."

# ============================================================
# Internal: Docker
# ============================================================

_docker-build:
	docker build -t $(DOCKER_IMAGE) .

# ============================================================
# Internal: Setup
# ============================================================

_check:
	@bash $(SCRIPTS)/00_setup/check_tools.sh

# ============================================================
# Internal: Initialize versioned run directories
# ============================================================

_init-run: _check
	@GIT_HASH=$(GIT_HASH) bash -c 'source $(SCRIPTS)/lib/common.sh && init_run'

# ============================================================
# Internal: Download Phase
# ============================================================

_download-packages: _check
	bash $(SCRIPTS)/01_download/download_packages.sh

_download-sources-idx: _check
	bash $(SCRIPTS)/01_download/download_sources_idx.sh

_download: _download-packages _download-sources-idx

# ============================================================
# Internal: Parse Phase
# ============================================================

_parse-packages: _download-packages
	bash $(SCRIPTS)/02_parse/parse_packages.sh

_parse-sources: _download-sources-idx
	bash $(SCRIPTS)/02_parse/parse_sources.sh

_minbase: _parse-packages
	bash $(SCRIPTS)/02_parse/generate_minbase_lists.sh

_counts: _minbase _init-run
	bash $(SCRIPTS)/02_parse/generate_counts.sh

_persistent: _minbase _init-run
	bash $(SCRIPTS)/02_parse/find_persistent.sh

_parse: _parse-packages _parse-sources _minbase _counts _persistent

# ============================================================
# Internal: Source Tarball Download
# ============================================================

_download-tarballs: _persistent _parse-sources
	bash $(SCRIPTS)/01_download/download_source_tarballs.sh

# ============================================================
# Internal: Analysis Phase
# ============================================================

_analyze-sizes: _parse-packages _persistent _counts
	bash $(SCRIPTS)/03_analyze/analyze_installed_size.sh

_analyze-deps: _parse-packages _init-run
	bash $(SCRIPTS)/03_analyze/analyze_dependencies.sh

_analyze-tokei: _download-tarballs _persistent _init-run
	bash $(SCRIPTS)/03_analyze/analyze_tokei.sh

_analyze-tokei-agg: _analyze-tokei
	bash $(SCRIPTS)/03_analyze/aggregate_tokei.sh

_analyze-patches: _download-tarballs _persistent _init-run
	bash $(SCRIPTS)/03_analyze/analyze_patches.sh

_analyze-complexity: _download-tarballs _persistent _init-run
	bash $(SCRIPTS)/03_analyze/analyze_complexity.sh

_analyze-init-transition: _minbase _init-run
	bash $(SCRIPTS)/03_analyze/aggregate_init_transition.sh

_analyze: _analyze-sizes _analyze-deps _analyze-tokei _analyze-tokei-agg _analyze-patches _analyze-complexity _analyze-init-transition

# ============================================================
# Internal: Plot Phase
# ============================================================

_plot: _analyze
	@bash $(SCRIPTS)/04_plot/run_plots.sh

# Re-plot using the most recent existing run directories (no re-analysis).
_plot-only:
	@bash $(SCRIPTS)/04_plot/run_plots.sh --latest

_pipeline: _plot

# ============================================================
# Internal: Benchmark
# ============================================================

_benchmark: _check
	@bash $(SCRIPTS)/99_benchmark/benchmark.sh bookworm

# ============================================================
# Help
# ============================================================

help:
	@echo "Debian Complexity Analysis Pipeline"
	@echo ""
	@echo "Commands:"
	@echo "  make all            — Build Docker image and run the full pipeline"
	@echo "  make rerun          — Re-run analyze and plot on cached data into a new run dir"
	@echo "  make plot           — Re-plot only (PDFs only) into the most recent existing run dir"
	@echo "  make clean          — Remove intermediate data (keeps results and figures)"
	@echo "  make benchmark      — Run benchmark in Docker (bookworm)"
	@echo ""
	@echo "Thesis assets (local, no Docker):"
	@echo "  make pdf            — Convert thesis/img/*.svg to PDF and delete the SVGs"
	@echo "  make sync           — Copy the newest output/figures run into thesis/img"
	@echo ""
	@echo "Webapp (interactive companion, runs locally without Docker):"
	@echo "  make webapp-install — Create webapp/.venv and install dependencies"
	@echo "  make webapp-link    — Symlink webapp/data to the newest output/results run"
	@echo "  make webapp         — Launch Streamlit (re-links data to the newest run; set BA_DATA_DIR to pin)"
	@echo ""
	@echo "  make help           — Show this command summary"

# ============================================================
# Webapp targets (local, no Docker)
# ============================================================

WEBAPP        := webapp
WEBAPP_VENV   := $(WEBAPP)/.venv
WEBAPP_PYTHON := $(WEBAPP_VENV)/bin/python
WEBAPP_PIP    := $(WEBAPP_VENV)/bin/pip
WEBAPP_ST     := $(WEBAPP_VENV)/bin/streamlit

webapp-install:
	@if [ ! -d "$(WEBAPP_VENV)" ]; then \
		echo "Creating venv at $(WEBAPP_VENV)"; \
		python3 -m venv $(WEBAPP_VENV); \
	fi
	@$(WEBAPP_PIP) install --upgrade pip >/dev/null
	@$(WEBAPP_PIP) install -r $(WEBAPP)/requirements.txt

webapp-link:
	@latest=$$(ls -td $(RESULTS)/*/ 2>/dev/null | head -n1); \
	if [ -z "$$latest" ]; then \
		echo "[ERROR] No pipeline runs found under $(RESULTS). Run 'make all' first." >&2; \
		exit 1; \
	fi; \
	latest=$${latest%/}; \
	rel=$$(python3 -c "import os,sys; print(os.path.relpath('$$latest', '$(WEBAPP)'))"); \
	ln -sfn "$$rel" $(WEBAPP)/data; \
	echo "Linked $(WEBAPP)/data -> $$rel"

webapp: webapp-install
	@if [ -n "$$BA_DATA_DIR" ]; then \
		echo "Using BA_DATA_DIR=$$BA_DATA_DIR (webapp/data symlink ignored)"; \
	else \
		$(MAKE) --no-print-directory webapp-link; \
	fi
	cd $(WEBAPP) && ../$(WEBAPP_ST) run app.py
