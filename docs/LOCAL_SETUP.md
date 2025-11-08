# Local Development and Testing Guide

This guide provides comprehensive instructions for setting up, running, and testing the entire TrashMapR system on your local machine.

## Quick Start (5-Minute Setup)

For experienced developers familiar with the stack.

1.  **Prerequisites**:
    - Docker & Docker Compose
    - A Google Cloud service account key (`gcp_creds.json`) with "Cloud SQL Client" and "Storage Object Admin" roles.
    - Flutter SDK

2.  **Configuration**:
    - Copy `.env.example` to `.env` in both the `backend` and `worker` directories.
    - Fill in the required variables, especially `DATABASE_URL`, `GCS_BUCKET_NAME`, and your GCP project details.
    - Place your service account key in the project root as `service_account.json`.

3.  **Start Services**:
    ```bash
    # From the project root
    docker-compose -f docker-compose.local.yml up --build -d
    ```
    This starts the backend, worker, and a local GCS event simulator.

4.  **Configure Flutter**:
    - The backend will be available at `http://localhost:8000`.
    - In `flutter/.env`, set `API_URL` to `http://10.0.2.2:8000/api/v1` for the Android emulator or `http://localhost:8000/api/v1` for the iOS simulator. For physical devices, a tunneling service like `ngrok` is required.

5.  **Run and Test**:
    - Run the Flutter app.
    - Sign in and upload a photo.
    - Monitor logs to see the event-driven flow in action: `docker-compose -f docker-compose.local.yml logs -f`

---

## Detailed Local Setup Guide

### 1. Architecture for Local Testing

The local setup uses `docker-compose` to simulate the cloud environment. The key difference is the `gcs-simulator` service, which polls your actual GCS bucket for new files and triggers the local worker service via an HTTP request, mimicking a Pub/Sub event.

```
┌──────────────┐
│ Flutter App  │ (Phone/Emulator)
└──────┬───────┘
       │ 1. POST /api/v1/uploads/signed-url
       ↓
┌──────────────┐
│   Backend    │ (localhost:8000, Docker)
└──────┬───────┘
       │ 2. Returns GCS Signed URL
       ↓
┌──────────────┐
│ Flutter App  │
└──────┬───────┘
       │ 3. PUT image directly to GCS
       ↓
┌──────────────┐
│ GCS Bucket   │ (Live on Google Cloud)
└──────┬───────┘
       │ 4. New file is created
       │
┌──────────────┐
│GCS Simulator │ (Polls GCS bucket, Docker)
└──────┬───────┘
       │ 5. POSTs notification to local worker
       ↓
┌──────────────┐
│   Worker     │ (localhost:8081, Docker)
└──────────────┘
```

### 2. Setup Instructions

#### Step 1: Configure Environment Variables

-   **Backend**: `cd backend`, copy `.env.example` to `.env`, and fill in the variables.
-   **Worker**: `cd worker`, copy `.env.example` to `.env`, and fill in the variables.

**Crucial Variables**:
-   `DATABASE_URL`: Your connection string for Cloud SQL or a local PostgreSQL instance.
-   `GCS_BUCKET_NAME`: The name of your GCS bucket.
-   `GOOGLE_APPLICATION_CREDENTIALS`: Should be set to `../service_account.json` to match the Docker setup.

#### Step 2: Place GCP Credentials

Place your downloaded service account JSON key in the project's root directory and name it `service_account.json`. This file is mounted into the `backend` and `worker` containers by `docker-compose.local.yml`.

#### Step 3: Start Services

From the project root, run:
```bash
docker-compose -f docker-compose.local.yml up --build -d
```
- The `-d` flag runs the services in detached mode.
- To view logs for all services: `docker-compose -f docker-compose.local.yml logs -f`
- To view logs for a specific service: `docker logs -f backend-service`

#### Step 4: Configure the Flutter App

As mentioned in the Quick Start, update `flutter/.env` to point to your local backend.
- **Android Emulator**: `API_URL=http://10.0.2.2:8000/api/v1`
- **iOS Simulator**: `API_URL=http://localhost:8000/api/v1`

### 3. Testing the Full Flow

1.  **Start Services**: Ensure all Docker containers are running.
2.  **Run Flutter App**: `cd flutter && flutter run`.
3.  **Sign In & Upload**: Use the app to sign in and upload a photo.
4.  **Monitor Logs**: Watch the logs of the `backend-service`, `gcs-simulator`, and `worker-service` to see the sequence of events.

**Expected Log Sequence**:
1.  **Backend**: Receives a request for a signed URL and generates it.
2.  **GCS Simulator**: Detects the new file in the GCS bucket and logs that it is triggering the worker.
3.  **Worker**: Receives the request, downloads the image, processes it, and saves the result to the database.

### 4. Troubleshooting

-   **Connection Refused**: Check that the service is running with `docker ps`. Verify the port mapping. Use `docker logs` to check for container startup errors.
-   **Database Connection Failed**: Double-check your `DATABASE_URL`. If using Cloud SQL, ensure your local IP is authorized or you are using the Cloud SQL Auth Proxy.
-   **Worker Not Triggered**: Check the `gcs-simulator` logs. It will report if it fails to list objects in the bucket (often a permissions issue) or if it fails to send the request to the worker.
-   **Permissions Denied on Upload**: Ensure your service account has the **Storage Object Admin** role on the GCS bucket.

### 5. Cleaning Up

To stop all local services:
```bash
docker-compose -f docker-compose.local.yml down
```
To remove the Docker volumes (deletes any container-stored data):
```bash
docker-compose -f docker-compose.local.yml down -v
```
