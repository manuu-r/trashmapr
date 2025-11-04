# TrashMapr - Geo-Photo Density Mapping App

A modern Flutter 3+ mobile application for geo-photo density mapping with AI-powered classification. Users can capture photos with GPS coordinates, upload them to a FastAPI backend for AI classification, and view a public heatmap with clickable markers.

## Features

### Authentication
- **Google Sign-In**: Required for photo capture/upload and viewing personal uploads
- **Public Map View**: Accessible without authentication
- **Token Persistence**: JWT tokens managed securely for API authentication

### Photo Capture & Upload
- **Camera Integration**: Take photos directly in the app
- **Auto GPS**: Automatic location tagging using device GPS
- **Preview & Confirm**: Review photos before uploading
- **AI Classification**: Backend Gemini AI classifies density (1-4) or rejects invalid images
- **Real-time Feedback**: Upload status and classification results displayed immediately

### Interactive Map
- **FlutterMap with OSM Tiles**: Open-source map implementation
- **Heatmap Visualization**: Color-coded density visualization (blue=low, red=high)
  - Category 1: Low Density (Blue)
  - Category 2: Medium Density (Yellow)
  - Category 3: High Density (Orange)
  - Category 4: Very High Density (Red)
- **Clickable Markers**: Tap photo thumbnails to view full details
- **Dynamic Loading**: Points fetched based on map bounds (debounced)
- **Current Location**: Auto-center on user's location

### My Uploads
- **Personal Gallery**: View all your uploaded points
- **Detailed Information**: See category, weight, location, and timestamp
- **Delete Functionality**: Remove unwanted uploads
- **Pull to Refresh**: Update your uploads list

### UI/UX
- **Material Design 3**: Modern, clean interface
- **Responsive Design**: Mobile-first, adaptive layouts
- **Dark Mode Support**: Automatic theme switching
- **Loading States**: Spinners and progress indicators
- **Error Handling**: User-friendly error messages

## Backend API Integration

The app connects to a FastAPI backend with the following endpoints:

### Public Endpoints
- `GET /points?lat1={sw_lat}&lng1={sw_lng}&lat2={ne_lat}&lng2={ne_lng}`
  - Returns points within map bounds
  - Response: `[{id, image_url, location: {lat, lng}, weight, category, timestamp}]`

### Protected Endpoints (Requires Google Auth JWT)
- `POST /upload?lat={lat}&lng={lng}` (multipart form-data)
  - Uploads photo to Google Cloud Storage
  - AI classification via Gemini
  - Returns classified point or rejection
  
- `GET /my-uploads`
  - Returns user's uploaded points only

- `DELETE /upload/{id}`
  - Deletes a user's upload

- `POST /report/{id}` (stub for future)
  - Reports a point

## Prerequisites

- **Flutter SDK**: 3.0 or higher
- **Dart SDK**: 3.0 or higher
- **iOS**: Xcode 14+ (for iOS development)
- **Android**: Android Studio with SDK 21+ (for Android development)
- **Google Cloud Project**: For Google Sign-In configuration

## Setup Instructions

### 1. Clone and Install Dependencies

```bash
cd flutter
flutter pub get
```

### 2. Configure Environment Variables

Copy `.env.example` to `.env` and update with your backend URL:

```bash
cp .env.example .env
```

Edit `.env`:
```
API_URL=https://your-backend-url.run.app
```

### 3. Configure Google Sign-In

#### Android Configuration

1. Create a Firebase project at [https://console.firebase.google.com](https://console.firebase.google.com)
2. Add an Android app to your Firebase project
3. Download `google-services.json`
4. Place it in `android/app/google-services.json`
5. Update `android/app/build.gradle`:

```gradle
dependencies {
    implementation 'com.google.firebase:firebase-auth'
}

apply plugin: 'com.google.gms.google-services'
```

6. Update `android/build.gradle`:

```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.3.15'
}
```

#### iOS Configuration

1. Add an iOS app to your Firebase project
2. Download `GoogleService-Info.plist`
3. Place it in `ios/Runner/GoogleService-Info.plist`
4. Update `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
        </array>
    </dict>
</array>
```

### 4. Configure Permissions

#### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

#### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to capture photos for density mapping</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to tag photos with GPS coordinates</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>We need your location to tag photos with GPS coordinates</string>
```

## Running the App

### Development Mode

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android

# Specific device
flutter devices
flutter run -d <device-id>
```

### Building for Production

#### Android APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

#### Android App Bundle (for Google Play)

```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

#### iOS

```bash
flutter build ios --release
# Then open ios/Runner.xcworkspace in Xcode
# Archive and upload to App Store Connect
```

## Project Structure

```
flutter/
├── lib/
│   ├── main.dart                 # App entry point, navigation, providers
│   ├── models/
│   │   └── point.dart            # Point data model
│   ├── screens/
│   │   ├── auth_screen.dart      # Google Sign-In screen
│   │   ├── map_screen.dart       # Map with heatmap and markers
│   │   ├── capture_screen.dart   # Camera and upload screen
│   │   └── my_uploads_screen.dart # User's uploads list
│   ├── services/
│   │   ├── auth_service.dart     # Google Sign-In service
│   │   └── api_service.dart      # Backend API communication
│   └── widgets/
│       └── image_modal.dart      # Point detail modal
├── android/                       # Android-specific configuration
├── ios/                          # iOS-specific configuration
├── pubspec.yaml                  # Dependencies
├── .env.example                  # Environment variables template
└── README.md                     # This file
```

## Dependencies

### Core Dependencies
- `flutter_map: ^8.2.2` - Map rendering with OSM tiles
- `latlong2: ^0.9.1` - Latitude/longitude utilities
- `geolocator: ^14.0.2` - GPS location services
- `camera: ^0.11.3` - Camera access and photo capture
- `google_sign_in: ^7.2.0` - Google authentication
- `http: ^1.5.0` - HTTP client for API calls
- `flutter_dotenv: ^6.0.0` - Environment variable management
- `provider: ^6.1.5+1` - State management

### Dev Dependencies
- `flutter_test` - Testing framework
- `flutter_lints: ^3.0.1` - Linting rules

## Troubleshooting

### Camera Issues
- Ensure camera permissions are granted in device settings
- For iOS simulator: Camera is not available, use physical device
- For Android: Check `AndroidManifest.xml` has camera permission

### GPS Issues
- Enable location services in device settings
- For iOS: Check Info.plist has location usage descriptions
- For Android: Ensure location permissions are granted

### Google Sign-In Issues
- Verify Firebase configuration files are correctly placed
- Check SHA-1 fingerprint is added to Firebase project (Android)
- Ensure OAuth consent screen is configured in Google Cloud Console

### Build Issues
- Run `flutter clean && flutter pub get`
- Check Flutter SDK version: `flutter --version`
- Update dependencies: `flutter pub upgrade`

## License

This project is licensed under the MIT License.

## Support

For issues, questions, or contributions, please open an issue on the GitHub repository.
