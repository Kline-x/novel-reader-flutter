# =============================================================================
# 藏书阁 (Novel Reader) 生产发布 ProGuard / R8 混淆与瘦身规则
# =============================================================================

# 1. 保护 Flutter 核心引擎与平台通道 (MethodChannel / EventChannel)
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# 2. 保护应用主入口与 Ability/Activity
-keep class com.kline.novelreader.novel_reader_flutter.** { *; }

# 3. 保护第三方原生插件 (flutter_tts, shared_preferences, path_provider 等)
-keep class com.tundralabs.fluttertts.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }

# 4. 保持反射属性与序列化字段注解
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# 5. 优化与瘦身：移除未使用的代码与无害警告
-dontwarn io.flutter.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**

# 6. 保留原生 Native 方法名以支持 JNI 绑定
-keepclasseswithmembernames class * {
    native <methods>;
}

# 7. 保留 Parcelable 序列化实现
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# 8. 保留枚举值
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
