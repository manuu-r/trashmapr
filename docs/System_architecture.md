# Architecture Diagrams and Detailed Documentation

This document provides a visual overview of the TrashMapR system architecture, data flows, and infrastructure, followed by a detailed explanation of the technical design.

## 1. System Architecture

This diagram shows the high-level relationship between the core components of the system, from the user-facing applications to the backend services on Google Cloud.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER LAYER                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│    ┌──────────────────────┐              ┌──────────────────────┐          │
│    │  Flutter Mobile App  │              │   React Web App      │          │
│    └──────────┬───────────┘              └──────────┬───────────┘          │
│               │                                     │                       │
└───────────────┼─────────────────────────────────────┼───────────────────────┘
                │                                     │
                │ HTTPS: Request                      │ HTTPS: Request
                │ Signed URL                          │ Map Data
                │                                     │
┌───────────────▼─────────────────────────────────────▼───────────────────────┐
│                  GOOGLE CLOUD PLATFORM (GCP)                                │
├─────────────────────────────────────────────────────────────────────────────┤
│               │                                     │                       │
│         ┌─────▼─────────────────────────────────────▼─────────┐             │
│         │              API Gateway                            │             │
│         └─────┬───────────────────────────────────────────────┘             │
│               │ Forwards API Requests                                       │
│         ┌─────▼─────────────────────────────────────┐                       │
│         │    Cloud Run: FastAPI Backend            │                       │
│         │                                           │                       │
│         │  • Generates Signed URL                   │                       │
│         │  • Serves Data                            │                       │
│         └───┬──────────────────┬────────────────────┘                       │
│             │                  │                                            │
│             │                  │ Reads/Writes                               │
│             │                  │                                            │
│  ┌──────────▼─────────┐  ┌─────▼──────────────────────┐                    │
│  │  Cloud Storage     │  │  Cloud SQL: PostgreSQL     │                    │
│  │     Bucket         │  │                            │                    │
│  └──────────┬─────────┘  └─────▲──────────────────────┘                    │
│             │                   │                                           │
│             │ On-Object-Create  │ Reads/Writes                              │
│             │ (Event)           │                                           │
│  ┌──────────▼─────────┐  ┌──────┴──────────────────┐                       │
│  │  Pub/Sub Topic     │  │  Cloud Run: Worker      │                       │
│  │                    ├──► (Subscribes to Pub/Sub) │                       │
│  └────────────────────┘  └──────┬──────────────────┘                       │
│             Push Message         │                                          │
│                                  │ Sends Notification                       │
│                         ┌────────▼─────────────────┐                        │
│                         │   Firebase (FCM)         │                        │
│                         └────────┬─────────────────┘                        │
│                                  │                                          │
└──────────────────────────────────┼──────────────────────────────────────────┘
                                   │ Push Notification
                                   │
                         ┌─────────▼──────────┐
                         │ Flutter Mobile App │
                         └────────────────────┘
```

## 2. Upload Flow (Sequence Diagram)

This diagram details the sequence of events for a user uploading an image, from requesting permission to the file landing in Cloud Storage.

```
┌─────────────┐                ┌──────────────────┐            ┌─────────────────────────┐
│ Flutter App │                │ FastAPI Backend  │            │ Google Cloud Storage    │
└──────┬──────┘                └────────┬─────────┘            └────────┬────────────────┘
       │                                │                               │
       │ 1. Authenticate & Request      │                               │
       │    Signed URL (for file.jpg)   │                               │
       ├───────────────────────────────►│                               │
       │                                │                               │
       │                                │ 2. Verify User &              │
       │                                │    Authorize Request          │
       │                                ├───┐                           │
       │                                │   │                           │
       │                                │◄──┘                           │
       │                                │                               │
       │                                │ 3. Generate Signed URL        │
       │                                │    for 'file.jpg'             │
       │                                ├──────────────────────────────►│
       │                                │                               │
       │                                │ 4. Return Signed URL          │
       │                                │◄──────────────────────────────┤
       │                                │                               │
       │ 5. Send Signed URL to App      │                               │
       │◄───────────────────────────────┤                               │
       │                                │                               │
       │ 6. Upload 'file.jpg' directly via Signed URL                   │
       ├────────────────────────────────────────────────────────────────►│
       │                                │                               │
       │                                │ 7. Confirm Upload             │
       │                                │    (HTTP 200 OK)              │
       │◄────────────────────────────────────────────────────────────────┤
       │                                │                               │
```

## 3. Event-Driven Processing Flow

This diagram illustrates the asynchronous workflow that begins after the file upload is complete. It highlights the decoupled nature of the system.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          DIRECT UPLOAD                                   │
│                                                                          │
│                    ┌────────────────────────────┐                        │
│                    │ Mobile App uploads to GCS  │                        │
│                    └────────────┬───────────────┘                        │
│                                 │                                        │
└─────────────────────────────────┼────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────────────┐
│              ASYNCHRONOUS PROCESSING PIPELINE                            │
│                                                                          │
│                  ┌────────────────────────────────┐                      │
│                  │ 1. GCS triggers Pub/Sub event  │                      │
│                  └────────────┬───────────────────┘                      │
│                               │                                          │
│                               ▼                                          │
│                  ┌────────────────────────────────────┐                  │
│                  │ 2. Pub/Sub pushes message to      │                  │
│                  │    Worker                          │                  │
│                  └────────────┬───────────────────────┘                  │
│                               │                                          │
│                               ▼                                          │
│                  ┌────────────────────────────────┐                      │
│                  │ 3. Worker processes metadata   │                      │
│                  └────────────┬───────────────────┘                      │
│                               │                                          │
│                  ┌────────────┴────────────┐                             │
│                  │                         │                             │
│                  ▼                         ▼                             │
│    ┌──────────────────────────┐  ┌─────────────────────────────────┐    │
│    │ 4. Worker updates        │  │ 5. Worker sends push            │    │
│    │    PostgreSQL DB         │  │    notification via FCM         │    │
│    └──────────────────────────┘  └─────────────┬───────────────────┘    │
│                                                 │                        │
└─────────────────────────────────────────────────┼────────────────────────┘
                                                  │
                                                  ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                         USER FEEDBACK                                    │
│                                                                          │
│                  ┌────────────────────────────────┐                      │
│                  │ 6. User receives notification  │                      │
│                  └────────────────────────────────┘                      │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

## 4. Infrastructure Layout

This diagram focuses on the Google Cloud services and their interactions, showing the clear boundaries between them.

```
                               ┌──────┐
                               │ User │
                               └───┬──┘
                                   │ Interacts with
                                   │
┌──────────────────────────────────▼──────────────────────────────────────┐
│                           USER-FACING                                   │
│                                                                         │
│                      ┌──────────────────────┐                           │
│                      │  Flutter/React Apps  │                           │
│                      └──┬────────────────┬──┘                           │
│                         │                │                              │
└─────────────────────────┼────────────────┼──────────────────────────────┘
                          │                │
                          │ API Calls      │ Direct Upload
                          │                │
┌─────────────────────────▼────────────────▼──────────────────────────────┐
│                    GOOGLE CLOUD PROJECT                                 │
│                                                                         │
│                         │                │                              │
│            ┌────────────▼─────┐          │                              │
│            │   API Gateway    │          │                              │
│            └────────┬─────────┘          │                              │
│                     │                    │                              │
│  ┌──────────────────┼────────────────────┼─────────────────────────┐    │
│  │     SERVICES     │                    │                         │    │
│  │                  │                    │                         │    │
│  │      ┌───────────▼─────────────┐      │                         │    │
│  │      │ Cloud Run: Backend API  │      │                         │    │
│  │      │                         │      │                         │    │
│  │      └───────────┬─────────────┘      │                         │    │
│  │                  │                    │                         │    │
│  │                  │ Read/Write         │                         │    │
│  │                  │                    │                         │    │
│  │          ┌───────▼──────────┐         │                         │    │
│  │          │  Cloud SQL (DB)  │◄────────┼───────────┐             │    │
│  │          └──────────────────┘         │           │             │    │
│  │                                       │           │             │    │
│  └───────────────────────────────────────┼───────────┼─────────────┘    │
│                                          │           │                  │
│  ┌───────────────────────────────────────┼───────────┼─────────────┐    │
│  │    EVENT-DRIVEN PIPELINE              │           │             │    │
│  │                                       │           │             │    │
│  │                  ┌────────────────────▼─────┐     │             │    │
│  │                  │   Cloud Storage          │     │             │    │
│  │                  └────────┬─────────────────┘     │             │    │
│  │                           │ Triggers              │             │    │
│  │                           │                       │             │    │
│  │                  ┌────────▼─────────────┐         │             │    │
│  │                  │      Pub/Sub         │         │             │    │
│  │                  └────────┬─────────────┘         │             │    │
│  │                           │ Delivers              │             │    │
│  │                           │                       │             │    │
│  │                  ┌────────▼───────────────┐       │             │    │
│  │                  │ Cloud Run: Worker      │       │             │    │
│  │                  │                        ├───────┘             │    │
│  │                  └────────┬───────────────┘                     │    │
│  │                           │ Via API                             │    │
│  │                           │                                     │    │
│  │                  ┌────────▼────────────────────┐                │    │
│  │                  │ Firebase Cloud Messaging    │                │    │
│  │                  └────────┬────────────────────┘                │    │
│  │                           │                                     │    │
│  └───────────────────────────┼─────────────────────────────────────┘    │
│                              │                                          │
└──────────────────────────────┼──────────────────────────────────────────┘
                               │ Notifies
                               │
                          ┌────▼────┐
                          │  User   │
                          └─────────┘
```

---

## 5. Detailed Architecture

This section provides a detailed explanation of the architectural decisions, patterns, and technical designs implemented in the TrashMapR system.

### 5.1. Core Principles

The system is built on a foundation of modern, cloud-native principles to ensure scalability, resilience, and maintainability.

- **Serverless First**: All backend components (API, workers) are designed to run on Google Cloud Run, a fully managed serverless platform. This eliminates the need for server management, provides automatic scaling (including scale-to-zero), and follows a pay-per-use model.
- **Event-Driven**: The system leverages a message-based, event-driven architecture using Google Pub/Sub. This decouples the upload process from the data processing, making the system more resilient to failures and easier to extend. If the processing worker fails, events are retained in Pub/Sub and can be re-processed.
- **Decoupled Components**: Each service (backend, worker, frontend) has a single responsibility and communicates over well-defined APIs or messaging queues. This separation of concerns simplifies development, testing, and independent deployment.

### 5.2. Authentication and Authorization

Authentication is handled on the mobile app using **Google Sign-In**, which provides a secure and user-friendly way to verify user identity.

- **Token-Based Auth**: The mobile app sends the user's Google ID token to the FastAPI backend.
- **Backend Verification**: The backend verifies the token's integrity and authenticity with Google's authentication servers.
- **User Context**: Upon successful verification, the backend creates or retrieves the user's profile from the database. The user's unique ID is then embedded as metadata in the signed URL, securely linking the uploaded file to the user without requiring the user to pass credentials for the upload itself.

This approach ensures that all uploads are authenticated and auditable while keeping the upload process itself simple and secure.

### 5.3. Direct-to-Storage Upload Pattern

To maximize performance and minimize load on the backend API, the system uses a **direct-to-storage upload pattern** with Google Cloud Storage (GCS) signed URLs.

- **Why Signed URLs?**: A signed URL is a short-lived, secure URL that grants temporary, limited-permission access to a specific GCS object. This allows the mobile client to upload a file directly to the GCS bucket without having any GCP credentials of its own.
- **Process**:
    1. The mobile app requests permission to upload a file from the FastAPI backend.
    2. The backend generates a `v4` signed URL, specifying the exact object name and setting a short expiration time (e.g., 15 minutes).
    3. The backend also includes the user's ID and other relevant information as custom metadata in the signed URL configuration.
    4. The mobile app receives the URL and performs an HTTP `PUT` request directly to GCS.
- **Benefits**:
    - **Performance**: Large file uploads do not consume backend server resources or bandwidth.
    - **Scalability**: GCS is massively scalable, so the upload process is never a bottleneck.
    - **Security**: Permissions are granular, temporary, and controlled by the backend. The backend never has to handle the file data itself.

### 5.4. Asynchronous Processing with Pub/Sub

The core of the system's backend logic is asynchronous, triggered by events from Google Cloud Storage.

- **GCS to Pub/Sub Trigger**: The GCS bucket is configured to publish a message to a specific Pub/Sub topic whenever a new object is successfully created. This message contains metadata about the object, such as its name, size, and the custom metadata (including the user ID) attached during the signed URL generation.
- **Worker Service**: A dedicated, independent Cloud Run service (the "Worker") is subscribed to this Pub/Sub topic. When a new message is published, Pub/Sub pushes it to the Worker.
- **Responsibilities of the Worker**:
    - Parse the event message to get the file details and user ID.
    - Update the PostgreSQL database to record the new trash location.
    - (Optional) Perform additional processing, such as image analysis or resizing.
    - Trigger a push notification via Firebase Cloud Messaging (FCM) to inform the user of the successful submission.
- **Benefits**:
    - **Resilience**: If the Worker service is down or fails to process a message, Pub/Sub's built-in retry mechanisms and dead-letter queues ensure that no data is lost.
    - **Extensibility**: New services can easily be added to subscribe to the same Pub/Sub topic to perform additional tasks (e.g., analytics, moderation) without modifying the existing flow.

### 5.5. Public Data Access vs. Private Operations

The system maintains a clear separation between public data and private, authenticated operations.

- **Public Web App**: The React-based web app is a read-only client. It does not require user authentication. It communicates with a set of public, unsecured API endpoints on the FastAPI backend (e.g., `GET /api/v1/uploads`) to fetch location data for the heatmap.
- **Private Mobile App**: The Flutter app is for authenticated users only. All its interactions with the backend (requesting signed URLs, updating user profiles) are protected and require a valid authentication token.

This separation ensures that sensitive user actions are secure while public data remains easily accessible.
