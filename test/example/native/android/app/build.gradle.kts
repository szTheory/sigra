import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "dev.sigra.proof"
    compileSdk = 36
    buildToolsVersion = "35.0.0"

    defaultConfig {
        applicationId = "dev.sigra.proof"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        debug {
            val proofHost = providers.gradleProperty("sigraNativeProofHostBaseUrl")
                .orElse("http://10.0.2.2:4102")
            buildConfigField("String", "PROOF_HOST_BASE_URL", "\"${proofHost.get()}\"")
            buildConfigField("String", "LOCKED_BROWSER_MODE", "\"custom_tab_fallback\"")
        }
        release {
            isMinifyEnabled = false
            buildConfigField("String", "PROOF_HOST_BASE_URL", "\"https://native-proof.invalid\"")
            buildConfigField("String", "LOCKED_BROWSER_MODE", "\"custom_tab_fallback\"")
        }
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    implementation(libs.androidx.browser)
    implementation(libs.androidx.activity)
    testImplementation(libs.junit4)
    androidTestImplementation(libs.junit4)
    androidTestImplementation(libs.androidx.test.core)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.espresso.core)
    androidTestImplementation(libs.androidx.test.uiautomator)
}
