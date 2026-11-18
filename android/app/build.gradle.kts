import java.io.File
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.brijesh.vision"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.brijesh.vision"
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

flutter {
    source = "../.."
}

// Automatically archive a timestamped VISION APK copy whenever `flutter build apk`
// runs directly, while preserving Flutter's original `app-<mode>.apk` output.
tasks.matching {
    it.name == "assembleDebug" || it.name == "assembleProfile" || it.name == "assembleRelease"
}.configureEach {
    val mode = when (name) {
        "assembleDebug" -> "debug"
        "assembleProfile" -> "profile"
        "assembleRelease" -> "release"
        else -> return@configureEach
    }
    val appBuildDirProvider = project.layout.buildDirectory
    val projectRootDir = project.rootProject.layout.projectDirectory.dir("..")
    val skipArchiveEnv = project.providers.environmentVariable("VISION_SKIP_GRADLE_ARCHIVE")
    val configuredAppId = "com.brijesh.vision"

    doLast {
        if (skipArchiveEnv.orNull == "1") {
            return@doLast
        }

        val appBuildDir = appBuildDirProvider.get().asFile
        val flutterApkDir = appBuildDir.resolve("outputs/flutter-apk")
        val primaryApk = flutterApkDir.resolve("app-$mode.apk")
        val fallbackApk = appBuildDir.resolve("outputs/apk/$mode/app-$mode.apk")
        val sourceApk = if (primaryApk.exists()) primaryApk else fallbackApk

        if (!sourceApk.exists()) {
            logger.warn("[VISION] Skipping timestamped APK archive: APK not found for mode '$mode'.")
            return@doLast
        }

        val istZone = ZoneId.of("Asia/Kolkata")
        val compactFmt = DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss")
        val dateFmt = DateTimeFormatter.ofPattern("yyyy-MM-dd")
        val timeFmt = DateTimeFormatter.ofPattern("HH:mm:ss")

        val distModeDir = projectRootDir.dir("dist/apk/$mode").asFile.apply { mkdirs() }
        flutterApkDir.mkdirs()

        var nowIst: ZonedDateTime
        var timestamp: String
        var baseName: String
        var distApk: File
        var distMeta: File
        var flutterNamedApk: File

        while (true) {
            nowIst = ZonedDateTime.now(istZone)
            timestamp = nowIst.format(compactFmt)
            baseName = "vision-$mode-$timestamp"
            distApk = distModeDir.resolve("$baseName.apk")
            distMeta = distModeDir.resolve("$baseName.json")
            flutterNamedApk = flutterApkDir.resolve("$baseName.apk")
            if (!distApk.exists() && !distMeta.exists() && !flutterNamedApk.exists()) {
                break
            }
            Thread.sleep(1000)
        }

        sourceApk.copyTo(distApk, overwrite = false)
        sourceApk.copyTo(flutterNamedApk, overwrite = false)

        val pubspecFile = projectRootDir.file("pubspec.yaml").asFile
        var versionName = "1.0.0"
        var versionCode = 1
        if (pubspecFile.exists()) {
            val versionRegex = Regex("""^\s*version\s*:\s*([^\s+#]+)(?:\+(\d+))?""")
            for (line in pubspecFile.readLines(Charsets.UTF_8)) {
                val match = versionRegex.find(line)
                if (match != null) {
                    versionName = match.groupValues[1]
                    if (match.groupValues[2].isNotEmpty()) {
                        versionCode = match.groupValues[2].toIntOrNull() ?: 1
                    }
                    break
                }
            }
        }

        val sizeBytes = distApk.length()
        val sizeMb = String.format(Locale.US, "%.2f", sizeBytes / (1024.0 * 1024.0))
        val metadataJson = """
            {
              "applicationName": "VISION",
              "packageId": "$configuredAppId",
              "buildMode": "$mode",
              "buildDate": "${nowIst.format(dateFmt)}",
              "buildTime": "${nowIst.format(timeFmt)}",
              "buildTimestamp": "$timestamp",
              "timezone": "Asia/Kolkata",
              "apkFilename": "$baseName.apk",
              "apkSizeBytes": $sizeBytes,
              "apkSizeFormatted": "$sizeMb MB ($sizeBytes bytes)",
              "versionName": "$versionName",
              "versionCode": $versionCode
            }
        """.trimIndent() + "\n"
        distMeta.writeText(metadataJson, Charsets.UTF_8)

        println("[VISION] Archived APK    : ${distApk.absolutePath}")
        println("[VISION] Flutter APK Copy: ${flutterNamedApk.absolutePath}")
        println("[VISION] Metadata JSON   : ${distMeta.absolutePath}")
    }
}
