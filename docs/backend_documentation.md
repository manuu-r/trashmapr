# TrashMapr Backend Documentation

## 1. Overview

The TrashMapr backend is a FastAPI API for a geo-tagged photo application. It uses Google's Gemini AI to analyze user-uploaded images for "trash" content and categorizes them by density. The entire system is designed for Google Cloud Platform, using AlloyDB, Google Cloud Storage (GCS), and the Gemini API.

## 2. Features

-   **Google OAuth 2.0:** Secure user authentication.
-   **AI-Powered Image Analysis:** Rejects invalid images (selfies, memes) and rates valid scenes on a 1-4 density scale using Gemini.
-   **Geospatial Database:** Stores geo-tagged points in a PostGIS-enabled AlloyDB for efficient map-based queries.
-   **Cloud Storage:** Uploads all images to a GCS bucket.
-   **Containerized:** Fully containerized with Docker for easy deployment.

## 3. Tech Stack

| Category       | Technology                                  |
| -------------- | ------------------------------------------- |
| **Framework**  | FastAPI                                     |
| **Database**   | Google AlloyDB for PostgreSQL + PostGIS     |
| **Migrations** | Alembic                                     |
| **AI/ML**      | Google Gemini API (gemini-2.5-flash)        |
| **Storage**    | Google Cloud Storage (GCS)                  |
| **Auth**       | Authlib for Google OAuth 2.0                |
| **Container**  | Docker & Docker Compose                     |

## 4. Project Structure

-   `main.py`: FastAPI application entrypoint and API routes.
-   `models.py`: SQLAlchemy ORM models defining the database schema.
-   `schemas.py`: Pydantic schemas for API request/response validation.
-   `crud.py`: Core database logic (Create, Read, Update, Delete).
-   `database.py`: Database engine, session management, and connection logic.
-   `auth.py`: Google OAuth2 authentication and token verification.
-   `gemini_service.py`: Service for interacting with the Google Gemini API.
-   `storage_service.py`: Service for uploading images to Google Cloud Storage.
-   `config.py`: Centralized application configuration loaded from environment variables.
-   `Dockerfile`: Defines the application's Docker image.
-   `docker-compose.yml`: Orchestrates services for local development.
-   `docker-entrypoint.sh`: Container startup script that waits for the DB and runs migrations.
-   `alembic/`: Directory for Alembic database migrations.

## 5. Core Workflows

### User Authentication

1.  Client sends a Google OAuth ID token in the `Authorization` header.
2.  The backend verifies the token with Google.
3.  The user is fetched from the database or created if they are new.
4.  The authenticated `User` object is injected into the endpoint.

### Image Upload & Processing

1.  An authenticated user uploads an image and GPS coordinates to `/upload`.
2.  The image is sent to the Gemini API for analysis.
3.  If Gemini flags the image as "trash" (e.g., a selfie), the request is rejected.
4.  If valid, the image is uploaded to Google Cloud Storage.
5.  A new `Point` record is created in the database with the image URL, location, and AI-generated density score.
