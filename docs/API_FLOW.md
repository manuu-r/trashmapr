# API and Data Flow

This document outlines the primary API endpoints and data flow sequences for major operations within the TrashMapR system.

## Base URL

All API endpoints are prefixed with `/api/v1`

## Authentication

TrashMapR uses Google OAuth 2.0 for authentication. Protected endpoints require a Bearer token (Google ID token) in the Authorization header:

```
Authorization: Bearer <Google_ID_Token>
```

The backend verifies the token with Google's servers and automatically creates user accounts on first login.

---

## 1. Mobile App Flow (Flutter)

The mobile app interacts with the backend for authenticated operations.

### 1.1. User Authentication

- **Action**: User signs in with their Google account on the app
- **Flow**:
    1. The Flutter app uses the `google_sign_in` package to initiate the Google Sign-In flow
    2. Upon successful sign-in, the app receives a Google ID token
    3. For all subsequent API requests, the app includes this token in the Authorization header
    4. The backend automatically verifies the token and creates/retrieves the user account
- **Authentication Method**: HTTP Bearer Token (Google ID Token)
- **Protected Endpoints**: All requests to `/api/v1/upload/*`, `/api/v1/users/*`, `/api/v1/notifications/*`, and `/api/v1/points/my-uploads` require authentication

### 1.2. Get Current User Information

- **Action**: Retrieve the authenticated user's profile and statistics
- **Endpoint**: `GET /api/v1/users/me` (Protected)
- **Headers**:
    ```
    Authorization: Bearer <Google_ID_Token>
    ```
- **Response (Success - 200)**:
    ```json
    {
      "id": 123,
      "email": "user@example.com",
      "name": "User Name",
      "picture": "https://example.com/profile-picture.jpg",
      "fcm_token": "fcm_device_token_...",
      "total_points": 1250,
      "total_uploads": 5,
      "created_at": "2025-01-07T10:00:00Z"
    }
    ```

### 1.3. Request Signed URL for Upload

- **Action**: User captures an image and is ready to upload
- **Flow**: The app requests a secure, time-limited URL to upload the image directly to Google Cloud Storage
- **Endpoint**: `POST /api/v1/upload/signed-url` (Protected)
- **Query Parameters**:
    - `lat` (float, required): Latitude coordinate (-90 to 90)
    - `lng` (float, required): Longitude coordinate (-180 to 180)
    - `content_type` (string, optional): Image MIME type (default: "image/jpeg", accepts: "image/jpeg", "image/jpg", "image/png")
- **Headers**:
    ```
    Authorization: Bearer <Google_ID_Token>
    ```
- **Example Request**:
    ```
    POST /api/v1/upload/signed-url?lat=40.7128&lng=-74.0060&content_type=image/jpeg
    ```
- **Response (Success - 200)**:
    ```json
    {
      "upload_url": "https://storage.googleapis.com/YOUR_BUCKET_NAME/uploads/USER_EMAIL/TIMESTAMP_FILENAME.jpg",
      "file_name": "uploads/USER_EMAIL/TIMESTAMP_FILENAME.jpg",
      "expires_in": 900,
      "required_headers": {
        "Content-Type": "image/jpeg"
      }
    }
    ```
- **Post-Action**: 
    1. The app performs an HTTP `PUT` request to the `upload_url` with the image file
    2. The signed URL includes custom metadata (user_id, latitude, longitude, uploaded_at) that is automatically attached to the object in GCS
    3. Upon successful upload, GCS triggers a Pub/Sub notification to the Worker service

### 1.4. Register FCM Token for Push Notifications

- **Action**: The app receives a new Firebase Cloud Messaging (FCM) token on launch
- **Flow**: The app sends the token to the backend to enable push notifications
- **Endpoint**: `POST /api/v1/notifications/register-token` (Protected)
- **Headers**:
    ```
    Authorization: Bearer <Google_ID_Token>
    ```
- **Request Body**:
    ```json
    {
      "fcm_token": "firebase_cloud_messaging_device_token_..."
    }
    ```
- **Response (Success - 200)**:
    ```json
    {
      "success": true,
      "message": "FCM token registered successfully"
    }
    ```

### 1.5. Unregister FCM Token (Logout)

- **Action**: User logs out and the app should stop receiving notifications
- **Endpoint**: `DELETE /api/v1/notifications/unregister-token` (Protected)
- **Headers**:
    ```
    Authorization: Bearer <Google_ID_Token>
    ```
- **Response (Success - 200)**:
    ```json
    {
      "success": true,
      "message": "FCM token unregistered successfully"
    }
    ```

### 1.6. Get My Uploads

- **Action**: User wants to view their own upload history
- **Endpoint**: `GET /api/v1/points/my-uploads` (Protected)
- **Headers**:
    ```
    Authorization: Bearer <Google_ID_Token>
    ```
- **Response (Success - 200)**:
    ```json
    [
      {
        "id": 123,
        "image_url": "https://storage.googleapis.com/YOUR_BUCKET_NAME/uploads/...",
        "location": {
          "lat": 40.7128,
          "lng": -74.0060
        },
        "weight": 0.75,
        "category": 2,
        "timestamp": "2025-01-07T14:30:25Z",
        "user_id": 456
      }
    ]
    ```

### 1.7. Delete Upload

- **Action**: User wants to delete one of their uploads
- **Flow**: 
    1. The app sends a delete request for a specific point
    2. The backend verifies ownership and deletes both the database record and the image from GCS
    3. The user loses 250 points for the deletion
- **Endpoint**: `DELETE /api/v1/upload/{point_id}` (Protected)
- **Path Parameters**:
    - `point_id` (integer): ID of the point to delete
- **Headers**:
    ```
    Authorization: Bearer <Google_ID_Token>
    ```
- **Response (Success - 200)**:
    ```json
    {
      "success": true,
      "message": "Upload deleted successfully",
      "point_id": 123
    }
    ```
- **Error Responses**:
    - `404`: Point not found
    - `403`: User does not own this upload

---

## 2. Web App Flow (React)

The web app is public and only fetches data for display.

### 2.1. Get Points Within Bounding Box

- **Action**: The web app loads the main map view or user pans/zooms the map
- **Flow**: The app requests all trash point coordinates within the visible map area
- **Endpoint**: `GET /api/v1/points` (Public - No Authentication Required)
- **Query Parameters**:
    - `lat1` (float, required): Southwest latitude (-90 to 90)
    - `lng1` (float, required): Southwest longitude (-180 to 180)
    - `lat2` (float, required): Northeast latitude (-90 to 90)
    - `lng2` (float, required): Northeast longitude (-180 to 180)
- **Example Request**:
    ```
    GET /api/v1/points?lat1=40.7&lng1=-74.1&lat2=40.8&lng2=-74.0
    ```
- **Response (Success - 200)**:
    ```json
    [
      {
        "id": 789,
        "image_url": "https://storage.googleapis.com/YOUR_BUCKET_NAME/uploads/...",
        "location": {
          "lat": 40.7128,
          "lng": -74.0060
        },
        "weight": 0.75,
        "category": 2,
        "timestamp": "2025-01-07T14:30:25Z",
        "user_id": 456
      }
    ]
    ```
- **Notes**:
    - Excludes points marked as trash (is_trash = true)
    - Weight values: 0.25 (Light), 0.5 (Moderate), 0.75 (Heavy), 1.0 (Severe)
    - Category values: 1 (Light Litter), 2 (Moderate Trash), 3 (Heavy Debris), 4 (Severe Pollution)

---

## 3. Worker Flow (Internal, Event-Driven)

This flow is triggered by a Google Cloud Storage event via Pub/Sub, not by a direct API call.

### 3.1. Pub/Sub Message from GCS

- **Source**: Google Cloud Storage
- **Trigger**: A new file is successfully uploaded to the GCS bucket
- **Endpoint**: `POST /process-upload` (Internal - Called by Pub/Sub)
- **Message Format** (pushed to Worker by Pub/Sub):
    ```json
    {
      "message": {
        "data": "BASE64_ENCODED_GCS_NOTIFICATION_DATA",
        "attributes": {
          "bucketId": "YOUR_BUCKET_NAME",
          "objectId": "uploads/USER_EMAIL/TIMESTAMP_FILENAME.jpg"
        },
        "messageId": "MESSAGE_ID",
        "publishTime": "2025-01-07T14:30:26Z"
      },
      "subscription": "projects/YOUR_PROJECT_ID/subscriptions/YOUR_SUBSCRIPTION_NAME"
    }
    ```

### 3.2. Decoded GCS Notification (Base64-decoded `data` field)

```json
{
  "name": "uploads/USER_EMAIL/TIMESTAMP_FILENAME.jpg",
  "bucket": "YOUR_BUCKET_NAME",
  "contentType": "image/jpeg",
  "metadata": {
    "user_id": "123",
    "latitude": "40.7128",
    "longitude": "-74.0060",
    "uploaded_at": "2025-01-07T14:30:25Z"
  },
  "size": "2048576",
  "timeCreated": "2025-01-07T14:30:26Z"
}
```

### 3.3. Worker Processing Steps

1. **Receive & Decode**: The Worker service receives the Pub/Sub push message and base64-decodes the `data` payload
2. **Extract Metadata**: Parses the custom metadata (user_id, latitude, longitude) attached to the GCS object
3. **Download Image**: Downloads the image bytes from Google Cloud Storage
4. **AI Validation**: Sends the image to Google Gemini API for validation and categorization:
   - Validates if the image is a valid trash photo
   - Categorizes the trash (1-4)
   - Estimates the weight/severity (0.25-1.0)
5. **Decision Point**:
   - **If Accepted**:
     1. Creates a new record in the `points` table (PostgreSQL)
     2. Updates user statistics (total_uploads +1, total_points +250)
     3. Sends push notification to user via FCM (if FCM token exists)
     4. Returns success response
   - **If Rejected**:
     1. Deletes the image from GCS
     2. Sends rejection notification to user via FCM (if FCM token exists)
     3. Returns rejection response

### 3.4. Worker Response (Success)

```json
{
  "status": "success",
  "point_id": 789,
  "category": 2,
  "weight": 0.75,
  "user_id": 456
}
```

### 3.5. Worker Response (Rejected)

```json
{
  "status": "rejected",
  "file_name": "uploads/USER_EMAIL/TIMESTAMP_FILENAME.jpg",
  "message": "Image rejected by AI validation"
}
```

### 3.6. Push Notifications Sent by Worker

#### Image Accepted Notification

```json
{
  "notification": {
    "title": "Image Accepted!",
    "body": "You earned 250 points! Category: Moderate Trash"
  },
  "data": {
    "type": "image_accepted",
    "category": "2",
    "weight": "0.75",
    "points_earned": "250"
  }
}
```

#### Image Rejected Notification

```json
{
  "notification": {
    "title": "Image Rejected",
    "body": "Image doesn't meet quality standards. Please try again with a clearer trash photo."
  },
  "data": {
    "type": "image_rejected",
    "reason": "Image doesn't meet quality standards"
  }
}
```

---

## 4. Complete Upload Flow Sequence

```
1. [Mobile App] User captures image and taps "Upload"
                    ↓
2. [Mobile App] → GET /api/v1/upload/signed-url?lat=X&lng=Y
                    ↓
3. [Backend]    Generates signed URL with metadata (user_id, lat, lng)
                    ↓
4. [Backend]    → Returns signed URL (expires in 15 minutes)
                    ↓
5. [Mobile App] → PUT <signed_url> with image bytes
                    ↓
6. [GCS]        Image uploaded successfully
                    ↓
7. [GCS]        Triggers Pub/Sub notification with metadata
                    ↓
8. [Pub/Sub]    → POST /process-upload to Worker service
                    ↓
9. [Worker]     Downloads image from GCS
                    ↓
10. [Worker]    → Calls Gemini API for validation
                    ↓
11. [Gemini]    → Returns (is_valid, category, weight)
                    ↓
12. [Worker]    IF ACCEPTED:
                  - Creates point in database
                  - Updates user stats (+250 points)
                  - Sends FCM notification (accepted)
                IF REJECTED:
                  - Deletes image from GCS
                  - Sends FCM notification (rejected)
                    ↓
13. [Mobile App] Receives push notification
                    ↓
14. [Mobile App] Refreshes user stats/points list
```

---

## 5. Error Handling

### Authentication Errors

- **401 Unauthorized**: Invalid or expired Google ID token
- **403 Forbidden**: Valid token but user lacks permission (e.g., trying to delete another user's upload)

### Validation Errors

- **400 Bad Request**: Invalid parameters (e.g., latitude out of range, invalid bounding box)
- **404 Not Found**: Resource not found (e.g., point_id doesn't exist)

### Server Errors

- **500 Internal Server Error**: Backend processing error (e.g., failed to generate signed URL, database error)

All error responses follow this format:

```json
{
  "detail": "Error message describing what went wrong"
}
```

---

## 6. Data Models Reference

### Category Values

| Value | Name              | Description                    |
|-------|-------------------|--------------------------------|
| 1     | Light Litter      | Small items, minimal impact    |
| 2     | Moderate Trash    | Medium accumulation            |
| 3     | Heavy Debris      | Large piles or heavy items     |
| 4     | Severe Pollution  | Extreme pollution levels       |

### Weight/Severity Values

| Value | Description        |
|-------|--------------------|
| 0.25  | Light             |
| 0.50  | Moderate          |
| 0.75  | Heavy             |
| 1.00  | Severe            |

### Points System

- **Upload Accepted**: +250 points
- **Upload Deleted**: -250 points

---

## 7. Rate Limiting & Quotas

- **Signed URL Expiration**: 15 minutes (900 seconds)
- **Supported Image Types**: JPEG, JPG, PNG
- **Pub/Sub Retry Policy**: Automatic retries with exponential backoff for failed worker processing
