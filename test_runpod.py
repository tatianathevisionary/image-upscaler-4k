import requests
import base64
import os
import json
import time
from pathlib import Path
import tempfile

def load_config():
    try:
        with open('config.json', 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print("Error: config.json file not found. Please create it with your API key.")
        exit(1)
    except json.JSONDecodeError:
        print("Error: config.json is not valid JSON. Please check the format.")
        exit(1)

def download_image(url, output_path):
    response = requests.get(url)
    response.raise_for_status()  # Raise an exception for bad status codes
    
    with open(output_path, 'wb') as f:
        f.write(response.content)
    return output_path

def encode_image_to_base64(image_path):
    with open(image_path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode('utf-8')

def check_status(job_id, api_key):
    status_url = f"https://api.runpod.ai/v2/b9rcz8azd7gdp7/status/{job_id}"
    headers = {
        'Authorization': f'Bearer {api_key}'
    }
    response = requests.get(status_url, headers=headers)
    return response.json()

def save_result(output_data, output_dir='upscaled_images'):
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Get the image URL from the output
    image_url = output_data.get('image', '')
    if not image_url:
        print("Error: No image URL in the output")
        return None
    
    # Generate output filename
    timestamp = time.strftime("%Y%m%d-%H%M%S")
    output_path = os.path.join(output_dir, f'upscaled_{timestamp}.png')
    
    # Download the image
    try:
        download_image(image_url, output_path)
        print(f"Upscaled image saved to: {output_path}")
        return output_path
    except Exception as e:
        print(f"Error downloading result: {e}")
        return None

def upscale_image(image_source, api_key, is_url=False):
    # RunPod endpoint URL
    endpoint_url = "https://api.runpod.ai/v2/b9rcz8azd7gdp7/run"
    
    # If the source is a URL, download it first
    if is_url:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as temp_file:
            temp_path = temp_file.name
            download_image(image_source, temp_path)
            image_path = temp_path
    else:
        image_path = image_source
    
    try:
        # Encode image to base64
        base64_image = encode_image_to_base64(image_path)
        
        # Request headers
        headers = {
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {api_key}'
        }
        
        # Request payload
        payload = {
            "input": {
                "image": base64_image
            }
        }
        
        # Make the request
        response = requests.post(endpoint_url, headers=headers, json=payload)
        
        # Print initial response
        print(f"Status Code: {response.status_code}")
        print("Initial Response:")
        response_data = response.json()
        print(response_data)
        
        if response.status_code == 200:
            job_id = response_data['id']
            print("\nPolling for results...")
            
            # Poll for results
            while True:
                status_data = check_status(job_id, api_key)
                status = status_data.get('status')
                print(f"Status: {status}")
                
                if status == 'COMPLETED':
                    print("\nJob completed!")
                    output_data = status_data.get('output')
                    if output_data:
                        saved_path = save_result(output_data)
                        if saved_path:
                            print("Processing completed successfully!")
                    break
                elif status in ['FAILED', 'CANCELLED']:
                    print(f"\nJob failed or was cancelled. Status: {status}")
                    print("Error:", status_data.get('error'))
                    break
                
                # Wait before checking again
                time.sleep(5)
        
    finally:
        # Clean up temporary file if we created one
        if is_url and os.path.exists(temp_path):
            os.unlink(temp_path)

if __name__ == "__main__":
    # Load configuration
    config = load_config()
    API_KEY = config['runpod_api_key']
    
    IMAGE_URL = "https://ayxyolvuwtqiccvoaoru.supabase.co/storage/v1/object/sign/raw-posters/before_processing/tatianathevisionary_A_dancer_in_a_coral_and_blue_costume_spinni_45d5b159-92c7-4982-b4e5-03a2e0e606eb.png?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6InN0b3JhZ2UtdXJsLXNpZ25pbmcta2V5X2VjNTQ2NDIxLTI2MDctNDkzYy04ZTgyLTk2YzA2YmYwYWM1MSJ9.eyJ1cmwiOiJyYXctcG9zdGVycy9iZWZvcmVfcHJvY2Vzc2luZy90YXRpYW5hdGhldmlzaW9uYXJ5X0FfZGFuY2VyX2luX2FfY29yYWxfYW5kX2JsdWVfY29zdHVtZV9zcGlubmlfNDVkNWIxNTktOTJjNy00OTgyLWI0ZTUtMDNhMmUwZTYwNmViLnBuZyIsImlhdCI6MTc0NTI5NzMwMCwiZXhwIjoxNzQ1OTAyMTAwfQ.J0OJb3joHQE8z9CvgcaX6-pflcW2wF0z4fF2hY6ZKB0"
    
    upscale_image(IMAGE_URL, API_KEY, is_url=True) 