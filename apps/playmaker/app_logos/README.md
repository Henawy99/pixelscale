# App Logos — Store Assets

This folder contains the app icon used for App Store Connect and Google Play listing.

## Files

| File | Size | Use |
|------|------|-----|
| `icon_1024x1024.png` | 1024×1024 | App Store Connect + source for Play Store |

## Store Requirements

### iOS — App Store Connect
- **App Icon**: 1024×1024 PNG, no alpha/transparency, no rounded corners
- Upload at: App Store Connect → Playmaker app → App Information → App Icon
- Two bundle IDs:
  - User App: `com.playmaker.start`
  - Management App: `com.playmaker.admin`

### Android — Google Play
- **App Icon**: 512×512 PNG
- **Feature Graphic**: 1024×500 PNG

## ⚠️ Note
If you update the icon:
```bash
cd apps/playmaker && dart run flutter_launcher_icons
cp assets/images/playmakerappicon.png app_logos/icon_1024x1024.png
```
