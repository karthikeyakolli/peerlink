# PeerLink Android Studio Edition — Troubleshooting Guide

---

## 1. Common Issues and Resolutions

### Issue 1: "flutter.sdk not set in local.properties"
- **Cause:** Android Studio opened `android/` directly before Flutter initialized `local.properties`.
- **Fix:** Run `flutter pub get` from `peerlink-android-studio/` or execute `.\scripts\setup.ps1`. This creates `android/local.properties` pointing to your Flutter SDK.

### Issue 2: "Java heap space / OutOfMemoryError during Gradle build"
- **Cause:** Gradle daemon ran out of memory compiling native dependencies and protobuf.
- **Fix:** Verify `android/gradle.properties` contains:
  ```properties
  org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m
  ```

### Issue 3: "Device discovery returns 0 peers"
- **Cause:** Android requires `NEARBY_WIFI_DEVICES` (Android 13+) or `ACCESS_FINE_LOCATION` (Android 12-) permissions, and Wi-Fi Multicast must be enabled.
- **Fix:** In device settings, grant the "Nearby devices" permission to PeerLink, and ensure both devices are connected to the same Wi-Fi subnet with AP isolation disabled.

### Issue 4: "Android KeyStore provider throws KeyStoreException"
- **Cause:** Device lock screen credentials changed or KeyStore alias invalidated.
- **Fix:** The app recovers gracefully by generating a new stable keypair, but past trust tokens will need to be re-verified with peers.
