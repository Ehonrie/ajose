plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.pavegroup.ajose.ajose"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (v10+) for its scheduled
        // notification support, even though this phase doesn't schedule any.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pavegroup.ajose.ajose"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Mobile Wallet Adapter requires API 26+ (Android 8.0) at minimum.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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

dependencies {
    // Required so LaunchTheme/NormalTheme can extend Theme.AppCompat.* —
    // needed by local_auth's biometric prompt (see styles.xml).
    implementation("androidx.appcompat:appcompat:1.7.0")
    // Pairs with isCoreLibraryDesugaringEnabled above (flutter_local_notifications).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Mobile Wallet Adapter 2.0, integrated directly here (MethodChannel
    // bridge in MainActivity) rather than via the solana_mobile_client
    // Flutter package: that package pins the old MWA 1.x native clientlib
    // (1.1.0), which current MWA-2.0-only wallets (Solflare) — and,
    // observed later, current Phantom builds too — silently ignore rather
    // than showing a connect screen.
    //
    // mobile-wallet-adapter-clientlib-ktx's own published 2.0.8 release (the
    // latest on Maven Central) has an upstream packaging bug: it and its
    // own `clientlib` dependency both declare the identical Android
    // namespace, which AGP 8+ rejects outright (see
    // solana-mobile/mobile-wallet-adapter#1530/#1531 — fixed on their main
    // branch, but never released, and JitPack fails to build this repo at
    // every version anyone has tried). Patched locally instead: downloaded
    // the published AAR and renamed its embedded namespace from
    // `com.solana.mobilewalletadapter.clientlib` to
    // `com.solana.mobilewalletadapter.clientlib.ktx` — the exact string the
    // unreleased upstream fix uses — nothing else in the AAR was touched.
    implementation(files("libs/mobile-wallet-adapter-clientlib-ktx-2.0.8-patched.aar"))
    // clientlib-ktx's own dependency, unpatched (its namespace is now
    // unique since the ktx copy above was renamed).
    implementation("com.solanamobile:mobile-wallet-adapter-clientlib:2.0.8")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}

flutter {
    source = "../.."
}
