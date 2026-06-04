FROM debian:bookworm-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        gzip \
        xz-utils \
        bzip2 \
        jq \
        gawk \
        make \
        gnuplot-nox \
        pmccabe \
        python3 \
        python3-pip \
        ca-certificates \
        debootstrap \
        debian-archive-keyring \
    && rm -rf /var/lib/apt/lists/*

# Install tokei from GitHub release (multi-arch)
ARG TARGETARCH
ARG TOKEI_VERSION=12.1.2
RUN case "${TARGETARCH}" in \
        amd64) TOKEI_ARCH="x86_64-unknown-linux-gnu" ;; \
        arm64) TOKEI_ARCH="aarch64-unknown-linux-gnu" ;; \
        *)     echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -sSL "https://github.com/XAMPPRocky/tokei/releases/download/v${TOKEI_VERSION}/tokei-${TOKEI_ARCH}.tar.gz" \
    | tar xz -C /usr/local/bin tokei \
    && chmod +x /usr/local/bin/tokei

# Install Python dependencies
RUN pip3 install --no-cache-dir --break-system-packages openpyxl

WORKDIR /workspace

# Copy pipeline code (data/results/figures are bind-mounted at runtime)
COPY Makefile .
COPY scripts/ scripts/

CMD ["make", "help"]
