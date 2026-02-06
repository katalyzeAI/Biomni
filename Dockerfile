# Biomni E1 Environment Dockerfile
# Based on miniconda with full bioinformatics toolset
#
# Build: docker build -t biomni:e1 .
# Run:   docker-compose up -d

FROM continuumio/miniconda3:24.11.1-0

LABEL maintainer="Hannes Bretschneider <hannes@katalyzeai.com>"
LABEL description="Biomni E1 bioinformatics environment with conda, R, and CLI tools"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install system dependencies required for bioinformatics tools
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

# Copy environment files first (for layer caching)
COPY biomni_env/environment.yml /app/biomni_env/environment.yml
COPY biomni_env/bio_env.yml /app/biomni_env/bio_env.yml
COPY biomni_env/r_packages.yml /app/biomni_env/r_packages.yml
COPY biomni_env/install_r_packages.R /app/biomni_env/install_r_packages.R
COPY biomni_env/cli_tools_config.json /app/biomni_env/cli_tools_config.json
COPY biomni_env/install_cli_tools.sh /app/biomni_env/install_cli_tools.sh

# Create the base conda environment
RUN conda env create -n biomni_e1 -f /app/biomni_env/environment.yml && \
    conda clean -afy

# Initialize conda for bash
RUN conda init bash

# Install bioinformatics packages into the environment
# Note: This is done separately for better layer caching
RUN conda env update -n biomni_e1 -f /app/biomni_env/bio_env.yml && \
    conda clean -afy

# Install R and R packages
RUN conda env update -n biomni_e1 -f /app/biomni_env/r_packages.yml && \
    conda clean -afy

# Activate environment and install additional R packages via R's package manager
SHELL ["/bin/bash", "-c"]
RUN source /opt/conda/etc/profile.d/conda.sh && \
    conda activate biomni_e1 && \
    Rscript /app/biomni_env/install_r_packages.R || true

# Set up CLI tools directory
ENV BIOMNI_TOOLS_DIR=/app/biomni_tools
ENV BIOMNI_AUTO_INSTALL=1
ENV NON_INTERACTIVE=1

# Install CLI bioinformatics tools
RUN source /opt/conda/etc/profile.d/conda.sh && \
    conda activate biomni_e1 && \
    cd /app/biomni_env && \
    bash install_cli_tools.sh --auto || true

# Add CLI tools to PATH
ENV PATH="/app/biomni_tools/bin:${PATH}"

# Copy the rest of the application
COPY . /app/

# Install FastAPI + uvicorn for the REST API
RUN source /opt/conda/etc/profile.d/conda.sh && \
    conda activate biomni_e1 && \
    pip install --no-cache-dir fastapi uvicorn[standard]

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
