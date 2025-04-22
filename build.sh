#!/bin/bash

# Exit on error
set -e

# Configuration
REGISTRY="registry.runpod.io"
REPOSITORY="tatianathevisionary-image-upscaler-4k"
TAG=$(date +%Y%m%d_%H%M%S)

echo "Building container..."
docker build -t $REGISTRY/$REPOSITORY:$TAG .

echo "Pushing to RunPod registry..."
docker push $REGISTRY/$REPOSITORY:$TAG

echo "Build complete. Your new image tag is: $TAG"
echo "Please update your RunPod endpoint with this new image: $REGISTRY/$REPOSITORY:$TAG" 