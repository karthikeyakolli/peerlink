# PeerLink — Known Technical Limitations & Environment Constraints

**Document Version:** 1.0.0  
**Phase:** 13.0 Complete Product-Wide UX Redesign  

---

## 1. Hardware & Environment Disclosures

1. **Zero Physical Android Devices Attached via ADB:**
   - Command `& "$env:LOCALAPPDATA\Android\Sdk\platform-toolsdb.exe" devices` reports 0 connected physical devices or emulators.
   - Physical routerless Wi-Fi Direct throughput benchmarks and hardware camera sensor autofocus testing remain deferred to physical hardware lab testing.
   - All unit, integration, and widget tests execute truthfully against the Flutter desktop and Android Robolectric test engines.
2. **Android SAF Deep Traversal Performance:**
   - Traversal of extensive directory trees via Android Storage Access Framework (`DocumentFile`) is governed by Android OS IPC limits. PeerLink caches document metadata during large batch transfers to mitigate OS latency.
3. **Desktop Webcam Camera Integration:**
   - QR invitation scanning on Windows/Linux depends on external USB webcam drivers. PeerLink provides a manual string paste fallback for pairing codes if no webcam is detected.
