plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.inmobiliariaapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // En KTS se usa isCoreLibraryDesugaringEnabled
        isCoreLibraryDesugaringEnabled = true 
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // Ignora el warning de deprecated por ahora, esto funciona:
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.inmobiliariaapp"
        
        // Es mejor definir números fijos si flutter.minSdkVersion da problemas
        minSdk = flutter.minSdkVersion 
        // En KTS se accede como flutter.targetSdkVersion (con "Version" al final)
        targetSdk = flutter.targetSdkVersion 
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
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

// ESTA SECCIÓN DEBE IR FUERA DEL BLOQUE android { }
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
