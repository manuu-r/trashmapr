#!/bin/bash

# Build and Push Docker Images to Google Cloud Artifact Registry
# This script reads configuration from .env file and builds/pushes both backend and worker images

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables from .env file
if [ -f .env ]; then
    echo -e "${GREEN}Loading environment variables from .env...${NC}"
    export $(grep -v '^#' .env | xargs)
else
    echo -e "${RED}Error: .env file not found!${NC}"
    exit 1
fi

# Verify required variables
if [ -z "$GCP_PROJECT_ID" ] || [ -z "$GCP_REGION" ] || [ -z "$GCP_REPO" ]; then
    echo -e "${RED}Error: Missing required environment variables (GCP_PROJECT_ID, GCP_REGION, GCP_REPO)${NC}"
    exit 1
fi

# Get current git commit hash or use 'latest'
COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")
export COMMIT_HASH

echo -e "${GREEN}=== Build Configuration ===${NC}"
echo "GCP Project ID: $GCP_PROJECT_ID"
echo "GCP Region: $GCP_REGION"
echo "GCP Repo: $GCP_REPO"
echo "Commit Hash: $COMMIT_HASH"
echo ""

# Configure Docker for Artifact Registry
echo -e "${YELLOW}Configuring Docker for Artifact Registry...${NC}"
gcloud auth configure-docker ${GCP_REGION}-docker.pkg.dev

# Parse command line arguments
BUILD_BACKEND=true
BUILD_WORKER=true
PUSH_IMAGES=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --backend-only)
            BUILD_WORKER=false
            shift
            ;;
        --worker-only)
            BUILD_BACKEND=false
            shift
            ;;
        --no-push)
            PUSH_IMAGES=false
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --backend-only    Build and push only the backend image"
            echo "  --worker-only     Build and push only the worker image"
            echo "  --no-push         Build images but don't push to registry"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Build and push backend
if [ "$BUILD_BACKEND" = true ]; then
    echo -e "${GREEN}=== Building Backend Image ===${NC}"
    docker compose build backend

    if [ "$PUSH_IMAGES" = true ]; then
        echo -e "${GREEN}=== Pushing Backend Image ===${NC}"
        docker push ${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${GCP_REPO}/trashmapr-backend:${COMMIT_HASH}
        echo -e "${GREEN}✓ Backend image pushed successfully${NC}"
    fi
fi

# Build and push worker
if [ "$BUILD_WORKER" = true ]; then
    echo -e "${GREEN}=== Building Worker Image ===${NC}"
    docker compose --profile worker build worker

    if [ "$PUSH_IMAGES" = true ]; then
        echo -e "${GREEN}=== Pushing Worker Image ===${NC}"
        docker push ${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${GCP_REPO}/trashmapr-worker:${COMMIT_HASH}
        echo -e "${GREEN}✓ Worker image pushed successfully${NC}"
    fi
fi

echo ""
echo -e "${GREEN}=== Summary ===${NC}"
if [ "$BUILD_BACKEND" = true ]; then
    echo "Backend: ${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${GCP_REPO}/trashmapr-backend:${COMMIT_HASH}"
fi
if [ "$BUILD_WORKER" = true ]; then
    echo "Worker:  ${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${GCP_REPO}/trashmapr-worker:${COMMIT_HASH}"
fi

if [ "$PUSH_IMAGES" = false ]; then
    echo ""
    echo -e "${YELLOW}Note: Images were built but not pushed (--no-push flag)${NC}"
fi

echo ""
echo -e "${GREEN}✓ All done!${NC}"
