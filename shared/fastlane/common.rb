# ============================================
# PixelScale - Shared Fastlane Helpers
# Import in app-level Fastfiles:
#   import '../../shared/fastlane/common.rb'
# ============================================

def increment_version_and_build(pubspec_path)
  content = File.read(pubspec_path)
  version_match = content.match(/version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)/)

  if version_match
    major = version_match[1].to_i
    minor = version_match[2].to_i
    patch = version_match[3].to_i + 1
    build = version_match[4].to_i + 1

    old_version = "#{version_match[1]}.#{version_match[2]}.#{version_match[3]}+#{version_match[4]}"
    new_version = "#{major}.#{minor}.#{patch}+#{build}"

    new_content = content.sub(/version:\s*[\d.+]+/, "version: #{new_version}")
    File.write(pubspec_path, new_content)

    UI.success("Version: #{old_version} -> #{new_version}")
    return new_version
  else
    UI.error("Could not find version in #{pubspec_path}")
    return nil
  end
end

def notify_complete(app_name, platform, version)
  UI.success("=" * 50)
  UI.success("  #{app_name} #{platform} build complete!")
  UI.success("  Version: #{version}")
  UI.success("=" * 50)
end
