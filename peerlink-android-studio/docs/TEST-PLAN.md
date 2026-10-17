# PeerLink Android Studio Edition — Test Plan & Quality Gates

---

## 1. Quality Gates (Definition of Done)

- **Gate A — Project Independence:**
  No source file, build file, or test imports code outside `peerlink-android-studio/`. Verified by `scripts/verify-isolation.ps1`.
- **Gate B — IDE Usability:**
  Can be opened directly in Android Studio via Flutter root or `android/` subproject. Gradle sync succeeds.
- **Gate C — Build Correctness:**
  `flutter pub get`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, and `flutter test` pass with 0 errors. Android Gradle debug compilation succeeds and outputs `app-debug.apk`.
- **Gate D — Runtime Verification:**
  Application starts, initializes `AndroidNodeFacade`, renders Material 3 navigation without crash, and truthfully reports peer discovery and node states.
- **Gate E — Honest Status & Documentation:**
  Full test results and environment diagnostics documented without fabricated results.

---

## 2. Test Execution Hierarchy

1. **Dart Unit & Contract Tests (`test/unit/`, `test/contract/`):**
   - Protocol buffer serialization/deserialization.
   - Platform channel message encoding and parsing.
   - State machine transition rules.
2. **Flutter Widget Tests (`test/widget/`):**
   - Main navigation shell tab switching.
   - Send flow preflight validation UI.
   - Device pairing and trust revocation dialogues.
3. **Native Android Unit Tests (`android/app/src/test/`):**
   - Android Keystore key generation and alias stability.
   - Scoped Storage URI sanitization.
   - Environmental state context builder.
4. **Integration & Smoke Tests (`test/integration/`):**
   - End-to-end simulated node lifecycle.
