plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.game_hub"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
        }
    }

    defaultConfig {
        applicationId = "com.example.game_hub"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // TODO: once exported from Godot 4.4 Editor (Project > Export > Android,
    // "Export as .aar" / library export), place godot-lib.aar under
    // android/app/libs/ and uncomment the line below. Until then,
    // GodotEmbedView.kt / GodotEmbedViewFactory.kt reference
    // org.godotengine.godot.Godot, which will NOT resolve and the Android
    // build will fail to compile — that is expected until this dependency
    // is wired in; see lib/games/football/soccer-course/EXPORT.md.
    // implementation(files("libs/godot-lib.aar"))
}
