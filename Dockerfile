FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3-pip \
    wget \
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
ENV CUDA_VISIBLE_DEVICES=0
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:4096

# Create and set permissions for cache
RUN mkdir -p /workspace/.cache/torch/hub/checkpoints && \
    chmod -R 777 /workspace/.cache

# Simple healthcheck that doesn't require GPU during build
HEALTHCHECK --interval=30s --timeout=30s --start-period=60s --retries=3 \
    CMD python3 -c "import torch; import os; assert os.path.exists('${MODEL_PATH}'), 'Model not found'"

# Start the handler
CMD ["python3", "-u", "runpod_handler.py"]