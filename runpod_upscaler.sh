#!/bin/bash

# Configuration
API_KEY=""  # Your RunPod API key
GPU_TYPE="NVIDIA RTX 3080"  # Best price/performance for Real-ESRGAN
CONTAINER_DISK_SIZE=10  # GB

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_api_key() {
    if [ -z "$API_KEY" ]; then
        echo -e "${RED}Error: RunPod API key not set${NC}"
        echo "Please edit this script and add your API key from https://www.runpod.io/console/user/settings"
        exit 1
    fi
}

create_pod() {
    echo -e "${YELLOW}Creating RunPod instance...${NC}"
    
    # Create pod using RunPod API
    POD_ID=$(curl -s -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -X POST "https://api.runpod.io/v2/pods" \
        -d "{
            \"name\": \"upscaler\",
            \"imageName\": \"pytorch/pytorch:latest\",
            \"gpuType\": \"$GPU_TYPE\",
            \"containerDiskSize\": $CONTAINER_DISK_SIZE,
            \"dockerArgs\": \"\",
            \"volumeInGb\": 20,
            \"volumeMountPath\": \"/workspace\"
        }" | jq -r '.id')
    
    if [ -n "$POD_ID" ] && [ "$POD_ID" != "null" ]; then
        echo -e "${GREEN}Pod created successfully: $POD_ID${NC}"
        echo "$POD_ID" > .pod_id
    else
        echo -e "${RED}Failed to create pod${NC}"
        exit 1
    fi
}

setup_environment() {
    POD_ID=$(cat .pod_id)
    echo -e "${YELLOW}Setting up environment...${NC}"
    
    # Wait for pod to be ready
    while true; do
        STATUS=$(curl -s -H "Authorization: Bearer $API_KEY" \
            "https://api.runpod.io/v2/pods/$POD_ID" | jq -r '.status')
        if [ "$STATUS" = "RUNNING" ]; then
            break
        fi
        echo "Waiting for pod to be ready..."
        sleep 10
    done
    
    # Install dependencies and copy files
    runpodctl exec $POD_ID -- bash -c '
        apt-get update && apt-get install -y git python3-pip
        pip install basicsr facexlib gfpgan numpy opencv-python Pillow torch torchvision tqdm realesrgan
        # Clear pip cache to save space
        pip cache purge
    '
    
    # Copy upscaler script and create directories
    runpodctl cp upscaler.py $POD_ID:/workspace/
    runpodctl exec $POD_ID -- mkdir -p /workspace/input /workspace/output
    
    # Print GPU info
    runpodctl exec $POD_ID -- bash -c '
        echo "GPU Information:"
        nvidia-smi --query-gpu=gpu_name,memory.total,memory.free --format=csv,noheader
    '
}

check_image_size() {
    local IMAGE_PATH=$1
    # Get image dimensions using identify (part of imagemagick)
    if command -v identify >/dev/null 2>&1; then
        dimensions=$(identify -format "%wx%h" "$IMAGE_PATH" 2>/dev/null)
        width=$(echo $dimensions | cut -d'x' -f1)
        height=$(echo $dimensions | cut -d'x' -f2)
        
        # Calculate approximate VRAM needed (very rough estimate)
        # Formula: (width * height * 4 * 4 * 4) / (1024^3) GB
        # 4 for RGBA, 4 for upscaling factor, 4 for processing overhead
        vram_needed=$(echo "scale=2; $width * $height * 64 / 1073741824" | bc)
        echo -e "${YELLOW}Estimated VRAM needed for $IMAGE_PATH: ${vram_needed}GB${NC}"
    fi
}

process_images() {
    POD_ID=$(cat .pod_id)
    INPUT_DIR=$1
    OUTPUT_DIR=$2
    
    echo -e "${YELLOW}Processing images...${NC}"
    
    # Create directories if they don't exist
    mkdir -p "$OUTPUT_DIR"
    
    # Check VRAM requirements for each image
    echo "Checking image sizes..."
    for img in "$INPUT_DIR"/*; do
        if [[ -f "$img" ]]; then
            check_image_size "$img"
        fi
    done
    
    # Copy images to pod
    echo "Uploading images..."
    runpodctl cp "$INPUT_DIR"/* $POD_ID:/workspace/input/
    
    # Run upscaler with optimized settings
    echo "Running upscaler..."
    runpodctl exec $POD_ID -- python3 /workspace/upscaler.py \
        --input /workspace/input \
        --output /workspace/output \
        --batch \
        --memory-efficient
    
    # Copy results back
    echo "Downloading results..."
    runpodctl cp $POD_ID:/workspace/output/* "$OUTPUT_DIR"/
    
    # Print GPU stats after processing
    echo "GPU usage stats:"
    runpodctl exec $POD_ID -- nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader
}

stop_pod() {
    if [ -f .pod_id ]; then
        POD_ID=$(cat .pod_id)
        echo -e "${YELLOW}Stopping pod $POD_ID...${NC}"
        curl -s -H "Authorization: Bearer $API_KEY" \
            -X DELETE "https://api.runpod.io/v2/pods/$POD_ID"
        rm .pod_id
        echo -e "${GREEN}Pod stopped${NC}"
    else
        echo "No active pod found"
    fi
}

case "$1" in
    "create")
        check_api_key
        create_pod
        setup_environment
        ;;
    "process")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 process <input_dir> <output_dir>"
            exit 1
        fi
        check_api_key
        process_images "$2" "$3"
        ;;
    "stop")
        check_api_key
        stop_pod
        ;;
    *)
        echo "Usage: $0 <command> [args]"
        echo "Commands:"
        echo "  create              Create RunPod instance"
        echo "  process <in> <out>  Process images"
        echo "  stop                Stop RunPod instance"
        echo -e "\nRecommended GPU (current): NVIDIA RTX 3080"
        echo "- Good for images up to 4K resolution"
        echo "- Can batch process multiple images"
        echo "- Cost: ~$0.25/hour"
        exit 1
        ;;
esac 