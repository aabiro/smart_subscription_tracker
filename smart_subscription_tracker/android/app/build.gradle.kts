// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
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
        applicationId = "com.example.smart_subscription_tracker"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Read signing configuration from gradle.properties
            // Ensure MYAPP_RELEASE_STORE_FILE, MYAPP_RELEASE_STORE_PASSWORD,
            // MYAPP_RELEASE_KEY_ALIAS, and MYAPP_RELEASE_KEY_PASSWORD are defined
            // in your android/gradle.properties file.

            val storeFileProperty = project.findProperty("MYAPP_RELEASE_STORE_FILE") as String?
            val storePasswordProperty = project.findProperty("MYAPP_RELEASE_STORE_PASSWORD") as String?
            val keyAliasProperty = project.findProperty("MYAPP_RELEASE_KEY_ALIAS") as String?
            val keyPasswordProperty = project.findProperty("MYAPP_RELEASE_KEY_PASSWORD") as String?

            if (storeFileProperty != null && storePasswordProperty != null && keyAliasProperty != null && keyPasswordProperty != null) {
                val resolvedStoreFile = file(storeFileProperty) // Resolves relative to android/app/
                if (resolvedStoreFile.exists()) {
                    storeFile = resolvedStoreFile
                    storePassword = storePasswordProperty
                    keyAlias = keyAliasProperty
                    keyPassword = keyPasswordProperty
                    println("Release signing config loaded from gradle.properties using keystore: $storeFileProperty")
                } else {
                    println("Warning: Keystore file '$storeFileProperty' specified in gradle.properties not found at ${resolvedStoreFile.absolutePath}. Release build will likely fail signing.")
                    // You might want to throw an error here if the file is mandatory for release builds
                    // throw new org.gradle.api.InvalidUserDataException("Keystore file '$storeFileProperty' not found at ${resolvedStoreFile.absolutePath}")
                }
            } else {
                println("Warning: Release signing information not found in gradle.properties. Release build will not be signed properly.")
                // This configuration will likely cause the :validateSigningRelease task to fail
                // or result in an unsigned/debug-signed release artifact if not handled.
                // For a real release, these properties MUST be set.
            }
        }
    }

    buildTypes {
        getByName("release") { 
            signingConfig = signingConfigs.getByName("release") 
            isMinifyEnabled = true    
            isShrinkResources = true  
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro" // Ensure this file exists in android/app/
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Add your app-specific Android dependencies here
}
