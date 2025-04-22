# AI Image Upscaler 4K

A Real-ESRGAN based image upscaler optimized for RTX A5000 GPUs on RunPod.

## RunPod Setup Instructions

### 1. Template Setup

1. Go to [RunPod Dashboard](https://www.runpod.io/console/templates)
2. Click on "New Template"
3. Fill in the template settings:
   ```
   Name: AI Image Upscaler 4K
   Container Image: registry.runpod.io/tatianathevisionary-image-upscaler-4k
   ```

4. Set Environment Variables:
   ```
   CUDA_VISIBLE_DEVICES=0
   PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:4096
   CUDA_LAUNCH_BLOCKING=0
   ```

5. Container Settings:
   - Container Disk: 10GB
   - Volume Path: /workspace
   - Volume Size: 10GB

### 2. Worker Configuration

Select these specifications for optimal performance:
- GPU: RTX A5000
- vCPU: 16
- RAM: 62GB
- Container Disk: 10GB
- Volume: 10GB

### 3. Endpoint Setup

1. Go to [RunPod Serverless](https://www.runpod.io/console/serverless)
2. Click on your endpoint
3. Update the configuration:
   - Worker Type: GPU
   - GPU Type: RTX A5000
   - Flash Boot: Enabled
   - Max Workers: 1
   - Idle Timeout: 5 minutes
   - Request Timeout: 300 seconds

### 4. API Usage

Example API request:
```bash
curl -X POST https://api.runpod.ai/v2/b9rcz8azd7gdp7/run \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer YOUR_API_KEY' \
  -d '{"input":{"image":"base64_encoded_image_string"}}'
```

## Troubleshooting

If the worker becomes unhealthy:

1. Stop the current worker:
   - Go to Workers tab
   - Click "Stop" on the unhealthy worker

2. Check logs for errors:
   - Click on the worker ID
   - Go to "Logs" tab
   - Look for error messages

3. Restart with clean state:
   - Stop all workers
   - Clear any pending jobs
   - Start a new worker

## Performance Optimization

Current settings are optimized for RTX A5000:
- Using TF32 for better performance
- Half-precision (FP16) enabled
- Tile size: 512x512
- Memory-efficient mode enabled
- cuDNN benchmarking enabled

## Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| CUDA_VISIBLE_DEVICES | 0 | GPU device to use |
| PYTORCH_CUDA_ALLOC_CONF | max_split_size_mb:4096 | Memory allocation settings |
| CUDA_LAUNCH_BLOCKING | 0 | Async CUDA operations |
| MODEL_PATH | /workspace/models/RealESRGAN_x4plus.pth | Model location |

## Features

- 4x upscaling using Real-ESRGAN
- Support for both CPU and GPU processing
- RunPod.io integration for cloud GPU processing
- Batch processing capability
- Memory-efficient processing for large images
- Support for common image formats (jpg, jpeg, png, webp)

## Requirements

- Python 3.7 or higher
- For local GPU processing: CUDA-capable GPU
- For cloud processing: RunPod.io API key

## Installation

1. Clone the repository:
```bash
git clone https://github.com/tatianathevisionary/image-upscaler-4k.git
cd image-upscaler-4k
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

## Usage

### Local Processing

```bash
python upscaler.py --input path/to/image.jpg --output path/to/output.jpg
```

For batch processing:
```bash
python upscaler.py --input input_folder --output output_folder --batch
```

### Cloud Processing (RunPod)

1. Get your API key from [RunPod.io](https://www.runpod.io/console/user/settings)
2. Add your API key to `runpod_upscaler.sh`
3. Run the upscaler:

```bash
# Make script executable
chmod +x runpod_upscaler.sh

# Create RunPod instance
./runpod_upscaler.sh create

# Process images
./runpod_upscaler.sh process input_folder output_folder

# Stop instance when done
./runpod_upscaler.sh stop
```

## GPU Options

The script supports various GPU options through RunPod:
- NVIDIA RTX 3070 (8GB VRAM)
- NVIDIA RTX 3080 (10GB VRAM) - Recommended
- NVIDIA RTX 3090 (24GB VRAM)
- NVIDIA A4000 (16GB VRAM)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN) for the base model
- [RunPod.io](https://www.runpod.io/) for GPU cloud computing 