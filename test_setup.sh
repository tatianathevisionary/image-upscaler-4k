#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Testing Google Cloud Setup...${NC}"

# Test 1: Check gcloud installation
echo -n "Checking gcloud installation... "
if command -v gcloud &> /dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    echo "Please install Google Cloud SDK first"
    exit 1
fi

# Test 2: Check authentication
echo -n "Checking gcloud authentication... "
if gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    echo "Please run 'gcloud auth login' first"
    exit 1
fi

# Test 3: Check project configuration
echo -n "Checking project configuration... "
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -n "$PROJECT_ID" ]; then
    echo -e "${GREEN}OK${NC} (Project: $PROJECT_ID)"
else
    echo -e "${RED}FAILED${NC}"
    echo "Please run 'gcloud config set project YOUR_PROJECT_ID' first"
    exit 1
fi

# Test 4: Check Compute Engine API
echo -n "Checking Compute Engine API... "
if gcloud services list --enabled --filter="name:compute.googleapis.com" | grep compute; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    echo "Please enable Compute Engine API in Google Cloud Console"
    exit 1
fi

# Test 5: Check GPU quota
echo -n "Checking GPU quota... "
QUOTA=$(gcloud compute regions describe us-central1 --format="get(quotas.metric==NVIDIA_T4_GPUS.limit)" 2>/dev/null)
if [ -n "$QUOTA" ] && [ "$QUOTA" -gt "0" ]; then
    echo -e "${GREEN}OK${NC} (T4 GPU quota: $QUOTA)"
else
    echo -e "${YELLOW}WARNING${NC}"
    echo "You may need to request GPU quota in Google Cloud Console"
fi

# Test 6: Create a test image directory
echo -n "Creating test directory... "
mkdir -p test_images
if [ ! -f test_images/test.jpg ]; then
    # Create a small test image using base64
    echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==" | base64 -d > test_images/test.jpg
fi
echo -e "${GREEN}OK${NC}"

# Test 7: Test upscaler script
echo -n "Testing upscaler script... "
if [ -f "upscaler.py" ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    echo "upscaler.py not found in current directory"
    exit 1
fi

echo -e "\n${GREEN}Setup verification complete!${NC}"
echo -e "\nTo test the full pipeline, run:"
echo -e "${YELLOW}./gcloud_upscaler.sh create${NC}"
echo -e "${YELLOW}./gcloud_upscaler.sh process test_images output_images${NC}"
echo -e "${YELLOW}./gcloud_upscaler.sh stop${NC}"

# Cleanup
echo -e "\nWould you like to run the full test now? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    ./gcloud_upscaler.sh create
    ./gcloud_upscaler.sh process test_images output_images
    ./gcloud_upscaler.sh stop
fi 