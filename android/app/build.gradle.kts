import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningProperties = Properties()
val releaseSigningPropertiesFile = rootProject.file("key.properties")
if (releaseSigningPropertiesFile.isFile) {
    releaseSigningPropertiesFile.inputStream().use(releaseSigningProperties::load)
}

val releaseSigningEnvironmentKeys = mapOf(
    "storeFile" to "NWU_RELEASE_STORE_FILE",
    "storePassword" to "NWU_RELEASE_STORE_PASSWORD",
    "keyAlias" to "NWU_RELEASE_KEY_ALIAS",
    "keyPassword" to "NWU_RELEASE_KEY_PASSWORD",
)

fun releaseSigningValue(name: String): String? =
    releaseSigningProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: System.getenv(releaseSigningEnvironmentKeys.getValue(name))
            ?.takeIf { it.isNotBlank() }

val releaseStoreFilePath = releaseSigningValue("storeFile")
val releaseStoreFile = releaseStoreFilePath?.let(rootProject::file)
val releaseStorePassword = releaseSigningValue("storePassword")
val releaseKeyAlias = releaseSigningValue("keyAlias")
val releaseKeyPassword = releaseSigningValue("keyPassword")
val hasReleaseSigning = releaseStoreFile?.isFile == true &&
    releaseStorePassword != null &&
    releaseKeyAlias != null &&
    releaseKeyPassword != null

android {
    namespace = "io.github.aceykn.nwuschedule"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.aceykn.nwuschedule"
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
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

tasks.configureEach {
    if (name == "assembleRelease" ||
        name == "bundleRelease" ||
        name == "validateSigningRelease") {
        doFirst {
            check(hasReleaseSigning) {
                "Release signing is not configured. Provide android/key.properties " +
                    "or NWU_RELEASE_* environment variables."
            }
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
