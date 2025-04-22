FROM pytorch/pytorch:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    python3-pip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Create directories for processing and models
RUN mkdir -p /workspace/input /workspace/output /workspace/models

# Define model name and download URL
ARG MODEL_NAME=RealESRGAN_x4plus
ENV MODEL_URL=https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/${MODEL_NAME}.pth

# Download the model file
RUN wget ${MODEL_URL} -P /workspace/models/

# Copy the rest of the application
COPY upscaler.py .
COPY runpod_handler.py .

# Environment variables for RTX A5000 optimization
ENV MODEL_PATH=/workspace/models/${MODEL_NAME}.pth
ENV CUDA_VISIBLE_DEVICES=0
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:4096
ENV CUDA_LAUNCH_BLOCKING=0
ENV TORCH_CUDA_ARCH_LIST="8.6"
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

# Set up cache directories
RUN mkdir -p /workspace/.cache/torch/hub/checkpoints && \
    chmod -R 777 /workspace/.cache

# Verify CUDA installation and GPU access
RUN python3 -c "import torch; assert torch.cuda.is_available(), 'CUDA is not available'"

# Healthcheck with more detailed diagnostics
HEALTHCHECK --interval=30s --timeout=30s --start-period=60s --retries=3 \
    CMD python3 -c "\
    import torch; \
    import os; \
    assert torch.cuda.is_available(), 'CUDA not available'; \
    assert torch.cuda.device_count() > 0, 'No GPU devices'; \
    assert os.path.exists('${MODEL_PATH}'), 'Model not found'; \
    t = torch.zeros(1).cuda(); \
    del t; \
    torch.cuda.empty_cache(); \
    print('Healthcheck passed')"

# Default command with increased logging
CMD [ "python3", "-u", "runpod_handler.py" ] 