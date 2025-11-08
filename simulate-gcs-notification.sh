#!/bin/bash

# GCS Notification Simulator
# Polls GCS bucket for new files and triggers worker with Pub/Sub-like payload
# This simulates the GCS → Pub/Sub → Worker flow for local testing

set -e

WORKER_URL="${WORKER_URL:-http://localhost:8081}"
GCS_BUCKET="${GCS_BUCKET_NAME:-flutter-geo-tagged-uploads}"
POLL_INTERVAL="${POLL_INTERVAL:-5}"
PROCESSED_FILE="/tmp/processed_files.txt"

echo "🔔 GCS Notification Simulator Started"
echo "=================================="
echo "Bucket: gs://$GCS_BUCKET/uploads/"
echo "Worker: $WORKER_URL"
echo "Poll interval: ${POLL_INTERVAL}s"
echo ""

# Create processed files tracker
touch "$PROCESSED_FILE"

# Function to check if file was already processed
is_processed() {
    local file_name="$1"
    grep -qF "$file_name" "$PROCESSED_FILE"
}

# Function to mark file as processed
mark_processed() {
    local file_name="$1"
    echo "$file_name" >> "$PROCESSED_FILE"
}

# Function to trigger worker with Pub/Sub-like message
trigger_worker() {
    local file_name="$1"
    local metadata="$2"

    echo "📨 Triggering worker for: $file_name"

    # Extract metadata
    local user_id=$(echo "$metadata" | jq -r '.user_id // "1"')
    local latitude=$(echo "$metadata" | jq -r '.latitude // "0.0"')
    local longitude=$(echo "$metadata" | jq -r '.longitude // "0.0"')
    local uploaded_at=$(echo "$metadata" | jq -r '.uploaded_at // ""')

    if [ -z "$uploaded_at" ]; then
        uploaded_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    fi

    # Create GCS object notification payload
    local gcs_payload=$(cat <<EOF
{
  "name": "$file_name",
  "bucket": "$GCS_BUCKET",
  "contentType": "image/jpeg",
  "size": "0",
  "metadata": {
    "user_id": "$user_id",
    "latitude": "$latitude",
    "longitude": "$longitude",
    "uploaded_at": "$uploaded_at"
  }
}
EOF
)

    # Encode as base64 (like Pub/Sub does)
    local encoded_data=$(echo -n "$gcs_payload" | base64 | tr -d '\n')

    # Create Pub/Sub push message
    local pubsub_message=$(cat <<EOF
{
  "message": {
    "data": "$encoded_data",
    "messageId": "simulator-$(date +%s)-$(uuidgen 2>/dev/null || echo $RANDOM)",
    "publishTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "subscription": "projects/local/subscriptions/image-upload-worker-sub"
}
EOF
)

    # Send to worker
    local response=$(curl -sf -X POST \
        "$WORKER_URL/process-upload" \
        -H "Content-Type: application/json" \
        -d "$pubsub_message" 2>&1)

    if [ $? -eq 0 ]; then
        echo "✅ Worker processed: $file_name"
        echo "Response: $response" | jq '.' 2>/dev/null || echo "$response"
        mark_processed "$file_name"
    else
        echo "❌ Worker failed: $response"
    fi

    echo ""
}

# Main polling loop
echo "👀 Watching for new uploads..."
echo ""

while true; do
    # List files in uploads/ folder (check jpg, jpeg, and png separately)
    FILES=$(gsutil -m ls -l "gs://$GCS_BUCKET/uploads/**/*.jpg" "gs://$GCS_BUCKET/uploads/**/*.jpeg" "gs://$GCS_BUCKET/uploads/**/*.png" 2>/dev/null | grep -v "TOTAL:" || true)

    if [ -n "$FILES" ]; then
        echo "$FILES" | while IFS= read -r line; do
            # Parse gsutil output: size date time gs://bucket/file
            FILE_PATH=$(echo "$line" | awk '{print $NF}')

            if [ -z "$FILE_PATH" ] || [ "$FILE_PATH" = "gs://$GCS_BUCKET/uploads/" ]; then
                continue
            fi

            # Extract just the file name
            FILE_NAME=$(echo "$FILE_PATH" | sed "s|gs://$GCS_BUCKET/||")

            # Skip if already processed
            if is_processed "$FILE_NAME"; then
                continue
            fi

            echo "🆕 New file detected: $FILE_NAME"

            # Get file metadata
            METADATA=$(gsutil stat "$FILE_PATH" 2>/dev/null | grep -A 100 "Metadata:" | tail -n +2 || echo '{}')

            # Convert metadata to JSON (use process substitution to avoid subshell)
            METADATA_JSON='{'
            while IFS= read -r meta_line; do
                if [ -z "$meta_line" ]; then
                    break
                fi
                KEY=$(echo "$meta_line" | awk '{print $1}' | tr -d ':')
                VALUE=$(echo "$meta_line" | awk '{$1=""; print $0}' | sed 's/^ //')
                METADATA_JSON="$METADATA_JSON\"$KEY\":\"$VALUE\","
            done < <(echo "$METADATA")
            METADATA_JSON="${METADATA_JSON%,}}"

            # Trigger worker
            trigger_worker "$FILE_NAME" "$METADATA_JSON"
        done
    fi

    # Wait before next poll
    sleep "$POLL_INTERVAL"
done
