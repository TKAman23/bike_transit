import groovy.json.JsonSlurper

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// API keys live in the git-ignored config/keys.json (see config/keys.example.json).
val apiKeys: Map<*, *> = rootProject.file("../config/keys.json").let { file ->
    if (file.exists()) JsonSlurper().parse(file) as Map<*, *> else emptyMap<String, String>()
}

// google-services.json is generated from the tracked template so the key stays out of git.
rootProject.file("app/google-services.template.json").let { template ->
    val key = apiKeys["MAPS_API_KEY"] as String?
    if (template.exists() && !key.isNullOrEmpty()) {
        val out = rootProject.file("app/google-services.json")
        val text = template.readText().replace("__MAPS_API_KEY__", key)
        if (!out.exists() || out.readText() != text) out.writeText(text)
    }
}

android {
    namespace = "com.example.bike_transit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.bike_transit"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = (apiKeys["MAPS_API_KEY"] as String?) ?: ""
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
