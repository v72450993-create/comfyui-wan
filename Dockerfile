# Use multi-stage build with caching optimizations
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 AS base

# Consolidated environment variables
ENV DEBIAN_FRONTEND=noninteractive \
   PIP_PREFER_BINARY=1 \
   PYTHONUNBUFFERED=1 \
   CMAKE_BUILD_PARALLEL_LEVEL=8

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.12 python3.12-venv python3.12-dev \
        python3-pip \
        curl ffmpeg ninja-build git aria2 git-lfs wget vim \
        libgl1 libglib2.0-0 build-essential gcc && \
    ln -sf /usr/bin/python3.12 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    python3.12 -m venv /opt/venv && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Use the virtual environment
ENV PATH="/opt/venv/bin:$PATH"

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --pre torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/nightly/cu128

# Core Python tooling
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install packaging setuptools wheel

# Runtime libraries
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install pyyaml gdown triton comfy-cli jupyterlab jupyterlab-lsp \
        jupyter-server jupyter-server-terminals \
        ipykernel jupyterlab_code_formatter \
        aiohttp

# Stage 2: Builder - Install ComfyUI and custom nodes
FROM base AS builder
# Use the virtual environment
ENV PATH="/opt/venv/bin:$PATH"

# ------------------------------------------------------------
# ComfyUI install
# ------------------------------------------------------------
RUN pip install opencv-python

# Stage 3: Final - Runtime image
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04 AS final
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.12 ffmpeg curl git aria2 git-lfs wget vim libgl1 libglib2.0-0 && \
    ln -sf /usr/bin/python3.12 /usr/bin/python && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /ComfyUI /ComfyUI

ENV PATH="/opt/venv/bin:$PATH"

# Setup CivitAI Downloader
RUN git clone https://github.com/Hearmeman24/CivitAI_Downloader.git && \
    mv CivitAI_Downloader/download_with_aria.py /usr/local/bin/ && \
    chmod +x /usr/local/bin/download_with_aria.py && \
    rm -rf CivitAI_Downloader

COPY src/start.sh /start.sh
RUN chmod +x /start.sh

COPY 4xLSDIR.pth /4xLSDIR.pth

CMD ["/start.sh"]