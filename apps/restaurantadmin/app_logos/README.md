# App Logos — Store Assets

This folder contains the app icon used for App Store Connect and Google Play listing.

## Files

| File | Size | Use |
|------|------|-----|
| `icon_1024x1024.png` | 1024×1024 | App Store Connect + source for Play Store |

## Store Requirements

### iOS — App Store Connect
- **App Icon**: 1024×1024 PNG, no alpha, no rounded corners
- Bundle ID: `com.mycoolrestaurant.adminapp`

### Android — Google Play
- Package: `com.example.restaurantadmin` (update if changed)
- **App Icon**: 512×512 PNG

## ⚠️ Note
If you update the logo:
```bash
cd apps/restaurantadmin && dart run flutter_launcher_icons
cp assets/restaurantlogos/devilssmashburger.png app_logos/icon_1024x1024.png
```
