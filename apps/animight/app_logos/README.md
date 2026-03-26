# App Logos — Store Assets

This folder contains the app icon used for App Store Connect and Google Play listing.

## Files

| File | Size | Use |
|------|------|-----|
| `icon_1024x1024.png` | 1024×1024 | App Store Connect (required) |

## Store Requirements

### iOS — App Store Connect
- **App Icon**: 1024×1024 PNG, no alpha/transparency, no rounded corners (Apple adds them)
- Upload at: App Store Connect → My Apps → [App] → App Store → App Information → App Icon
- Can also be uploaded automatically via Fastlane `deliver`:
  ```bash
  # From apps/animight/fastlane/
  bundle exec fastlane deliver --app_icon ../app_logos/icon_1024x1024.png
  ```

### Android — Google Play
- **App Icon**: 512×512 PNG, up to 1 MB
- **Feature Graphic**: 1024×500 PNG (banner shown in Play Store listing)
- Upload at: Play Console → Listing → Graphics → App icon
- Can be uploaded automatically via Fastlane `supply`:
  ```bash
  # Create metadata/android/en-US/images/icon.png (512×512)
  # Then: cd apps/animight/android && bundle exec fastlane run upload_to_play_store ...
  ```

## ⚠️ Note
The `icon_1024x1024.png` here is a copy of the source app icon.
If you update the icon, regenerate with:
```bash
cd apps/animight && dart run flutter_launcher_icons
# Then re-copy:
cp assets/appiconnew.png app_logos/icon_1024x1024.png
```
