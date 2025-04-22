# AI Image Upscaler 4K

A powerful image upscaling tool using Real-ESRGAN to enhance images to 4K quality. This project supports both local processing and cloud GPU processing through RunPod.io.

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