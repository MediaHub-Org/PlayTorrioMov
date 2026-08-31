import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material. Never committed: CI writes android/key.properties
// and the keystore beside it from repository secrets, and android/.gitignore
// covers key.properties, *.keystore and *.jks. When it is absent -- a local
// checkout, or a pull request from a fork, which cannot read secrets -- the
// release build falls back to the debug key below so it still builds.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseSigning = keystorePropertiesFile.exists()

android {
    namespace = "com.example.playtorrio"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Deliberately NOT the upstream `com.example.playtorrio`. Sharing that
        // id made this fork the same app as ayman708-UX/PlayTorrioV3 to Android,
        // so it could not be installed alongside the original and could not be
        // installed over it either (different signing key). Changing it costs
        // nothing here because this fork has never published an installable
        // release, and it is the identity of an install forever after -- so it
        // must not change again once anyone has this build.
        //
        // `namespace` above is only the generated R/BuildConfig package and is
        // intentionally left alone; it has no bearing on install identity.
        applicationId = "com.mediahub.playtorriomod"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // The debug key is regenerated per machine, so every CI run used to
            // produce a differently-signed APK that Android refused to install
            // over the previous one. With key.properties present the build is
            // signed with a stable release key instead, and updates apply.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
