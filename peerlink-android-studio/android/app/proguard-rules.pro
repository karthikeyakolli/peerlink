# ProGuard rules for PeerLink Android
-keep class org.peerlink.protocol.v1.** { *; }
-keep class org.peerlink.core.android.** { *; }
-keep class org.peerlink.app.** { *; }
-dontwarn java.lang.management.**
-dontwarn java.net.http.**
