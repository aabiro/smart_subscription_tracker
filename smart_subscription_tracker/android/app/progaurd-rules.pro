# Keep rules based on R8 "Missing class" errors.
# These are essential to prevent the classes from being removed.
-keep class com.google.errorprone.annotations.CanIgnoreReturnValue { *; }
-keep class com.google.errorprone.annotations.CheckReturnValue { *; }
-keep class com.google.errorprone.annotations.Immutable { *; }
-keep class com.google.errorprone.annotations.RestrictedApi { *; }
-keep class javax.annotation.Nullable { *; }
-keep class javax.annotation.concurrent.GuardedBy { *; }

# Rules from your missing_rules.txt (to suppress warnings, if still needed)
-dontwarn com.google.errorprone.annotations.CanIgnoreReturnValue
-dontwarn com.google.errorprone.annotations.CheckReturnValue
-dontwarn com.google.errorprone.annotations.Immutable
-dontwarn com.google.errorprone.annotations.RestrictedApi
-dontwarn javax.annotation.Nullable
-dontwarn javax.annotation.concurrent.GuardedBy

# --- Added/Updated Rules for Google Tink ---
# Keep all public classes and their public members in the com.google.crypto.tink package
# This is a common approach for libraries that R8 might strip too aggressively.
-keep public class com.google.crypto.tink.** {
    public *;
}
# Keep all public interfaces and their public members in the com.google.crypto.tink package
-keep public interface com.google.crypto.tink.** {
    public *;
}

# If Tink uses Protocol Buffers extensively and those are also being stripped,
# you might need rules for them too. For example:
-keep class com.google.protobuf.GeneratedMessageLite { *; }
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }
-keep public enum com.google.protobuf.** { *; public static **[] values(); public static ** valueOf(java.lang.String); }

# General good practices (optional, but can help prevent other issues):
# Flutter specific rules are usually handled by the Flutter Gradle plugin.

# If you still face issues with specific libraries after adding these rules,
# you might need to consult their documentation for any specific ProGuard/R8 rules.

# Flutter-specific rules
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# Retrofit
-keep class retrofit2.** { *; }
-dontwarn retrofit2.**

# OkHttp
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**

# Gson
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
-keepattributes Signature
-keepattributes *Annotation*

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# Suppress warnings for common annotations
-dontwarn javax.annotation.**
-keep class javax.annotation.** { *; }

# General good practices
-dontwarn sun.misc.**
-dontwarn java.nio.file.**
