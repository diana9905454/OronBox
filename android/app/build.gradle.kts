import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "org.zxor.oronbox"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "org.zxor.oronbox"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties.getProperty("keyAlias")
            keyPassword = keyProperties.getProperty("keyPassword")
            storeFile = keyProperties.getProperty("storeFile")?.let { path -> file(path) }
            storePassword = keyProperties.getProperty("storePassword")
        }
    }

    // Store native libraries uncompressed and page-aligned so the system maps
    // them straight from the APK instead of extracting a second copy. The APK
    // download grows, but installed size drops by roughly the same amount.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            // Release builds use the upload key from android/key.properties
            // when present; local builds without it fall back to debug keys.
            signingConfig = if (keyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
    implementation(project(":xms-wearable-lib"))
}

val normalizeWasmRunReleaseNativeAssets = tasks.register("normalizeWasmRunReleaseNativeAssets") {
    val nativeAssetsDir = layout.buildDirectory
        .dir("intermediates/flutter/release/native_assets/jniLibs")
        .get()
        .asFile

    dependsOn("compileFlutterBuildRelease")

    doLast {
        nativeAssetsDir
            .walkTopDown()
            .filter { it.isFile && it.name == "libwasm_run_dart.a" }
            .forEach { archiveNamedLibrary ->
                val dynamicLibrary = archiveNamedLibrary.resolveSibling("libwasm_run_dart.so")
                if (dynamicLibrary.exists()) {
                    dynamicLibrary.delete()
                }
                check(archiveNamedLibrary.renameTo(dynamicLibrary)) {
                    "Unable to normalize ${archiveNamedLibrary.absolutePath}"
                }
            }
    }
}

tasks.configureEach {
    if (name == "copyJniLibsflutterBuildRelease") {
        dependsOn(normalizeWasmRunReleaseNativeAssets)
    }
}
