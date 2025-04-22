import os
import base64
import runpod
from PIL import Image
from io import BytesIO
from upscaler import ImageUpscaler

# Initialize the upscaler
upscaler = ImageUpscaler(device='cuda', memory_efficient=True)

def save_base64_image(base64_string, output_path):
    """Save a base64 string as an image"""
    img_data = base64.b64decode(base64_string)
    with open(output_path, 'wb') as f:
        f.write(img_data)

def image_to_base64(image_path):
    """Convert an image file to base64 string"""
    with open(image_path, 'rb') as f:
        return base64.b64encode(f.read()).decode('utf-8')

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
        # Get the input image
        input_image = event["input"]["image"]
        
        # Save input image
        input_path = "/workspace/input/image.jpg"
        save_base64_image(input_image, input_path)
        
        # Process image
        output_path = "/workspace/output/upscaled.jpg"
        success = upscaler.upscale_image(input_path, output_path)
        
        if not success:
            return {"error": "Failed to process image"}
        
        # Convert output to base64
        output_base64 = image_to_base64(output_path)
        
        # Clean up
        os.remove(input_path)
        os.remove(output_path)
        
        return {
            "output": {
                "image": output_base64
            }
        }
        
    except Exception as e:
        return {"error": str(e)}

runpod.serverless.start({"handler": handler}) 