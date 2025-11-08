#!/bin/bash

# Test script for local end-to-end upload flow
# Simulates: Client → Backend → GCS → Pub/Sub → Worker

set -e

echo "🧪 TrashMapr Upload Flow Test"
echo "=============================="
echo ""

# Configuration
BACKEND_URL="${BACKEND_URL:-http://localhost:8000}"
WORKER_URL="${WORKER_URL:-http://localhost:8081}"
TEST_IMAGE="${TEST_IMAGE:-test-image.jpg}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Check services are running
echo "📡 Step 1: Checking services..."
if ! curl -sf "$BACKEND_URL/health" > /dev/null; then
    echo -e "${RED}❌ Backend is not running at $BACKEND_URL${NC}"
    echo "Start it with: cd backend && docker-compose up -d"
    exit 1
fi
echo -e "${GREEN}✅ Backend is running${NC}"

if ! curl -sf "$WORKER_URL/health" > /dev/null; then
    echo -e "${RED}❌ Worker is not running at $WORKER_URL${NC}"
    echo "Start it with: cd worker && docker-compose up -d"
    exit 1
fi
echo -e "${GREEN}✅ Worker is running${NC}"
echo ""

# Step 2: Check for test image
echo "📸 Step 2: Checking test image..."
if [ ! -f "$TEST_IMAGE" ]; then
    echo -e "${YELLOW}⚠️  Test image not found. Creating a sample image...${NC}"
    # Create a simple test image (requires ImageMagick)
    if command -v convert &> /dev/null; then
        convert -size 800x600 xc:blue -pointsize 72 -fill white \
                -gravity center -annotate +0+0 "Test Upload" "$TEST_IMAGE"
        echo -e "${GREEN}✅ Created test image: $TEST_IMAGE${NC}"
    else
        echo -e "${RED}❌ Please provide a test image at: $TEST_IMAGE${NC}"
        echo "Or install ImageMagick to auto-generate one"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Test image found: $TEST_IMAGE${NC}"
fi
echo ""

# Step 3: Get authentication token (optional - for testing without auth)
echo "🔐 Step 3: Authentication..."
echo -e "${YELLOW}⚠️  This test requires a valid Google OAuth ID token${NC}"
echo "Options:"
echo "  1. Set TOKEN environment variable: export TOKEN='your-google-id-token'"
echo "  2. Use the Flutter app to authenticate and get a token"
echo "  3. Skip auth for now (endpoints will fail)"
echo ""

if [ -z "$TOKEN" ]; then
    echo -e "${YELLOW}⚠️  No TOKEN set - skipping authenticated endpoints${NC}"
    SKIP_AUTH=true
else
    echo -e "${GREEN}✅ Token found${NC}"
    SKIP_AUTH=false
fi
echo ""

# Step 4: Request signed URL (requires auth)
if [ "$SKIP_AUTH" = false ]; then
    echo "🔗 Step 4: Requesting signed URL from backend..."

    SIGNED_URL_RESPONSE=$(curl -sf -X POST \
        "$BACKEND_URL/api/v1/upload/signed-url?lat=12.9716&lng=77.5946&content_type=image/jpeg" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json")

    if [ $? -eq 0 ]; then
        echo "$SIGNED_URL_RESPONSE" | jq '.'
        UPLOAD_URL=$(echo "$SIGNED_URL_RESPONSE" | jq -r '.upload_url')
        FILE_NAME=$(echo "$SIGNED_URL_RESPONSE" | jq -r '.file_name')
        echo -e "${GREEN}✅ Got signed URL${NC}"
        echo "File will be uploaded to: $FILE_NAME"
    else
        echo -e "${RED}❌ Failed to get signed URL${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⏭️  Step 4: Skipped (no auth token)${NC}"
fi
echo ""

# Step 5: Upload to GCS (if we have signed URL)
if [ "$SKIP_AUTH" = false ] && [ -n "$UPLOAD_URL" ]; then
    echo "☁️  Step 5: Uploading image to GCS..."

    HTTP_CODE=$(curl -sf -w "%{http_code}" -X PUT \
        "$UPLOAD_URL" \
        -H "Content-Type: image/jpeg" \
        --data-binary "@$TEST_IMAGE" \
        -o /dev/null)

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        echo -e "${GREEN}✅ Upload successful (HTTP $HTTP_CODE)${NC}"
    else
        echo -e "${RED}❌ Upload failed (HTTP $HTTP_CODE)${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⏭️  Step 5: Skipped${NC}"
fi
echo ""

# Step 6: Manually trigger worker (simulating Pub/Sub)
echo "🤖 Step 6: Triggering worker (simulating Pub/Sub notification)..."
echo -e "${YELLOW}⚠️  In production, GCS automatically triggers Pub/Sub${NC}"
echo "For local testing, we'll call the worker directly..."
echo ""

if [ "$SKIP_AUTH" = false ] && [ -n "$FILE_NAME" ]; then
    # Create mock Pub/Sub message
    PUBSUB_MESSAGE=$(cat <<EOF
{
  "message": {
    "data": "$(echo -n "{\"name\":\"$FILE_NAME\",\"bucket\":\"garbage-pics\",\"contentType\":\"image/jpeg\",\"metadata\":{\"user_id\":\"1\",\"latitude\":\"12.9716\",\"longitude\":\"77.5946\",\"uploaded_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}" | base64)",
    "messageId": "test-message-id-$(date +%s)",
    "publishTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "subscription": "projects/test/subscriptions/test-sub"
}
EOF
)

    echo "Sending mock Pub/Sub message to worker..."
    echo "$PUBSUB_MESSAGE" | jq '.'

    WORKER_RESPONSE=$(curl -sf -X POST \
        "$WORKER_URL/process-upload" \
        -H "Content-Type: application/json" \
        -d "$PUBSUB_MESSAGE")

    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ Worker processed the upload${NC}"
        echo "$WORKER_RESPONSE" | jq '.'
    else
        echo -e "${RED}❌ Worker failed to process${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⏭️  Step 6: Skipped${NC}"
    echo ""
    echo -e "${YELLOW}To test the worker manually with a test payload:${NC}"
    cat <<'EOF'

curl -X POST http://localhost:8081/process-upload \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "data": "eyJuYW1lIjoidXBsb2Fkcy90ZXN0L3Rlc3QuanBnIiwiYnVja2V0IjoiZ2FyYmFnZS1waWNzIiwibWV0YWRhdGEiOnsidXNlcl9pZCI6IjEiLCJsYXRpdHVkZSI6IjEyLjk3MTYiLCJsb25naXR1ZGUiOiI3Ny41OTQ2In19",
      "messageId": "test-123"
    }
  }'
EOF
fi
echo ""

# Summary
echo "=============================="
echo "📊 Test Summary"
echo "=============================="
if [ "$SKIP_AUTH" = false ]; then
    echo -e "${GREEN}✅ Full end-to-end test completed!${NC}"
    echo ""
    echo "What happened:"
    echo "  1. ✅ Backend generated signed URL"
    echo "  2. ✅ Image uploaded to GCS"
    echo "  3. ✅ Worker processed the image"
    echo "  4. ✅ Database updated (check your DB)"
else
    echo -e "${YELLOW}⚠️  Partial test (no authentication)${NC}"
    echo ""
    echo "To run full test:"
    echo "  1. Get a Google OAuth ID token"
    echo "  2. export TOKEN='your-token'"
    echo "  3. Run this script again"
fi
echo ""
echo "Next steps:"
echo "  - Check backend logs: docker logs trashmapr-api"
echo "  - Check worker logs: docker logs worker-worker-1"
echo "  - Query database to see the new point"
