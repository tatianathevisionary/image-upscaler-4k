#!/usr/bin/env python3
import os
import logging
import argparse
from pathlib import Path
from typing import Union, List
import torch
import gc
from basicsr.archs.rrdbnet_arch import RRDBNet
from realesrgan import RealESRGANer
from realesrgan.archs.srvgg_arch import SRVGGNetCompact
from tqdm import tqdm

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ImageUpscaler:
    def __init__(self, model_name: str = 'RealESRGAN_x4plus', device: str = None, 
                 gpu_id: int = 0, memory_efficient: bool = False):
        """
        Initialize the image upscaler with specified model and device.
        
        Args:
            model_name: Name of the model to use
            device: Device to use ('cuda' or 'cpu'). If None, will automatically detect.
            gpu_id: GPU ID to use if multiple GPUs are available
            memory_efficient: If True, enables memory-efficient mode for vGPUs
        """
        self.model_name = model_name
        self.memory_efficient = memory_efficient
        
        # GPU device selection and verification
        if device == 'cuda' or (device is None and torch.cuda.is_available()):
            try:
                # Set specific GPU if multiple are available
                if torch.cuda.device_count() > 1:
                    logger.info(f"Multiple GPUs detected. Using GPU {gpu_id}")
                    torch.cuda.set_device(gpu_id)
                
                # Get GPU info
                gpu_name = torch.cuda.get_device_name()
                gpu_memory = torch.cuda.get_device_properties(gpu_id).total_memory / 1024**3  # Convert to GB
                logger.info(f"Using GPU: {gpu_name} with {gpu_memory:.2f}GB memory")
                
                self.device = f'cuda:{gpu_id}'
                
                # Enable memory efficient mode if requested
                if self.memory_efficient:
                    torch.cuda.empty_cache()
                    logger.info("Memory efficient mode enabled")
            except Exception as e:
                logger.warning(f"Error initializing GPU: {str(e)}. Falling back to CPU")
                self.device = 'cpu'
        else:
            self.device = 'cpu'
            
        logger.info(f"Using device: {self.device}")
        
        # Initialize model
        if self.model_name == 'RealESRGAN_x4plus':
            model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=4)
            netscale = 4
        else:
            raise ValueError(f"Unsupported model: {model_name}")

        # Initialize the upscaler with memory-efficient settings if enabled
        tile_size = 100 if self.memory_efficient else 0  # Use tiling when memory efficient mode is on
        self.upscaler = RealESRGANer(
            scale=netscale,
            model_path=f"https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/{model_name}.pth",
            model=model,
            tile=tile_size,  # Use tiling for memory efficiency
            tile_pad=10,
            pre_pad=0,
            device=self.device,
            half=self.memory_efficient  # Use half precision for memory efficiency
        )
        logger.info(f"Model {model_name} initialized successfully")

    def _clear_gpu_memory(self):
        """Clear GPU memory cache if memory efficient mode is enabled."""
        if self.memory_efficient and self.device.startswith('cuda'):
            torch.cuda.empty_cache()
            gc.collect()

    def upscale_image(self, input_path: Union[str, Path], output_path: Union[str, Path]) -> bool:
        """
        Upscale a single image.
        
        Args:
            input_path: Path to input image
            output_path: Path to save the upscaled image
            
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            input_path = str(input_path)
            output_path = str(output_path)
            
            # Create output directory if it doesn't exist
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            
            # Upscale image
            logger.info(f"Processing image: {input_path}")
            output, _ = self.upscaler.enhance(input_path, outscale=4)
            
            # Save the result
            self.upscaler.save_image(output, output_path)
            logger.info(f"Saved upscaled image to: {output_path}")
            
            # Clear GPU memory if memory efficient mode is enabled
            self._clear_gpu_memory()
            
            return True
            
        except Exception as e:
            logger.error(f"Error processing {input_path}: {str(e)}")
            return False

    def batch_upscale(self, input_dir: Union[str, Path], output_dir: Union[str, Path],
                      extensions: List[str] = ['.jpg', '.jpeg', '.png', '.webp']) -> None:
        """
        Batch upscale all images in a directory.
        
        Args:
            input_dir: Directory containing input images
            output_dir: Directory to save upscaled images
            extensions: List of file extensions to process
        """
        input_dir = Path(input_dir)
        output_dir = Path(output_dir)
        
        # Create output directory if it doesn't exist
        output_dir.mkdir(parents=True, exist_ok=True)
        
        # Get all image files
        image_files = []
        for ext in extensions:
            image_files.extend(list(input_dir.glob(f"*{ext}")))
            image_files.extend(list(input_dir.glob(f"*{ext.upper()}")))
        
        if not image_files:
            logger.warning(f"No images found in {input_dir} with extensions {extensions}")
            return
        
        logger.info(f"Found {len(image_files)} images to process")
        
        # Process each image
        successful = 0
        for img_path in tqdm(image_files, desc="Processing images"):
            output_path = output_dir / f"{img_path.stem}_upscaled{img_path.suffix}"
            if self.upscale_image(img_path, output_path):
                successful += 1
        
        logger.info(f"Batch processing complete. Successfully processed {successful}/{len(image_files)} images")

def main():
    parser = argparse.ArgumentParser(description="AI Image Upscaler using Real-ESRGAN")
    parser.add_argument('--input', required=True, help='Input image path or directory')
    parser.add_argument('--output', required=True, help='Output image path or directory')
    parser.add_argument('--device', choices=['cuda', 'cpu'], help='Device to use (default: auto-detect)')
    parser.add_argument('--batch', action='store_true', help='Enable batch processing of a directory')
    parser.add_argument('--gpu-id', type=int, default=0, help='GPU ID to use if multiple GPUs are available')
    parser.add_argument('--memory-efficient', action='store_true', 
                       help='Enable memory-efficient mode for vGPUs (uses tiling and half precision)')
    args = parser.parse_args()

    # Initialize upscaler
    upscaler = ImageUpscaler(device=args.device, gpu_id=args.gpu_id, 
                            memory_efficient=args.memory_efficient)

    if args.batch:
        upscaler.batch_upscale(args.input, args.output)
    else:
        success = upscaler.upscale_image(args.input, args.output)
        if not success:
            logger.error("Failed to process image")
            exit(1)

if __name__ == '__main__':
    main() 