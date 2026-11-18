# ProGuard & R8 rules for PeerLink Android Release

# Keep Flutter Framework and Plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Keep All PeerLink application and core classes
-keep class org.peerlink.** { *; }
-keep interface org.peerlink.** { *; }
-keepclasseswithmembers class org.peerlink.** { *; }

# Keep Protobuf Generated Messages and Parsers
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# Keep BouncyCastle Providers and Algorithms
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# Keep Android WorkManager
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-dontwarn androidx.work.**

# Suppress logging and desktop Java warnings
-dontwarn org.slf4j.**
-dontwarn java.lang.management.**
-dontwarn java.net.http.**
-dontwarn java.time.**
