# TrashMapr Backend API

A FastAPI backend for a geo-tagged photo app with AI-powered trash classification using Google Cloud services.

## Features

- Google OAuth authentication with user management
- Image upload to GCS (Google Cloud Storage)
- AI-powered image classification using Gemini API
- Automatic trash detection (rejects selfies, memes, non-scene images)
- Density categorization (1-4 scale)
- PostGIS-enabled database for geographic queries
- User accounts with relationship to uploaded images
- Public endpoints for viewing data
- Protected endpoints for uploads

## Tech Stack

- **Framework**: FastAPI 0.115+ with async support
- **Database**: Google AlloyDB for PostgreSQL with PostGIS
  - SQLAlchemy 2.0.44+ (async ORM)
  - asyncpg 0.30+ (PostgreSQL driver)
  - GeoAlchemy2 0.18+ (PostGIS support)
  - Alembic 1.17+ (migrations)
- **Storage**: Google Cloud Storage 2.20+
- **AI**: Google Gemini API 0.8+ (Gemini 2.5 models)
- **Auth**: Google OAuth 2.0 (authlib 1.3+)
- **Validation**: Pydantic 2.12+ with email support
- **Server**: Uvicorn 0.38+ with standard extras
- **Containerization**: Docker & Docker Compose
- **Python Version**: 3.10+ (3.12 recommended)

**Note**: All services run on Google Cloud Platform - no local database setup required.

## Project Structure

```
backend/
├── main.py                      # FastAPI application and routes
├── models.py                    # SQLAlchemy models (User, Point)
├── schemas.py                   # Pydantic schemas
├── database.py                  # Database configuration
├── crud.py                      # Database operations
├── auth.py                      # Google OAuth authentication
├── gemini_service.py            # Gemini API integration
├── storage_service.py           # GCS operations
├── requirements.txt             # Python dependencies
├── Dockerfile                   # Container configuration
├── docker-compose.yml           # Docker Compose configuration
├── Dockerfile                   # Container configuration
├── docker-entrypoint.sh         # Container startup script
├── .env.example                 # Environment variables template
├── .gitignore                   # Git exclusions
├── .dockerignore                # Docker build exclusions
├── alembic/                     # Database migrations
│   ├── env.py
│   ├── script.py.mako
│   └── versions/
│       ├── 001_initial_migration.py
│       └── 002_add_user_table.py
└── alembic.ini                  # Alembic configuration
```

## Quick Start with Docker Compose (Recommended)

### Prerequisites

Before starting, ensure you have:
1. **Google Cloud Project** set up
2. **AlloyDB instance** created with PostGIS enabled
3. **GCS bucket** created
4. **Google OAuth 2.0 credentials** configured
5. **Gemini API** enabled and API key obtained
6. **Service account JSON** with necessary permissions

### Setup

1. **Copy and configure environment file:**
```bash
cp .env.example .env
```

2. **Edit `.env` with your Google Cloud credentials:**
```env
# AlloyDB Connection
ALLOYDB_CONNECTION_URI=postgresql+asyncpg://user:password@10.0.0.5:5432/trashmapr

# Google Cloud Services
GOOGLE_OAUTH_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_OAUTH_CLIENT_SECRET=your-client-secret
GEMINI_API_KEY=your-gemini-api-key
GCS_BUCKET_NAME=your-gcs-bucket-name

# Service Account (path to your credentials file)
GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcloud/application_default_credentials.json

# Application
SECRET_KEY=your-secret-key-change-in-production
```

3. **Start the API:**
```bash
docker-compose up -d
```

This will:
- Start **FastAPI backend** on port 8000
- **Connect to Google AlloyDB** (no local database)
- **Run database migrations automatically** on startup
- **Connect to GCS and Gemini API**

4. **View logs:**
```bash
# View logs
docker-compose logs -f

# Check migration status
docker-compose logs api | grep -i migration
```

5. **Access the API:**
- API: http://localhost:8000
- Interactive docs: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- Health check: http://localhost:8000/health

6. **Stop service:**
```bash
docker-compose down
```

## Manual Setup (Without Docker)

### Prerequisites

- **Python 3.10+** (3.12 recommended, 3.13 & 3.14 supported)
- Google Cloud Project with:
  - AlloyDB instance with PostGIS enabled
  - Google Cloud Storage bucket
  - Google OAuth 2.0 credentials
  - Gemini API enabled
  - Service account with appropriate permissions

### Installation

1. **Navigate to backend directory:**
```bash
cd backend
```

2. **Create virtual environment:**
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. **Install dependencies:**
```bash
pip install -r requirements.txt
```

4. **Configure environment:**
```bash
cp .env.example .env
# Edit .env with your credentials
```

5. **Run migrations:**
```bash
alembic upgrade head
```

6. **Start server:**
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## Database Schema

### Users Table

| Column | Type | Description |
|--------|------|-------------|
| id | Integer | Primary key (auto-increment) |
| email | String(255) | Unique email from Google OAuth |
| name | String(255) | User's display name |
| picture | Text | Profile picture URL |
| created_at | Timestamp | Account creation time |
| updated_at | Timestamp | Last update time |

### Points Table

| Column | Type | Description |
|--------|------|-------------|
| id | Integer | Primary key (auto-increment) |
| user_id | Integer | Foreign key to users.id |
| image_url | Text | Public GCS URL |
| location | Geography | PostGIS POINT (lat/lng) |
| weight | Float | 0.25 to 1.0 |
| category | Integer | 1-4 (density level) |
| is_trash | Boolean | Flag for rejected images |
| timestamp | Timestamp | Upload time (UTC) |

**Relationships:**
- User has many Points (one-to-many)
- Point belongs to one User (with CASCADE delete)

**Indexes:**
- `users.email` - Unique, B-tree
- `points.user_id` - B-tree, Foreign key
- `points.location` - GIST spatial index

## API Endpoints

### Public Endpoints

#### GET `/`
Health check and API information.

#### GET `/health`
Service health check.

#### GET `/points`
Get all points within a bounding box.

**Query Parameters:**
- `lat1`: Southwest latitude
- `lng1`: Southwest longitude
- `lat2`: Northeast latitude
- `lng2`: Northeast longitude

**Response:**
```json
[
  {
    "id": 1,
    "image_url": "https://storage.googleapis.com/...",
    "location": {"lat": 37.7749, "lng": -122.4194},
    "weight": 0.75,
    "category": 3,
    "timestamp": "2025-01-01T12:00:00Z",
    "user_id": 1
  }
]
```

### Protected Endpoints (Require Authentication)

All protected endpoints require a Google OAuth ID token in the `Authorization` header:
```
Authorization: Bearer <google-oauth-id-token>
```

#### POST `/upload`
Upload an image with GPS coordinates.

**Form Data:**
- `file`: Image file (multipart)

**Query Parameters:**
- `lat`: Latitude
- `lng`: Longitude

**Response:**
```json
{
  "success": true,
  "message": "Image uploaded successfully",
  "point_id": 123,
  "category": 3,
  "weight": 0.75
}
```

**Error (Trash Image):**
```json
{
  "detail": "Image rejected: This appears to be a trash image..."
}
```

#### GET `/my-uploads`
Get all uploads by the authenticated user.

**Response:**
```json
[
  {
    "id": 1,
    "image_url": "https://storage.googleapis.com/...",
    "location": {"lat": 37.7749, "lng": -122.4194},
    "weight": 0.75,
    "category": 3,
    "timestamp": "2025-01-01T12:00:00Z",
    "user_id": 1
  }
]
```

#### GET `/me`
Get current user information.

**Response:**
```json
{
  "id": 1,
  "email": "user@example.com",
  "name": "John Doe",
  "picture": "https://lh3.googleusercontent.com/...",
  "created_at": "2025-01-01T10:00:00Z"
}
```

## Authentication Flow

1. **Frontend** obtains Google OAuth ID token
2. **Frontend** sends token in `Authorization: Bearer <token>` header
3. **Backend** verifies token with Google
4. **Backend** extracts user info (email, name, picture)
5. **Backend** creates or updates user in database
6. **Backend** returns User object for use in endpoints

## Image Classification

Images are analyzed by Gemini API with the following logic:

1. **Trash Detection**: Rejects selfies, memes, screenshots, indoor scenes
2. **Density Rating**: Valid outdoor scenes are rated 1-4:
   - 1: Low/sparse (few objects, open space)
   - 2: Medium (moderate activity)
   - 3: High (busy scene)
   - 4: Very high (extremely crowded)

3. **Weight Calculation**: `weight = category / 4.0` (0.25 to 1.0)

## Migrations

### Create New Migration

```bash
alembic revision --autogenerate -m "Description of changes"
```

### Apply Migrations

```bash
alembic upgrade head
```

### Rollback Migration

```bash
alembic downgrade -1
```

### View Migration History

```bash
alembic history
```

## Deployment

### Cloud Run Deployment

1. **Build and deploy:**
```bash
gcloud run deploy trashmapr-backend \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars GOOGLE_OAUTH_CLIENT_ID=...,GEMINI_API_KEY=...,ALLOYDB_CONNECTION_URI=...,GCS_BUCKET_NAME=...,SECRET_KEY=...
```

2. **Using Cloud Build:**
```bash
gcloud builds submit --config cloudbuild.yaml
```

### Docker Image Build

```bash
docker build -t trashmapr-backend .
docker run -p 8080:8080 --env-file .env trashmapr-backend
```

## Environment Variables

See `.env.example` for all available configuration options.

### Required Variables

| Variable | Description |
|----------|-------------|
| ALLOYDB_CONNECTION_URI | AlloyDB/Cloud SQL connection string |
| GOOGLE_OAUTH_CLIENT_ID | Google OAuth client ID |
| GOOGLE_OAUTH_CLIENT_SECRET | Google OAuth client secret |
| GEMINI_API_KEY | Gemini API key |
| GCS_BUCKET_NAME | GCS bucket name |
| SECRET_KEY | Secret key for JWT signing |
| GOOGLE_APPLICATION_CREDENTIALS | Path to service account JSON |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| API_PORT | 8000 | External API port |
| OAUTH_REDIRECT_URI | http://localhost:8000/auth/callback | OAuth callback URL |
| GCP_PROJECT_ID | - | Google Cloud Project ID |
| GCP_REGION | - | Google Cloud Region |

## Development

### Hot Reload

Source code is mounted as a volume, so changes are automatically reflected:

```bash
docker-compose up
```

The server will reload when you edit files.

### Database Management

Connect to AlloyDB using Cloud SQL Proxy or direct connection:

**Using Cloud SQL Proxy:**
```bash
# Download and run Cloud SQL Proxy
./cloud-sql-proxy <INSTANCE_CONNECTION_NAME>

# Connect with psql
psql "host=127.0.0.1 port=5432 dbname=trashmapr user=your-user"
```

**Using psql directly (if network access is configured):**
```bash
psql "host=<ALLOYDB_IP> port=5432 dbname=trashmapr user=your-user"
```

### Run Migrations Manually

Migrations run automatically on container startup, but you can run them manually:

```bash
docker-compose exec api alembic upgrade head

# Create new migration
docker-compose exec api alembic revision --autogenerate -m "description"

# Rollback migration
docker-compose exec api alembic downgrade -1
```

### Access Database via Container

```bash
# Run psql commands through the API container
docker-compose exec api python -c "
import asyncio
from database import engine
asyncio.run(engine.execute('SELECT version()'))
"
```

### Rebuild Containers

After updating requirements.txt or Dockerfile:

```bash
docker-compose up --build
```

## Testing

### Manual Testing with curl

```bash
# Health check
curl http://localhost:8000/health

# Get points (public)
curl "http://localhost:8000/points?lat1=37.7&lng1=-122.5&lat2=37.8&lng2=-122.4"

# Upload image (requires auth token)
curl -X POST http://localhost:8000/upload \
  -H "Authorization: Bearer <google-oauth-token>" \
  -F "file=@image.jpg" \
  -F "lat=37.7749" \
  -F "lng=-122.4194"
```

## Security Notes

- Never commit `.env` file or credentials
- Use environment variables for all secrets
- Configure CORS appropriately for production
- Implement rate limiting for production
- Use HTTPS in production
- Validate all user inputs
- Use Google Secret Manager for production secrets
- Enable Cloud Armor for DDoS protection
- Use Private IP for AlloyDB connections

## Troubleshooting

### Database Connection Issues

```bash
# Check if API is running
docker-compose ps

# Check API logs for database connection errors
docker-compose logs api | grep -i database

# Test AlloyDB connection
docker-compose exec api python -c "
import asyncio
from database import init_db
asyncio.run(init_db())
"

# Verify environment variables
docker-compose exec api env | grep ALLOYDB
```

**Common Issues:**
- **Connection timeout**: Check AlloyDB instance is running and accessible
- **Authentication failed**: Verify credentials in `ALLOYDB_CONNECTION_URI`
- **Network error**: Ensure VPC/network connectivity to AlloyDB
- **SSL/TLS error**: Check if SSL is required for your AlloyDB instance

### Migration Issues

```bash
# Check current migration version
docker-compose exec api alembic current

# View migration history
docker-compose exec api alembic history

# Check migration logs
docker-compose logs api | grep -i migration
```

### API Not Starting

```bash
# Check API logs
docker-compose logs api

# Rebuild containers
docker-compose up --build

# Remove all containers and start fresh
docker-compose down -v
docker-compose up --build
```

### Port Already in Use

```bash
# Change ports in .env file
API_PORT=8001
POSTGRES_PORT=5433
PGADMIN_PORT=5051

# Then restart
docker-compose up -d
```

## License

MIT
