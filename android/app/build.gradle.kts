import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// --- Release signing -------------------------------------------------------
//
// Material comes from one of two places, never from this file:
//
//   1. `android/key.properties` (a developer's machine), or
//   2. environment variables (CI):
//        ANDROID_KEYSTORE_BASE64  -> decoded to a keystore by the workflow
//        ANDROID_KEYSTORE_PATH    -> where the workflow wrote it
//        ANDROID_KEY_ALIAS
//        ANDROID_KEY_PASSWORD
//        ANDROID_STORE_PASSWORD
//
// No keystore and no password is ever committed. `key.properties` and
// `*.jks`/`*.keystore` are gitignored.
//
// WHY THIS FAILS LOUDLY
// ---------------------
// A release build with no signing material used to fall back to the DEBUG key
// silently. A debug-signed APK installs and runs, so the fallback is invisible
// until the Play Console rejects the upload -- or worse, until an "internal
// testing" build goes out signed with a key that is on every developer's
// machine and in every CI image.
//
// So: a release build with nothing to sign with now stops with an explanation.
// `-PallowDebugSigning=true` (or ALLOW_DEBUG_SIGNING=true) restores the old
// behaviour for `flutter run --release` on a dev machine, and says so in the
// build log every time.
//
// Debug builds are untouched -- CI builds a debug APK on every push and must
// keep working with no secrets at all.
fun signingEnv(name: String): String? =
    System.getenv(name)?.takeIf { it.isNotBlank() }

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(keystorePropertiesFile.inputStream())
    }
}

fun signingValue(propertyKey: String, envKey: String): String? =
    (keystoreProperties[propertyKey] as String?)?.takeIf { it.isNotBlank() }
        ?: signingEnv(envKey)

val releaseStoreFilePath = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
val releaseKeyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
val releaseStorePassword = signingValue("storePassword", "ANDROID_STORE_PASSWORD")

val hasReleaseSigning = releaseStoreFilePath != null &&
    releaseKeyAlias != null &&
    releaseKeyPassword != null &&
    releaseStorePassword != null &&
    file(releaseStoreFilePath).exists()

val allowDebugSigning =
    (project.findProperty("allowDebugSigning") as String?)?.toBoolean() == true ||
        System.getenv("ALLOW_DEBUG_SIGNING")?.toBoolean() == true

// Only release tasks are gated. `assembleDebug`, `flutter test` and
// `flutter analyze` must never be blocked by a missing keystore.
val buildingRelease = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true) || it.contains("bundle", ignoreCase = true)
}

if (buildingRelease && !hasReleaseSigning && !allowDebugSigning) {
    throw GradleException(
        """
        Release build refused: no Android signing material.

        Supply either android/key.properties with storeFile/keyAlias/
        keyPassword/storePassword, or the environment variables
        ANDROID_KEYSTORE_PATH, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD and
        ANDROID_STORE_PASSWORD.

        To build a release APK signed with the DEBUG key on purpose -- never
        for distribution, because that key is not yours alone -- re-run with
        -PallowDebugSigning=true.
        """.trimIndent()
    )
}

if (buildingRelease && !hasReleaseSigning) {
    logger.warn(
        "WARNING: signing this RELEASE build with the DEBUG key " +
            "(allowDebugSigning). It cannot be distributed."
    )
}

android {
    namespace = "com.deeptrics.saaradhigo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    lint {
        abortOnError = false
        checkReleaseBuilds = false
        disable += "Instantiatable"
        disable += "ProtectedPermissions"
        disable += "NewApi"
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Declared only when every value resolved AND the keystore exists on disk.
    //
    // This block used to run whenever key.properties existed and cast its
    // values with `as String`, so a file missing one key died with "null
    // cannot be cast to non-null type kotlin.String" -- taking
    // `flutter build apk --debug` with it, which needs no keystore at all.
    // Nothing reported it, because `flutter test` and `flutter analyze` never
    // read Gradle.
    if (hasReleaseSigning) {
        signingConfigs {
            create("release") {
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeFile = file(releaseStoreFilePath!!)
                storePassword = releaseStorePassword
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.deeptrics.saaradhigo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Supplies ${MAPS_API_KEY} in AndroidManifest.xml. Empty by default:
        // an unsupplied placeholder fails the build, and this app does not use
        // the Maps SDK, so there is nothing to supply. Pass one at build time
        // if that ever changes:  flutter build apk -Pmaps.apiKey=AIza...
        manifestPlaceholders["MAPS_API_KEY"] =
            (project.findProperty("maps.apiKey") as String?) ?: ""
    }

    buildTypes {
        release {
            // The debug fallback is reachable only with -PallowDebugSigning=true;
            // without it the build has already stopped above.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(platform("com.google.firebase:firebase-bom:34.10.0"))
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-analytics")
}
