plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.fiveyear"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    assetPacks += ":gemma3_1b_it"

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.fiveyear"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true 
            isShrinkResources = true 
            
       proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            project.file("proguard-rules.pro") // Use project.file to be explicit
        )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ... other dependencies like kotlin-stdlib, flutter stuff ...
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Google Play Asset Delivery
    implementation("com.google.android.play:asset-delivery:2.2.2")
    
    // Kotlin Extensions (KTX) - optional but recommended for cleaner Kotlin code
    implementation("com.google.android.play:asset-delivery-ktx:2.2.2")
}