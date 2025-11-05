# App Icon Setup

The app icon should be a 1024x1024 PNG image of the trash bag with map icon.

## To set up the icon:

1. Save the trash bag SVG image as a PNG file at 1024x1024 pixels
2. Name it `app_icon.png`
3. Place it in this directory (`flutter/assets/icon/`)
4. Run: `flutter pub get`
5. Run: `flutter pub run flutter_launcher_icons`

This will automatically generate all required icon sizes for both iOS and Android.

## Using online converter:
You can convert the SVG to PNG at: https://cloudconvert.com/svg-to-png
- Set output size to 1024x1024
- Download and save as `app_icon.png` in this folder

## Manual steps if you already have app_icon.png:
```bash
cd /Users/manu/Dev_stuff/trashmapr/flutter
flutter pub get
flutter pub run flutter_launcher_icons
```

This will generate:
- Android icons in: android/app/src/main/res/mipmap-*
- iOS icons in: ios/Runner/Assets.xcassets/AppIcon.appiconset/
