
# Architecture Overview

This document outlines the architecture of the TrashMapr project, which consists of a backend service, a Flutter mobile application, and a React web application.

## Architecture Diagram

```mermaid
graph TD
    subgraph "Clients"
        A[Flutter Mobile App]
        B[React Web App]
    end

    subgraph "Backend (FastAPI)"
        C[API Endpoints]
        D[Authentication Service]
        E[Database (PostgreSQL + PostGIS)]
        F[Google Cloud Storage]
        G[Google Gemini API]
    end

    A -- "REST API (HTTPS)" --> C
    B -- "REST API (HTTPS)" --> C
    C -- "User Auth" --> D
    C -- "Data Access" --> E
    C -- "Image Upload" --> F
    C -- "Image Analysis" --> G
```

## Components

### 1. Backend (FastAPI)

The backend is a Python application built with the [FastAPI](https://fastapi.tiangolo.com/) framework. It serves as the central hub for the entire system.

*   **API Endpoints**: Exposes a RESTful API for creating, reading, and deleting geo-tagged points. It also handles user authentication and image uploads.
*   **Authentication Service**: Manages user authentication using Google OAuth2. It secures endpoints and ensures that users can only manage their own data.
*   **Database**: A [PostgreSQL](https://www.postgresql.org/) database with the [PostGIS](https://postgis.net/) extension is used to store user data and geo-spatial information about the uploaded photos. [SQLAlchemy](https://www.sqlalchemy.org/) with `asyncpg` is used for asynchronous database operations, and [Alembic](https://alembic.sqlalchemy.org/) handles database migrations.
*   **Google Cloud Storage**: Uploaded images are stored in a [Google Cloud Storage](https://cloud.google.com/storage) bucket for persistence and easy access.
*   **Google Gemini API**: The [Google Gemini API](https://ai.google.dev/) is used for AI-powered image analysis. It validates uploaded images to ensure they are not inappropriate and categorizes the type of trash depicted.

### 2. Flutter Mobile App

The mobile application is built with [Flutter](https://flutter.dev/) and is available for both Android and iOS. It is the primary tool for users to contribute data to the platform.

*   **Map View**: Displays a map with clusters of geo-tagged photos.
*   **Camera and Geolocation**: Allows users to take photos and automatically tag them with their current GPS coordinates.
*   **Authentication**: Integrates with Google Sign-In to authenticate users with the backend.
*   **API Service**: Communicates with the backend via HTTP requests to upload photos and retrieve data.

### 3. React Web App

The web application is built with [React](https://reactjs.org/) and provides a read-only view of the collected data.

*   **Map View**: Uses the [React Google Maps API](https://react-google-maps-api-docs.netlify.app/) to display the density map of the collected photos.
*   **Data Visualization**: The primary purpose of the web app is to visualize the data collected by the mobile app users, providing an overview of the trash distribution.
