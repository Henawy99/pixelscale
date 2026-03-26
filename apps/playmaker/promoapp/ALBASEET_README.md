# Al Baseet Sports - Android App

A beautiful promotional Android app for Al Baseet Sports with real-time visitor tracking.

## Features

- **Premium Sports Showcase**: Animated product carousel showcasing Al Baseet's sports gear
- **Real-time Visitor Counter**: Shows total visitors and today's visitors count
- **Beautiful UI**: Yellow/gold brand colors with smooth animations
- **Responsive Design**: Works great on phones, tablets, and Android TV
- **Session Tracking**: Tracks visit duration and screens viewed

## Build Instructions

### Quick Build (Debug APK)

```bash
cd promoapp
flutter run -t lib/main_albaseet.dart
```

### Full Build (Release APK)

```bash
./build_albaseet_android.sh
```

Or manually:

```bash
cd promoapp
flutter build apk --release -t lib/main_albaseet.dart
```

### Output Locations

| Build Type | Location |
|-----------|----------|
| Debug APK | `build/app/outputs/flutter-apk/app-debug.apk` |
| Release APK | `build/app/outputs/flutter-apk/app-release.apk` |
| App Bundle (AAB) | `build/app/outputs/bundle/release/app-release.aab` |

## Database Setup

Before the visitor counter works, run this SQL migration in your Supabase dashboard:

```sql
-- Location: supabase/migrations/create_albaseet_visits_table.sql
```

The migration creates:
- `al_baseet_visits` table for tracking visitors
- Helper functions for getting visitor counts
- Proper RLS policies for anonymous tracking

## App Structure

```
lib/
├── main_albaseet.dart          # Entry point for Al Baseet app
├── screens/
│   └── albaseet_home_screen.dart   # Main showcase screen with visitor counter
└── services/
    └── albaseet_visitor_service.dart   # Visitor tracking service
```

## Visitor Counter Display

The app shows:
- **Total Visitors**: All-time visitor count (top-right badge)
- **Today's Visitors**: Count of visitors today (shown as "+X today")
- **Real-time Updates**: Counter refreshes every 30 seconds

## Customization

### Change Brand Colors

Edit the theme in `lib/main_albaseet.dart`:

```dart
colorScheme: ColorScheme.light(
  primary: const Color(0xFFFFCD3A),  // Al Baseet Yellow
  secondary: const Color(0xFFFFD700),
),
```

### Add More Products

Edit the `_products` list in `lib/screens/albaseet_home_screen.dart`:

```dart
final List<Map<String, String>> _products = [
  {'image': 'assets/images/product.png', 'name': 'Product Name', 'price': 'EGP XXX'},
  // Add more products...
];
```

## App Icon

To generate the Al Baseet app icon:

```bash
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_albaseet.yaml
```

## Quick Commands

| Command | Description |
|---------|-------------|
| `./run_albaseet_app.sh` | Run on connected device (debug) |
| `./build_albaseet_android.sh` | Build debug + release APK |
| `flutter install -t lib/main_albaseet.dart` | Install on device |

## Version History

- **v1.0.0**: Initial release with product showcase and visitor counter
