FROM pytorch/pytorch:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy the rest of the application
COPY upscaler.py .
COPY runpod_handler.py .

# Create directories for processing
RUN mkdir -p /workspace/input /workspace/output

# Default command
CMD [ "python3", "-u", "runpod_handler.py" ] 