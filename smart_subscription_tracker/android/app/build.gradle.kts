// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.smart_subscription_tracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.smart_subscription_tracker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Configure your release signing key here
            // IMPORTANT: For security, avoid hardcoding passwords in version control.
            // Consider using gradle.properties (added to .gitignore) or environment variables.
            storeFile = file("smart-sub-release-key.keystore") // Ensure this file is in android/app/ or provide the correct path
            storePassword = "O2tr341989*"
            keyAlias = "alias"
            keyPassword = "O2tr341989*"
        }
    }

    buildTypes {
        getByName("release") { // Use getByName to configure an existing build type
            // Correct Kotlin DSL syntax:
            signingConfig = signingConfigs.getByName("release") // Assign using '=' and get by name
            isMinifyEnabled = true    // Use 'isMinifyEnabled ='
            isShrinkResources = true  // Use 'isShrinkResources ='
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro" // Ensure this file exists in android/app/
            )
        }
        // Example for debug, often inherits defaults or can be customized
        // getByName("debug") {
        //     applicationIdSuffix = ".debug"
        //     isMinifyEnabled = false
        // }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Add your app-specific Android dependencies here
    // implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:$kotlin_version") // Example
}
