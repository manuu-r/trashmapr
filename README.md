# TrashMapr

TrashMapr is a google cloudrun system designed for crowdsourcing and visualizing trash locations. Users can upload images of litter via a mobile app, and the data is processed and displayed on a public web-based heatmap.

## Documentation

This document provides a high-level overview. For more detailed information, please refer to the documentation in the `docs` folder:

- **[Architecture](docs/Architecture.md)**: A detailed explanation of the system architecture, components, and data flows, including diagrams.
- **[API and Data Flow](docs/API_FLOW.md)**: A description of the API endpoints and the sequence of events for major operations.
- **[Deployment Guide](docs/DEPLOYMENT.md)**: Instructions for deploying the system to Google Cloud Platform.
- **[Local Setup and Testing](docs/LOCAL_SETUP.md)**: A guide for setting up and running the system on a local machine for development and testing.

---

## Architecture Overview

The system features a serverless, event-driven architecture. A Flutter mobile app handles authenticated image uploads directly to Google Cloud Storage using signed URLs. A React web app provides a public, read-only view of the collected data. The backend is built with FastAPI and runs on Cloud Run, with an asynchronous worker service that processes uploads and sends notifications via Firebase Cloud Messaging (FCM).

## Core Components

- **Flutter Mobile App**: Allows authenticated users to capture and upload images of trash, automatically embedding geolocation data.
- **React Web App**: A public-facing web application that displays a heatmap of all collected trash points.
- **FastAPI Backend**: A Python-based service running on Cloud Run that handles user authentication, generates signed URLs for secure uploads, and serves data to the web app.
- **Google Cloud Storage**: Provides scalable, secure storage for all user-uploaded images.
- **Google Pub/Sub**: A messaging service that decouples the image upload process from the backend processing, creating a resilient, event-driven workflow.
- **Worker (Cloud Run)**: A separate Cloud Run service that listens to Pub/Sub events, processes image metadata, updates the database, and triggers push notifications.
- **Firebase Cloud Messaging (FCM)**: Sends real-time push notifications to users upon successful image processing.

## Technology Stack

- **Frontend (Mobile)**: Flutter, Dart
- **Frontend (Web)**: React, TypeScript, Vite, MapLibre GL JS
- **Backend**: Python, FastAPI
- **Database**: PostgreSQL
- **Infrastructure**: Google Cloud Platform (Cloud Run, Cloud Storage, Pub/Sub, Identity Platform)
- **Notifications**: Firebase Cloud Messaging (FCM)
- **Containerization**: Docker, Docker Compose
