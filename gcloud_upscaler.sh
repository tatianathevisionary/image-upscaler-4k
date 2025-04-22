#!/bin/bash

# Configuration
INSTANCE_NAME="upscaler-gpu"
ZONE="us-central1-a"
MACHINE_TYPE="n1-standard-4"
GPU_TYPE="nvidia-tesla-t4"
GPU_COUNT=1

# Function to check if instance exists
instance_exists() {
    gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE &>/dev/null
}

# Function to create instance
create_instance() {
    echo "Creating GPU instance..."
    gcloud compute instances create $INSTANCE_NAME \
        --zone=$ZONE \
        --machine-type=$MACHINE_TYPE \
        --accelerator="type=$GPU_TYPE,count=$GPU_COUNT" \
        --maintenance-policy=TERMINATE \
        --image-family=debian-11-gpu \
        --image-project=debian-cloud \
        --boot-disk-size=50GB
}

# Function to setup environment
setup_environment() {
    echo "Setting up environment..."
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="
        curl https://raw.githubusercontent.com/GoogleCloudPlatform/compute-gpu-installation/main/linux/install_gpu_driver.py --output install_gpu_driver.py
        sudo python3 install_gpu_driver.py
        python3 -m venv venv
        source venv/bin/activate
        pip install -r requirements.txt
    "
}

# Function to process images
process_images() {
    local INPUT_DIR=$1
    local OUTPUT_DIR=$2
    
    echo "Creating directories on instance..."
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="
        mkdir -p ~/input ~/output
    "
    
    echo "Uploading images..."
    gcloud compute scp --zone=$ZONE --recurse "$INPUT_DIR"/* "$INSTANCE_NAME:~/input/"
    
    echo "Processing images..."
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="
        source venv/bin/activate
        python upscaler.py --input ~/input --output ~/output --batch --memory-efficient
    "
    
    echo "Downloading processed images..."
    mkdir -p "$OUTPUT_DIR"
    gcloud compute scp --zone=$ZONE --recurse "$INSTANCE_NAME:~/output/*" "$OUTPUT_DIR/"
}

# Main script
case "$1" in
    "create")
        if ! instance_exists; then
            create_instance
            setup_environment
        else
            echo "Instance already exists"
        fi
        ;;
    "start")
        if instance_exists; then
            gcloud compute instances start $INSTANCE_NAME --zone=$ZONE
        else
            echo "Instance does not exist. Create it first with './gcloud_upscaler.sh create'"
        fi
        ;;
    "stop")
        if instance_exists; then
            gcloud compute instances stop $INSTANCE_NAME --zone=$ZONE
        else
            echo "Instance does not exist"
        fi
        ;;
    "process")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: ./gcloud_upscaler.sh process <input_dir> <output_dir>"
            exit 1
        fi
        if ! instance_exists; then
            echo "Instance does not exist. Create it first with './gcloud_upscaler.sh create'"
            exit 1
        fi
        process_images "$2" "$3"
        ;;
    *)
        echo "Usage: ./gcloud_upscaler.sh <command> [args]"
        echo "Commands:"
        echo "  create              Create GPU instance"
        echo "  start               Start GPU instance"
        echo "  stop                Stop GPU instance"
        echo "  process <in> <out>  Process images from <in> directory to <out> directory"
        exit 1
        ;;
esac 