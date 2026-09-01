import com.flutter.gradle.tasks.FlutterTask
import java.util.Properties

val releaseKeystoreProperties = Properties()
val releaseKeystorePropertiesFile = rootProject.file("key.properties")
if (releaseKeystorePropertiesFile.exists()) {
    releaseKeystorePropertiesFile.inputStream().use(releaseKeystoreProperties::load)
}
val releaseSigningKeys = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
)
val releaseSigningConfigured = releaseSigningKeys.all {
    !releaseKeystoreProperties.getProperty(it).isNullOrBlank()
} && file(releaseKeystoreProperties.getProperty("storeFile", "")).isFile

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.otamanagement.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationId = "com.otamanagement.app"
            resValue("string", "app_name", "OTA Dev")
        }
        create("prod") {
            dimension = "environment"
            applicationId = "com.otacheshire.app"
            resValue("string", "app_name", "Olympic Taekwondo Academy")
        }
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = file(releaseKeystoreProperties.getProperty("storeFile"))
                storePassword = releaseKeystoreProperties.getProperty("storePassword")
                keyAlias = releaseKeystoreProperties.getProperty("keyAlias")
                keyPassword = releaseKeystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

// A command-line -t value must never be able to cross Firebase environments.
// Each generated Flutter compilation task is pinned to its native flavor.
tasks.withType<FlutterTask>().configureEach {
    targetPath = when {
        name.contains("Dev", ignoreCase = true) -> "lib/main_dev.dart"
        name.contains("Prod", ignoreCase = true) -> "lib/main_prod.dart"
        else -> throw GradleException(
            "Flutter task '$name' is not associated with the dev or prod flavor.",
        )
    }
}

tasks.configureEach {
    if (name.contains("ProdRelease", ignoreCase = true) &&
        !releaseSigningConfigured
    ) {
        doFirst {
            throw GradleException(
                "Production release signing is not configured. Add " +
                    "android/key.properties with storeFile, storePassword, " +
                    "keyAlias, and keyPassword pointing to the external " +
                    "production keystore.",
            )
        }
    }
}
