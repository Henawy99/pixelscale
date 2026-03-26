plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.appdistribution") // Added for Firebase App Distribution
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.restaurantadmin"
    compileSdk = 36 // Updated for plugin compatibility
    ndkVersion = "27.0.12077973" // Updated NDK version

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.restaurantadmin"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36 // Updated for plugin compatibility
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Temporarily disabling R8 to bypass ML Kit issues.
            // TODO: Re-enable isMinifyEnabled and thoroughly debug ProGuard rules for ML Kit before production release.
            isMinifyEnabled = false
            isShrinkResources = false // Must be false if isMinifyEnabled is false
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro") // Proguard files are not used when isMinifyEnabled is false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.android.material:material:1.12.0") // Ensure a recent version of Material Components
    // Add other app-level dependencies here if needed
}
