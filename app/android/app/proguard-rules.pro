# ProGuard Rules for MediFamily
# 保留 TPNS 相关类
-keep class com.tencent.android.tpush.** { *; }
-keep class com.tencent.tpns.** { *; }

# 保留 Firebase
-keep class com.google.firebase.** { *; }

# 保留 Flutter 框架
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 保留序列化相关（JSON）
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
