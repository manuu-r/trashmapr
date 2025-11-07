# TrashMapr

TrashMapr is a geo-photo density mapping application with AI classification. It allows users to upload photos of trash, which are then analyzed by an AI to determine the type of trash. The data is then displayed on a map to visualize trash density.

## Architecture

The project is composed of three main components:

*   **Backend**: A FastAPI application that serves as the API for the clients.
*   **Mobile App**: A Flutter application for iOS and Android that allows users to upload photos.
*   **Web App**: A React application that displays a map of the collected data.

For a more detailed explanation of the architecture, please see the [Architecture Overview](docs/architecture.md).

## Getting Started

### Prerequisites

*   Docker
*   Flutter SDK
*   Node.js and npm

### Installation

**Backend**

```bash
# Navigate to the backend directory
cd backend

# Build and run the Docker containers
docker-compose up -d --build
```

**Flutter App**

```bash
# Navigate to the flutter directory
cd flutter

# Install dependencies
flutter pub get

# Run the app
flutter run
```

**React App**

```bash
# Navigate to the react directory
cd react

# Install dependencies
npm install

# Run the app
npm run dev
```
