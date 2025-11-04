# Geo-Photo Density Map Frontend (Google Maps Edition)

This is a modern React 18+ frontend for a public geo-photo density map viewer. It's built with Vite, TypeScript, and styled with Tailwind CSS. The mapping functionality is powered by Google Maps Platform.

## Features

- **Interactive Map**: Pan and zoom with Google Maps.
- **Heatmap Layer**: Visualizes photo density with weights.
- **Custom Markers**: Displays image thumbnails directly on the map.
- **Image Modal**: Click a thumbnail to view the full-size image and its details.
- **Responsive Design**: Clean, modern UI that works on all screen sizes.
- **Geolocation**: Automatically centers the map on your current location on load.

## Tech Stack

- **Framework**: React 18+
- **Build Tool**: Vite
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **Mapping**: Google Maps Platform (via `@react-google-maps/api`)
- **Modals**: react-modal

## Setup and Development

### Prerequisites

- Node.js (v18 or higher)
- npm or yarn
- A Google Maps API Key with the "Maps JavaScript API" and "Maps Datasets API" enabled.

### Installation

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd geo-photo-density-map-frontend
    ```

2.  **Install dependencies:**
    ```bash
    npm install
    ```

3.  **Set Backend URL:**
    Open `hooks/usePoints.ts` and replace the placeholder URL with the URL of your running FastAPI backend.
    ```typescript
    // hooks/usePoints.ts
    const API_URL = 'https://your-backend-api.run.app'; // <-- CHANGE THIS
    ```

**Note on API Key**: The Google Maps API key has been hardcoded directly into the map component (`src/components/MapView.tsx`) for simplicity. For a production application, it is strongly recommended to manage this key using environment variables to avoid exposing it in your source code.

### Running the Development Server

To start the Vite development server, run:

```bash
npm run dev
```

The application will be available at `http://localhost:5173`.

## Building for Production

To create a production build, run:

```bash
npm run build
```

The optimized static files will be generated in the `dist/` directory.

## Deployment

This application is designed to be deployed as a static site on platforms like Vercel, Netlify, or GitHub Pages.

### Deploying to Vercel/Netlify

1.  Push your code to a Git repository (GitHub, GitLab, etc.).
2.  Connect your repository to your Vercel or Netlify account.
3.  Configure the build settings:
    -   **Build Command**: `npm run build`
    -   **Output Directory**: `dist`

Deploy the site. The platform will automatically build and host your application. Since the API key is hardcoded, no environment variable configuration is needed on the deployment platform.