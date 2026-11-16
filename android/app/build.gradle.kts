import java.util.Properties
import java.io.FileInputStream

// Llave de firma propia (android/key.properties, no se sube a git). Todas
// las versiones deben firmarse con la misma para poder actualizarse encima.
val llave = Properties().apply {
    val archivo = rootProject.file("key.properties")
    if (archivo.exists()) load(FileInputStream(archivo))
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.visitasdefe.visitas_de_fe"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.visitasdefe.visitas_de_fe"
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
        create("release") {
            if (llave.isNotEmpty()) {
                keyAlias = llave["keyAlias"] as String
                keyPassword = llave["keyPassword"] as String
                storeFile = file(llave["storeFile"] as String)
                storePassword = llave["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (llave.isNotEmpty()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
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
    // FileProvider, para pasarle el APK de la actualización al instalador.
    implementation("androidx.core:core-ktx:1.13.1")
}
