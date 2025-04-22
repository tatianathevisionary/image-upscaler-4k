import os
import base64
import runpod
import logging
from PIL import Image
from io import BytesIO
from upscaler import ImageUpscaler

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize the upscaler with error handling
try:
    logger.info("Initializing upscaler...")
    upscaler = ImageUpscaler(device='cuda', memory_efficient=True)
    logger.info("Upscaler initialized successfully")
except Exception as e:
    logger.error(f"Failed to initialize upscaler: {str(e)}")
    raise

def save_base64_image(base64_string, output_path):
    """Save a base64 string as an image"""
    try:
        img_data = base64.b64decode(base64_string)
        with open(output_path, 'wb') as f:
            f.write(img_data)
        return True
    except Exception as e:
        logger.error(f"Error saving base64 image: {str(e)}")
        return False

def image_to_base64(image_path):
    """Convert an image file to base64 string"""
    try:
        with open(image_path, 'rb') as f:
            return base64.b64encode(f.read()).decode('utf-8')
    except Exception as e:
        logger.error(f"Error converting image to base64: {str(e)}")
        return None

def handler(event):
    """
    Handler function for RunPod serverless requests
    
    Input format:
    {
        "input": {
            "image": "base64_encoded_image_string"
        }
    }
    """
    try:
        # Validate input
        if not event or "input" not in event or "image" not in event["input"]:
            error_msg = "Invalid input format. Expected {'input': {'image': 'base64_string'}}"
            logger.error(error_msg)
            return {"error": error_msg}
            
        # Get the input image
        input_image = event["input"]["image"]
        
        # Save input image
        input_path = "/workspace/input/image.jpg"
        if not save_base64_image(input_image, input_path):
            error_msg = "Failed to save input image"
            logger.error(error_msg)
            return {"error": error_msg}
        
        # Process image
        output_path = "/workspace/output/upscaled.jpg"
        logger.info("Starting image upscaling...")
        success = upscaler.upscale_image(input_path, output_path)
        
        if not success:
            error_msg = "Failed to process image"
            logger.error(error_msg)
            return {"error": error_msg}
        
        # Convert output to base64
        output_base64 = image_to_base64(output_path)
        if not output_base64:
            error_msg = "Failed to convert output image to base64"
            logger.error(error_msg)
            return {"error": error_msg}
        
        # Clean up
        try:
            os.remove(input_path)
            os.remove(output_path)
        except Exception as e:
            logger.warning(f"Error cleaning up temporary files: {str(e)}")
        
        logger.info("Successfully processed image")
        return {
            "output": {
                "image": output_base64
            }
        }
        
    except Exception as e:
        error_msg = f"Unexpected error: {str(e)}"
        logger.error(error_msg)
        return {"error": error_msg}

# Start the serverless handler with error handling
try:
    logger.info("Starting RunPod serverless handler...")
    runpod.serverless.start({"handler": handler})
except Exception as e:
    logger.error(f"Failed to start serverless handler: {str(e)}")
    raise 