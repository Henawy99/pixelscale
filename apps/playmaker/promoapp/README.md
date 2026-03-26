# 🎬 Playmaker Promo App

A display app designed for big screens at sports clubs that continuously streams match recordings with Playmaker ads.

## Features

- **Continuous Video Playback**: Automatically plays the latest match recordings in a loop
- **Playmaker Ads**: Shows branded ads every 30 seconds (15 sec duration)
- **Auto-Refresh**: Updates the video playlist every 5 minutes to include new recordings
- **Fullscreen Mode**: Runs in landscape fullscreen with screen always on
- **Error Recovery**: Automatically retries on connection errors

## Setup

### 1. Install Dependencies
```bash
cd promoapp
flutter pub get
```

### 2. Run on Device
```bash
flutter run -d android
```
Or use the script from the root directory:
```bash
./run_promo_app.sh
```

### 3. Build Release APK
```bash
./build_android_promo_release.sh
```

## Configuration

### Target Specific Field
Edit `lib/services/recording_service.dart`:
```dart
RecordingService({this.targetFieldId = 'YOUR_FIELD_ID'});
```

### Adjust Ad Timing
Edit `lib/screens/promo_screen.dart`:
```dart
static const int adIntervalSeconds = 30;  // Show ad every X seconds
static const int adDurationSeconds = 15;  // Ad displays for X seconds
static const int refreshIntervalMinutes = 5;  // Refresh playlist every X minutes
```

## Installing on Android TV Box

1. Build the release APK
2. Enable ADB debugging on your Android TV box
3. Connect via ADB: `adb connect <TV_IP_ADDRESS>`
4. Install: `adb install playmaker-promo.apk`
5. Launch the app from the TV's app launcher

## Video Sources

The app fetches videos from:
1. `camera_recording_schedules` table (primary) - completed recordings with `final_video_url`
2. `bookings` table (fallback) - recordings with `recording_url`

Both sources are filtered to only show completed recordings with valid video URLs.
