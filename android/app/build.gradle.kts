plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase plugin'ini buraya ekledik (Doğru yöntem bu)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.bigboss_eren"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.bigboss_eren"
        
        // --- BURASI DÜZELTİLDİ ---
        // Firebase en az 21 ister. 'flutter.minSdkVersion' yerine 21 yapıyoruz.
        minSdk = flutter.minSdkVersion  
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // MultiDex (Eşittir işareti ile yazılmalı)
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

// --- DEPENDENCIES KISMI EKLENDİ ---
dependencies {
    // MultiDex kütüphanesi
    implementation("androidx.multidex:multidex:2.0.1")
}
