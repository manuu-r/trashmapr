# TrashMapr - Technical Architecture

## 1. Backend Setup: FastAPI on Cloud Run

**Core Flow:** API endpoints for photo upload (with GPS metadata) → Trigger Vertex AI to analyze image for density (e.g., crowd/sparseness score) → Derive weight/category → Store URL and data in DB → Return success.

**AI Logic:** Use Gemini 1.5 Flash model. Prompt it to output a 1-4 category based on visual density (e.g., "Rate scene busyness: 1=empty, 4=packed"). Convert to weight (e.g., category / 4.0 for 0.25-1.0 scale).

**Storage:** Upload images to Cloud Storage (auto-generates public URLs for viewing). Use signed URLs for secure temp access if needed.

### Deployment Steps:

1. Create a GCP project; enable APIs: Cloud Run, Cloud SQL, Vertex AI, Cloud Storage.
2. Set up Cloud SQL instance: PostgreSQL 15+ with PostGIS extension (via console flags). Create table for points (columns: id, image_url, location as POINT, weight, category, timestamp, user_id).
3. Build FastAPI app: Define routes for POST /upload (handles file + geo), integrate Vertex AI client for inference, use SQLAlchemy ORM to insert into DB.
4. Containerize: Simple Dockerfile with Python 3.12, pip-install FastAPI/Uvicorn/SQLAlchemy/psycopg2/google-cloud-aiplatform/google-cloud-storage.
5. Deploy to Cloud Run: `gcloud run deploy --source .` (auto-scales, handles concurrency).

**Query Endpoint:** GET /points?bounds=lat1,lng1,lat2,lng2 — Uses PostGIS ST_Intersects for efficient fetching within map view.

## 2. Database: Cloud SQL (PostgreSQL/PostGIS)

**Why?** Handles geo-queries natively (e.g., fetch points in bounding box), indexes for speed. Managed backups/scaling.

### Key Features for You:

- Store location as GEOGRAPHY(POINT) for accurate lat/lng.
- Index on location for fast heatmap data pulls.
- Query example concept: Select points where location overlaps a polygon, ordered by timestamp.

**Connection:** FastAPI connects via connection string; use connection pooling for Cloud Run's stateless nature.

## 3. Frontend: Flutter App (Mobile)

### Capture Flow:
Use device camera + GPS plugins to grab photo + location. Send to backend API on submit (AI happens server-side).

### Viewing/Heatmap:

- **Base map:** Flutter Map with OpenStreetMap tiles (free).
- **Heatmap:** Overlay plugin like heatmap_layer; feed it fetched points (lat/lng + weight).
- **Clickable Photos:** Render markers (e.g., small thumbnails) at each point. Tap opens a full-screen modal with the image URL loaded via Image.network.
- **Fetch Data:** On map load/zoom, query backend for points in current bounds; update heatmap dynamically.

**Simplicity Tip:** Start with a single map screen; add pull-to-refresh for real-time updates.

## 4. Frontend: React Website (Simple)

- **Map Library:** Leaflet.js (lightweight, free OSM tiles).
- **Heatmap:** Leaflet.heat plugin; load points from API, pass array of {lat, lng, weight}.
- **Clickable Photos:** Use Leaflet markers with popups (thumbnail + click to enlarge in modal via react-modal).
- **Structure:** Single-page app with App.js handling map init, useEffect for API fetch on view change. Deploy to Netlify/Vercel for free.

**Simplicity Tip:** No auth/state mgmt needed for MVP—hardcode API base URL.

## 5. Integrations & Polish

- **Auth:** Add Firebase Auth to both frontends; pass token to FastAPI for user_id validation.
- **Real-Time:** For live updates, use Cloud Pub/Sub to trigger webhooks on new uploads, or poll API every 30s.
- **Costs/Scaling:** Free tiers cover dev (e.g., Cloud Run 2M requests/month). Monitor with GCP Logging.
- **Testing:** Upload sample photos manually via Postman; verify AI weights (tune prompt if inconsistent); test geo-queries with pgAdmin connected to Cloud SQL.

## Next Steps

If AI accuracy dips, fine-tune with few-shot examples in Gemini prompt. For denser heatmaps, aggregate weights server-side in queries.
