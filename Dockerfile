# Biomni E1 Environment Dockerfile
# Based on miniconda with full bioinformatics toolset
#
# Build: docker build -t biomni:e1 .
# Run:   docker-compose up -d
#
# Layer caching strategy (top = changes least, bottom = changes most):
#   1. System packages (rarely change)
#   2. Conda base environment (environment.yml)
#   3. Conda bio packages (bio_env.yml)
#   4. Conda R packages (r_packages.yml)
#   5. R CRAN packages + CLI tools
#   6. Python package install (pyproject.toml — dependencies only)
#   7. Application code (biomni/, scripts/ — changes most often)

FROM continuumio/miniconda3:24.11.1-0

LABEL maintainer="Hannes Bretschneider <hannes@katalyzeai.com>"
LABEL description="Biomni E1 bioinformatics environment with conda, R, and CLI tools"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# ── Layer 1: System packages (rarely changes) ───────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    gfortran \
    make \
    cmake \
    git \
    curl \
    wget \
    unzip \
    jq \
    zlib1g-dev \
    libbz2-dev \
    liblzma-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libpng-dev \
    libjpeg-dev \
    libtiff-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libgit2-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libhdf5-dev \
    libffi-dev \
    libsqlite3-dev \
    libreadline-dev \
    perl \
    && rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /app

# Install mamba for faster dependency resolution
RUN conda install -n base -c conda-forge mamba && \
    conda clean -afy

# ── Layer 2-3: Conda environments (change when yml files change) ─
COPY biomni_env/environment.yml /app/biomni_env/environment.yml
COPY biomni_env/bio_env.yml /app/biomni_env/bio_env.yml
COPY biomni_env/r_packages.yml /app/biomni_env/r_packages.yml
COPY biomni_env/install_r_packages.R /app/biomni_env/install_r_packages.R
COPY biomni_env/cli_tools_config.json /app/biomni_env/cli_tools_config.json
COPY biomni_env/install_cli_tools.sh /app/biomni_env/install_cli_tools.sh

RUN mamba env create -n biomni_e1 -f /app/biomni_env/environment.yml && \
    conda clean -afy

RUN conda init bash

RUN mamba env update -n biomni_e1 -f /app/biomni_env/bio_env.yml && \
    conda clean -afy

# ── Layer 4: R packages ─────────────────────────────────────
RUN mamba env update -n biomni_e1 -f /app/biomni_env/r_packages.yml && \
    conda clean -afy

SHELL ["/bin/bash", "-c"]
RUN source /opt/conda/etc/profile.d/conda.sh && \
    conda activate biomni_e1 && \
    Rscript /app/biomni_env/install_r_packages.R || true

# ── Layer 5: CLI bioinformatics tools ────────────────────────
ENV BIOMNI_TOOLS_DIR=/app/biomni_tools
ENV BIOMNI_AUTO_INSTALL=1
ENV NON_INTERACTIVE=1

RUN source /opt/conda/etc/profile.d/conda.sh && \
    conda activate biomni_e1 && \
    cd /app/biomni_env && \
    bash install_cli_tools.sh --auto || true

ENV PATH="/app/biomni_tools/bin:${PATH}"

# ── Layer 6: Python package dependencies (pyproject.toml) ────
# Copy only dependency metadata first so `pip install` is cached
# unless pyproject.toml itself changes.
COPY pyproject.toml /app/pyproject.toml
COPY biomni/version.py /app/biomni/version.py
COPY biomni/__init__.py /app/biomni/__init__.py

RUN source /opt/conda/etc/profile.d/conda.sh && \
    conda activate biomni_e1 && \
    pip install --no-cache-dir -e ".[gradio]" && \
    pip install --no-cache-dir fastapi uvicorn[standard] && \
    pip install --force-reinstall --no-cache-dir "numpy==1.26.4" && \
    pip install --force-reinstall --no-cache-dir --no-deps "pandas==2.2.3"

# ── Layer 7: Application code (changes most often) ──────────
# This layer rebuilds on any code change, but all heavy installs
# above are cached.
COPY . /app/

# Create entrypoint script
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'source /opt/conda/etc/profile.d/conda.sh' >> /entrypoint.sh && \
    echo 'conda activate biomni_e1' >> /entrypoint.sh && \
    echo 'exec "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Set the default shell to bash with conda activated
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]

# Expose ports: Jupyter, Gradio UI, FastAPI REST API
EXPOSE 8888 7860 8000
