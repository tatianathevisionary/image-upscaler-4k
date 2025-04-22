FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    TZ=UTC

# Pre-configure tzdata package
RUN echo "tzdata tzdata/Areas select Etc" | debconf-set-selections && \
    echo "tzdata tzdata/Zones/Etc select UTC" | debconf-set-selections

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3-pip \
    wget \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    ffmpeg \
    tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Create directories
RUN mkdir -p /workspace/input /workspace/output /workspace/models

# Download model
ARG MODEL_NAME=RealESRGAN_x4plus
ENV MODEL_PATH=/workspace/models/${MODEL_NAME}.pth
RUN wget https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/${MODEL_NAME}.pth -P /workspace/models/

# Copy application files
COPY upscaler.py runpod_handler.py ./

# Environment variables
ENV CUDA_VISIBLE_DEVICES=0 \
    PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:4096 \
    PYTHONUNBUFFERED=1

# Create and set permissions for cache and logs
RUN mkdir -p /workspace/.cache/torch/hub/checkpoints && \
    mkdir -p /workspace/logs && \
    chmod -R 777 /workspace/.cache && \
    chmod -R 777 /workspace/logs

# Create startup script with improved logging
RUN echo '#!/bin/bash\n\
echo "[$(date)] Starting container..." >> /workspace/logs/startup.log\n\
echo "[$(date)] Python version:" >> /workspace/logs/startup.log\n\
python3 --version 2>&1 | tee -a /workspace/logs/startup.log\n\
echo "[$(date)] PyTorch version:" >> /workspace/logs/startup.log\n\
python3 -c "import torch; print(torch.__version__)" 2>&1 | tee -a /workspace/logs/startup.log\n\
echo "[$(date)] CUDA available:" >> /workspace/logs/startup.log\n\
python3 -c "import torch; print(torch.cuda.is_available())" 2>&1 | tee -a /workspace/logs/startup.log\n\
echo "[$(date)] Starting handler..." >> /workspace/logs/startup.log\n\
exec python3 -u runpod_handler.py 2>&1 | tee -a /workspace/logs/handler.log\n\
' > /workspace/start.sh && chmod +x /workspace/start.sh

# Simple healthcheck that doesn't require GPU during build
HEALTHCHECK --interval=30s --timeout=30s --start-period=60s --retries=3 \
    CMD python3 -c "import torch; import os; import cv2; \
    print('Checking dependencies...'); \
    print(f'PyTorch version: {torch.__version__}'); \
    print(f'OpenCV version: {cv2.__version__}'); \
    assert os.path.exists('${MODEL_PATH}'), 'Model not found'; \
    print('All checks passed')"

# Start the handler with logging
CMD ["/workspace/start.sh"]