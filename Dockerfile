FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

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

# Set up cache directories
RUN mkdir -p /workspace/.cache/torch/hub/checkpoints && \
    chmod -R 777 /workspace/.cache

# Basic verification that PyTorch is installed
RUN python3 -c "import torch; print(f'PyTorch version: {torch.__version__}')"

# Healthcheck script
COPY <<'EOF' /workspace/healthcheck.py
import torch
import os
import sys

def run_checks():
    try:
        print('Checking PyTorch installation...')
        print(f'PyTorch version: {torch.__version__}')
        
        if not torch.cuda.is_available():
            print('CUDA is not available')
            sys.exit(1)
            
        print(f'CUDA available: {torch.cuda.is_available()}')
        print(f'GPU devices: {torch.cuda.device_count()}')
        print(f'GPU name: {torch.cuda.get_device_name(0)}')
        
        model_path = os.getenv('MODEL_PATH')
        if not os.path.exists(model_path):
            print(f'Model not found at {model_path}')
            sys.exit(1)
            
        print('Testing GPU memory allocation...')
        t = torch.zeros(1).cuda()
        del t
        torch.cuda.empty_cache()
        
        print('All checks passed successfully!')
        sys.exit(0)
    except Exception as e:
        print(f'Check failed: {str(e)}')
        sys.exit(1)

if __name__ == '__main__':
    run_checks()
EOF

# Make healthcheck script executable
RUN chmod +x /workspace/healthcheck.py

# Healthcheck configuration
HEALTHCHECK --interval=30s --timeout=30s --start-period=60s --retries=3 \
    CMD python3 /workspace/healthcheck.py

# Default command with increased logging
CMD [ "python3", "-u", "runpod_handler.py" ] 