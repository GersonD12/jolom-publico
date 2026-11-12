import groovy.json.JsonSlurper
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasProductionSigning = keystorePropertiesFile.exists()

if (hasProductionSigning) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}

fun Properties.required(name: String): String =
    getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException("Falta '$name' en android/key.properties")

fun mapsApiKey(environment: String): String {
    val propertiesFile = rootProject.file("maps-$environment.properties")
    if (!propertiesFile.isFile) return ""
    val properties = Properties()
    FileInputStream(propertiesFile).use(properties::load)
    return properties.getProperty("GOOGLE_MAPS_API_KEY")?.trim().orEmpty()
}

fun firebaseAuthHost(environment: String): String {
    val file = project.file("src/$environment/google-services.json")
    if (!file.isFile) return "firebase.example"
    val config = JsonSlurper().parse(file) as Map<*, *>
    val projectInfo = config["project_info"] as Map<*, *>
    return "${projectInfo["project_id"]}.firebaseapp.com"
}

android {
    namespace = "com.example.jolom"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Requerido por flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.jolom"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasProductionSigning) {
            create("production") {
                keyAlias = keystoreProperties.required("keyAlias")
                keyPassword = keystoreProperties.required("keyPassword")
                storeFile = rootProject.file(keystoreProperties.required("storeFile"))
                storePassword = keystoreProperties.required("storePassword")
            }
        }
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationId = "com.example.jolom"
            resValue("string", "app_name", "Jolom Dev")
            signingConfig = signingConfigs.getByName("debug")
            manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = mapsApiKey("dev")
            manifestPlaceholders["FIREBASE_AUTH_HOST"] = firebaseAuthHost("dev")
        }
        create("prod") {
            dimension = "environment"
            applicationId = "com.example.jolom.prod"
            resValue("string", "app_name", "Jolom")
            if (hasProductionSigning) {
                signingConfig = signingConfigs.getByName("production")
            }
            manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = mapsApiKey("prod")
            manifestPlaceholders["FIREBASE_AUTH_HOST"] = firebaseAuthHost("prod")
            manifestPlaceholders["JOLOM_SITE_HOST"] = providers.gradleProperty("jolomSiteHost")
                .orElse("jolom.example").get()
        }
    }

    buildTypes {
        release {
            // La firma la define cada flavor; prod nunca hereda la llave debug.
        }
    }
}

// Falla antes de compilar si alguien intenta publicar sin credenciales reales.
tasks.matching { it.name == "preProdReleaseBuild" }.configureEach {
    doFirst {
        if (!hasProductionSigning) {
            throw GradleException(
                "No existe android/key.properties. Copia key.properties.example y configura la firma de producción.",
            )
        }

        val configuredStore = rootProject.file(keystoreProperties.required("storeFile"))
        if (!configuredStore.isFile) {
            throw GradleException("No existe el keystore configurado: ${configuredStore.path}")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
