import java.io.StringReader
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.reader(Charsets.UTF_8).use { reader ->
        localProperties.load(reader)
    }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode")?.toIntOrNull() ?: flutter.versionCode
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: flutter.versionName

// 正式签名密钥。本地放在 android/key.properties（已 gitignore），
// CI 发版时由 GitHub Secrets 还原出同名文件。
//
// 这里必须是一把**固定**的密钥：Android 不允许换签名覆盖安装。
// 之前 release 直接复用 debug 签名，而 debug keystore 是每台机器随机生成、
// CI runner 更是一次性的，导致 v1.0.5 / v1.0.6 / v1.0.7 三个包三把不同的钥匙，
// 任意两版之间在线更新都会被系统拦下并提示「开发者签名异常」。
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    // 显式跳过 UTF-8 BOM：Windows 上用 PowerShell 写这个文件会带 BOM，
    // 于是首个键名变成 "﻿storeFile"，取不到值，构建就会不声不响地
    // 退回 debug 签名出一个装不上的包。宁可炸，也不要静默降级。
    val text = keystorePropertiesFile.readText(Charsets.UTF_8).removePrefix("﻿")
    keystoreProperties.load(StringReader(text))
}

// 文件不存在 = 本地开发，退回 debug 签名；
// 文件存在但内容残缺 = 配置写错了，直接让构建失败。
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    val missing = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .filter { keystoreProperties.getProperty(it).isNullOrBlank() }
    require(missing.isEmpty()) {
        "android/key.properties 缺少字段 $missing —— 签名配置不完整会导致出包退回 debug 签名，用户覆盖安装时报「开发者签名异常」。"
    }
}

android {
    namespace = "com.kline.novelreader.novel_reader_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kline.novelreader.novel_reader_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutterVersionCode
        versionName = flutterVersionName
        manifestPlaceholders["appLabel"] = "藏书阁"
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // 本地构建一律换包名与应用名，装成一个独立的「藏书阁 Dev」，
        // 和从 Release 下载安装的正式版并排共存。
        //
        // 这么做是因为本地包只能用 debug 签名（正式密钥只存在于 CI），
        // 同包名不同签名会被系统判为冲突、必须先卸载正式版才能装，
        // 连带把书架和阅读进度一起清掉。换个包名就没这问题了。
        // 只有 CI 注入了正式密钥的 release 构建才保留原包名。
        all {
            if (name != "release" || !hasReleaseKeystore) {
                applicationIdSuffix = ".dev"
                versionNameSuffix = "-dev"
                manifestPlaceholders["appLabel"] = "藏书阁 Dev"
            }
        }

        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // 有正式密钥就用正式密钥；没有则退回 debug，保证本地
            // `flutter run --release` 不配密钥也能跑。
            // 发版链路不靠这个兜底——release.yml 缺密钥直接失败，
            // 并在出包后校验证书，debug 签名的包一律不许发。
            signingConfig = if (hasReleaseKeystore) {
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
