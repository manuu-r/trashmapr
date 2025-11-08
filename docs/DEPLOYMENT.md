# Deployment Guide

This guide provides instructions for deploying the TrashMapR system to Google Cloud Platform (GCP). The entire backend is containerized and designed to run on Cloud Run.

## 1. Prerequisites

- **Google Cloud SDK**: `gcloud` CLI installed and authenticated.
- **Docker**: Docker installed and running on your local machine.
- **GCP Project**: A GCP project with the following APIs enabled:
    - Cloud Run API
    - Cloud Storage API
    - Pub/Sub API
    - Cloud SQL Admin API
    - Artifact Registry API (or Container Registry API)
- **Permissions**: You need sufficient IAM permissions to create and manage these resources (e.g., `roles/owner` or a combination of specific roles like `roles/run.admin`, `roles/storage.admin`, etc.).

## 2. Environment Variables

Each service requires a set of environment variables to be configured. Create a `.env` file for each service based on its `.env.example`.

### Backend (`backend/.env`)
```
DATABASE_URL=postgresql://USERNAME:PASSWORD@HOST:PORT/DATABASE_NAME
GOOGLE_CLIENT_ID=YOUR_GOOGLE_OAUTH_CLIENT_ID
# ... other variables
```

### Worker (`worker/.env`)
```
DATABASE_URL=postgresql://USERNAME:PASSWORD@HOST:PORT/DATABASE_NAME
GCP_PROJECT_ID=YOUR_GCP_PROJECT_ID
FCM_PROJECT_ID=YOUR_FIREBASE_PROJECT_ID
# ... other variables
```

## 3. Infrastructure Setup on GCP

### 3.1. Cloud SQL for PostgreSQL

1.  Create a Cloud SQL for PostgreSQL instance.
2.  Create a database (e.g., `your_database_name`).
3.  Create a user and set a password.
4.  **Important**: Configure the Cloud SQL instance to have a **public IP** and add the IP ranges for Cloud Run to its authorized networks. Alternatively, for better security, use a **private IP** and configure a Serverless VPC Connector.

### 3.2. Cloud Storage

1.  Create a GCS bucket to store the uploaded images.
2.  **Configure CORS**: The bucket must be configured with a CORS policy to allow `PUT` requests from the domain where your Flutter app runs (or `*` for development).
    ```json
    [
      {
        "origin": ["*"],
        "method": ["PUT"],
        "responseHeader": ["Content-Type"],
        "maxAgeSeconds": 3600
      }
    ]
    ```
    You can apply this using `gcloud storage buckets update gs://YOUR_BUCKET_NAME --cors-file=cors.json`.

### 3.3. Pub/Sub

1.  Create a Pub/Sub topic (e.g., `gcs-uploads`).
2.  Configure the GCS bucket to send notifications to this topic on object creation. Go to your bucket -> "Create notification" and select the topic.
3.  You do not need to create a subscription manually; Cloud Run will do this when you link the Worker service to the topic.

## 4. Building and Pushing Docker Images

For both the `backend` and `worker` services:

1.  **Enable Artifact Registry**:
    ```bash
    gcloud services enable artifactregistry.googleapis.com
    ```
2.  **Create a Docker Repository**:
    ```bash
    gcloud artifacts repositories create REPO_NAME --repository-format=docker --location=GCP_REGION
    ```
3.  **Build and Push**: From within the `backend` and `worker` directories respectively:
    ```bash
    # Authenticate Docker
    gcloud auth configure-docker GCP_REGION-docker.pkg.dev

    # Build the image
    docker build -t GCP_REGION-docker.pkg.dev/GCP_PROJECT_ID/REPO_NAME/SERVICE_NAME:latest .

    # Push the image
    docker push GCP_REGION-docker.pkg.dev/GCP_PROJECT_ID/REPO_NAME/SERVICE_NAME:latest
    ```
    Replace `SERVICE_NAME` with `backend` and `worker`.

## 5. Deploying to Cloud Run

### 5.1. Deploy the Backend Service

```bash
gcloud run deploy backend-service \
  --image GCP_REGION-docker.pkg.dev/GCP_PROJECT_ID/REPO_NAME/backend:latest \
  --platform managed \
  --region GCP_REGION \
  --allow-unauthenticated \
  --set-env-vars-from-file .env \
  --add-cloudsql-instances CLOUDSQL_CONNECTION_NAME
```
- `--allow-unauthenticated`: Required to make the API publicly accessible.
- `--add-cloudsql-instances`: Links the service to your database.

### 5.2. Deploy the Worker Service

```bash
gcloud run deploy worker-service \
  --image GCP_REGION-docker.pkg.dev/GCP_PROJECT_ID/REPO_NAME/worker:latest \
  --platform managed \
  --region GCP_REGION \
  --no-allow-unauthenticated \
  --set-env-vars-from-file .env \
  --add-cloudsql-instances CLOUDSQL_CONNECTION_NAME
```
- `--no-allow-unauthenticated`: The worker should not be publicly accessible.

### 5.3. Link Worker to Pub/Sub

After deploying the worker, create a trigger that connects the Pub/Sub topic to the worker:

```bash
gcloud eventarc triggers create gcs-trigger \
  --destination-run-service=worker-service \
  --destination-run-region=GCP_REGION \
  --location=GCP_REGION \
  --event-filters="type=google.cloud.pubsub.topic.v1.messagePublished" \
  --service-account=SERVICE_ACCOUNT_EMAIL \
  --transport-topic=projects/GCP_PROJECT_ID/topics/gcs-uploads
```
This command sets up an Eventarc trigger, which is the modern way to link Pub/Sub to Cloud Run.

## 6. Deploying the React Web App

The React app is a static site. You can deploy it using various methods:

- **Firebase Hosting (Recommended)**: Simple, fast, and integrates well with the GCP ecosystem.
- **Google Cloud Storage**: Configure a GCS bucket to serve static website content.
- **Cloud Run**: Serve the static files from a minimal container (e.g., Nginx).

For Firebase Hosting:
1.  `npm run build` in the `react` directory.
2.  Initialize Firebase in your project: `firebase init hosting`.
3.  Deploy: `firebase deploy`.
