# Quick Start Guide

This guide will help you get the TrashMapr Flutter app running quickly.

## Prerequisites Check

```bash
# Check Flutter installation
flutter doctor

# Should show:
# ✓ Flutter (Channel stable, 3.x.x)
# ✓ Android toolchain
# ✓ Xcode (for iOS)
# ✓ Chrome (for web, optional)
```

## 1. Install Dependencies

```bash
cd flutter
flutter pub get
```

## 2. Configure Backend URL

Edit the `.env` file:

```bash
# For local development
API_URL=http://localhost:8000

# For production (update with your Cloud Run URL)
API_URL=https://your-backend-url.run.app
```

## 3. Set Up Google Sign-In

### Quick Setup (Testing)

For testing purposes, you can skip Firebase setup initially. The app will work in "guest mode" for viewing the map.

### Full Setup (Required for Upload)

1. **Create Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Create a new project
   - Add Android and/or iOS app

2. **Android Setup**
   ```bash
   # Download google-services.json from Firebase
   # Place it in: android/app/google-services.json
   ```

3. **iOS Setup**
   ```bash
   # Download GoogleService-Info.plist from Firebase
   # Place it in: ios/Runner/GoogleService-Info.plist
   ```

## 4. Run the App

### Android

```bash
# List available devices
flutter devices

# Run on connected device/emulator
flutter run
```

### iOS

```bash
# Install iOS dependencies
cd ios && pod install && cd ..

# Run on connected device/simulator
flutter run
```

## 5. Testing Without Backend

If you don't have the backend running yet:

1. The app will start and show the map
2. You can view the UI and navigation
3. Map will show an error when trying to load points (expected)
4. Sign-in will work if Firebase is configured

## 6. Common Commands

```bash
# Clean build
flutter clean && flutter pub get

# Run with verbose logging
flutter run -v

# Build release APK (Android)
flutter build apk --release

# Build for iOS
flutter build ios --release

# Run tests (when available)
flutter test

# Format code
flutter format .

# Analyze code
flutter analyze
```

## 7. First Launch Checklist

When you first launch the app:

- [ ] App opens without crashes
- [ ] Bottom navigation shows 3 tabs (Map, Capture, My Uploads)
- [ ] Map screen displays (may show error if backend not available)
- [ ] Capture screen shows camera (or requests permission)
- [ ] Sign-in button appears in app bar
- [ ] Google Sign-In works (if Firebase configured)

## 8. Troubleshooting

### "Unable to load asset: .env"
- This is a warning, not an error. The app will use default values.

### Camera not working
```bash
# iOS: Ensure Info.plist has camera description
# Android: Check AndroidManifest.xml has camera permission
```

### GPS not working
```bash
# Enable location services in device/emulator settings
# Grant location permissions when prompted
```

### Build errors
```bash
# Try cleaning and rebuilding
flutter clean
flutter pub get
flutter run
```

### Google Sign-In not working
- Verify Firebase configuration files are in place
- Check SHA-1 fingerprint is added to Firebase (Android)
- Ensure OAuth consent screen is configured

## 9. Development Tips

### Hot Reload
```bash
# Press 'r' in terminal for hot reload
# Press 'R' for hot restart
# Press 'q' to quit
```

### Debug Mode Features
- Material Design debug banner (shows "DEBUG" ribbon)
- Performance overlay: Press 'p' in terminal
- Show widget boundaries: Press 'w' in terminal

### Recommended VS Code Extensions
- Flutter
- Dart
- Flutter Widget Snippets
- Pubspec Assist

## 10. Next Steps

1. **Backend Connection**: Set up the FastAPI backend
2. **Firebase Auth**: Complete Google Sign-In setup
3. **Test Upload**: Take a photo and upload it
4. **View on Map**: See your uploaded point on the map
5. **Customize**: Modify colors, icons, or features as needed

## Need Help?

- Check the main [README.md](README.md) for detailed documentation
- Review Flutter docs: https://docs.flutter.dev
- Check Firebase docs: https://firebase.google.com/docs

Happy mapping! 🗺️📸
