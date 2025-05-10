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
        applicationId = "com.example.smart_subscription_tracker"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // IMPORTANT: The keystore file specified below MUST exist.
            // 1. VERIFY THE FILE 'smart-sub-release-key.keystore' IS LOCATED IN THE 'android/app/' DIRECTORY.
            // 2. IF IT'S MISSING, YOU NEED TO GENERATE IT.
            //    - In Android Studio: Build > Generate Signed Bundle / APK... > Create new...
            //    - Or use the 'keytool' command-line utility.
            // 3. IF IT EXISTS BUT IN A DIFFERENT LOCATION (e.g., 'android/' folder),
            //    UPDATE THE PATH in storeFile. For example, if in 'android/': file("../smart-sub-release-key.keystore")
            // 4. Ensure the storePassword, keyAlias, and keyPassword match EXACTLY
            //    what was used when creating/defining the keystore.
            

            val storeFilePath = project.findProperty("MYAPP_RELEASE_STORE_FILE") as String? ?: "smart-sub-release-key.keystore"
            val resolvedStoreFile = file(storeFilePath)

            if (resolvedStoreFile.exists()) {
                storeFile = resolvedStoreFile
                storePassword = project.findProperty("MYAPP_RELEASE_STORE_PASSWORD") as String? ?: "O2tr341989*" // Example, replace with property
                keyAlias = project.findProperty("MYAPP_RELEASE_KEY_ALIAS") as String? ?: "alias" // Example, replace with property
                keyPassword = project.findProperty("MYAPP_RELEASE_KEY_PASSWORD") as String? ?: "O2tr341989*" // Example, replace with property
            } else {
                println("Warning: Keystore file not found at $storeFilePath. Release build may fail signing.")
                // Optionally, you can make the build fail here if the keystore is mandatory for your setup
                // throw new InvalidUserDataException("Keystore file '$storeFilePath' not found.")
                // Or, allow it to proceed and fail at validateSigningRelease if not configured for debug signing
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
