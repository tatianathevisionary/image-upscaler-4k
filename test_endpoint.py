import requests
import base64
from pathlib import Path
import os

# Configuration
RUNPOD_API_KEY = ""  # Add your RunPod API key here
ENDPOINT_ID = "b9rcz8azd7gdp7"  # Your endpoint ID from RunPod
IMAGE_URL = "https://ayxyolvuwtqiccvoaoru.supabase.co/storage/v1/object/sign/raw-posters/before_processing/tatianathevisionary_A_dancer_in_a_coral_and_blue_costume_spinni_45d5b159-92c7-4982-b4e5-03a2e0e606eb.png?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6InN0b3JhZ2UtdXJsLXNpZ25pbmcta2V5X2VjNTQ2NDIxLTI2MDctNDkzYy04ZTgyLTk2YzA2YmYwYWM1MSJ9.eyJ1cmwiOiJyYXctcG9zdGVycy9iZWZvcmVfcHJvY2Vzc2luZy90YXRpYW5hdGhldmlzaW9uYXJ5X0FfZGFuY2VyX2luX2FfY29yYWxfYW5kX2JsdWVfY29zdHVtZV9zcGlubmlfNDVkNWIxNTktOTJjNy00OTgyLWI0ZTUtMDNhMmUwZTYwNmViLnBuZyIsImlhdCI6MTc0NTI5NjA5NSwiZXhwIjoxNzQ1OTAwODk1fQ.fsbmU0b0q6hlRVkl9DOH1MVRDF9WUAc6Ic_4QISbCHg"

def download_image(url: str, save_path: str):
    """Download image from URL"""
    response = requests.get(url)
    response.raise_for_status()
    
    with open(save_path, 'wb') as f:
        f.write(response.content)
    return save_path

def image_to_base64(image_path: str) -> str:
    """Convert image to base64 string"""
    with open(image_path, 'rb') as f:
        return base64.b64encode(f.read()).decode('utf-8')

def save_base64_image(base64_str: str, save_path: str):
    """Save base64 string as image"""
    img_data = base64.b64decode(base64_str)
    with open(save_path, 'wb') as f:
        f.write(img_data)

def main():
    # Create directories if they don't exist
    Path("test_images").mkdir(exist_ok=True)
    Path("results").mkdir(exist_ok=True)
    
    # Download the image
    input_path = "test_images/dancer.png"
    print(f"Downloading image to {input_path}...")
    download_image(IMAGE_URL, input_path)
    
    # Convert to base64
    print("Converting image to base64...")
    image_base64 = image_to_base64(input_path)
    
    # Prepare the request
    headers = {
        "Authorization": f"Bearer {RUNPOD_API_KEY}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "input": {
            "image": image_base64
        }
    }
    
    # Send request to RunPod
    print("Sending request to RunPod...")
    endpoint_url = f"https://api.runpod.ai/v2/{ENDPOINT_ID}/run"
    response = requests.post(endpoint_url, headers=headers, json=payload)
    response.raise_for_status()
    
    # Get the task ID
    task_id = response.json()['id']
    print(f"Request submitted. Task ID: {task_id}")
    
    # Poll for results
    status_url = f"https://api.runpod.ai/v2/{ENDPOINT_ID}/status/{task_id}"
    while True:
        status_response = requests.get(status_url, headers=headers)
        status_data = status_response.json()
        
        if status_data['status'] == 'COMPLETED':
            # Save the result
            output_path = "results/dancer_upscaled.png"
            save_base64_image(status_data['output']['image'], output_path)
            print(f"\nSuccess! Upscaled image saved to: {output_path}")
            break
        elif status_data['status'] == 'FAILED':
            print(f"\nError: {status_data.get('error', 'Unknown error')}")
            break
        else:
            print(".", end="", flush=True)
            import time
            time.sleep(1)

if __name__ == "__main__":
    main() 