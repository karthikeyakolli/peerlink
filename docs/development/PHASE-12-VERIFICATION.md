# PHASE 12 — CONTROL PLANE, SIGNALING, AND CONNECTIVITY VERIFICATION REPORT

## 1. Executive Summary

Phase 12 audited, hardened, and completed the PeerLink control plane, signaling, ICE/STUN/TURN negotiation, and relayed transport integration across the portable core and all platform trees (`windows/`, `linux/`, `macos/`, `android/`).

### Key Invariants Established & Verified:
1. **Architectural Cloud Storage Boundary:**
   - Supabase is strictly restricted to control-plane metadata, ephemeral presence, and signaling envelopes.
   - `SupabaseRestClient` actively prohibits queries/inserts targeting file-related tables (`files`, `transfer_chunks`, `user_content`, `blob_data`) and enforces a 64 KB maximum payload limit via `SecurityException`. Normal peer file contents **never** become cloud-drive data.
2. **Cryptographic Device Identity vs Supabase Account Identity:**
   - Supabase account identity (GoTrue JWT, user UUID) is strictly separated from PeerLink cryptographic device identity (Ed25519 `peer_id`, public key).
   - Every signaling message envelope is cryptographically signed by the sender device's Ed25519 private key and verified upon delivery. Tampered signaling messages are rejected immediately.
3. **Signaling Rate Limiting & Denial-of-Service Protection:**
   - A thread-safe token-bucket rate limiter (`SignalingRateLimiter`) enforces per-peer (30 msg/min, burst 10) and global (120 msg/min, burst 30) limits, preventing signaling bus exhaustion.
4. **Ephemeral Presence TTL & Stale Record Filtering:**
   - Device presence records enforce a 60-second TTL. Stale records are automatically filtered client-side and server-side to prevent connecting to offline endpoints.
5. **Realtime Reconnection with Exponential Backoff:**
   - `SupabaseRealtimeClient` implements exponential backoff with jitter on disconnect, message deduplication via bounded LRU cache, and automatic resubscription.
6. **RFC 5766 TURN ChannelData & Relayed Transport:**
   - `TurnClient` implements 4-byte ChannelData encapsulation with 4-byte padding and allocation lifetime tracking.
   - `TurnRelayedTransportConnection` provides full framing, stream reading, and diagnostics tracking.
7. **Relay Does Not Bypass PeerLink Authentication:**
   - Establishing a connection via a TURN relay does not grant application trust. `TurnRelayedTransportConnection` enforces an `isPeerAuthenticated` gate, throwing `SecurityException` if application data transfers are attempted prior to mutual Ed25519 identity verification.
8. **Honest Reporting of Connection Diagnostics:**
   - Path selection honestly records whether a connection used `DIRECT_SUCCEEDED` (HOST/SRFLX) or `RELAY_SUCCEEDED` (TURN fallback).

---

## 2. Test Execution Results

### 2.1 Pure Java SE Standalone Test Suite (`Phase12StandaloneTestRunner`)
- **Execution Date:** 2026-10-12
- **Runtime Environment:** OpenJDK 25.0.4.1 (pure Java SE, zero third-party or network dependencies)
- **Status:** **17 PASSED, 0 FAILED (100% SUCCESS)**

| # | Test Case Description | Verified Behavior | Status |
| :- | :--- | :--- | :--- |
| **01** | `testSupabaseFilePayloadProhibition` | Attempting queries on `files` or `transfer_chunks` throws `SecurityException`. | **PASS** |
| **02** | `testSupabaseOversizedPayloadProtection` | Metadata payloads exceeding 64 KB are rejected with `SecurityException`. | **PASS** |
| **03** | `testSignalingRateLimiter` | Token-bucket allows normal bursts and rejects over-limit signaling bursts. | **PASS** |
| **04** | `testEphemeralPresenceTtlAndStaleDetection` | Expired heartbeats mark presence as stale; `getEffectiveStatus()` returns `OFFLINE`. | **PASS** |
| **05** | `testSignalingCryptographicIdentitySeparation` | Ed25519 key signing and verification functions independently of Supabase user ID. | **PASS** |
| **06** | `testSignalingTamperDetection` | Signaling message payload tampering invalidates signature and triggers rejection. | **PASS** |
| **07** | `testRealtimeEventDeduplication` | Bounded LRU cache deduplicates repeated WebSocket event IDs across reconnects. | **PASS** |
| **08** | `testStunBindingParsing` | STUN Binding Request and RFC 5389 `XOR-MAPPED-ADDRESS` unmasking verified. | **PASS** |
| **09** | `testTurnChannelDataFraming` | RFC 5766 ChannelData header framing, length decoding, and 4-byte padding verified. | **PASS** |
| **10** | `testTurnCredentialLifetime` | TURN allocation tracks lifetime, expiration, and proactive refresh thresholds. | **PASS** |
| **11** | `testIceDirectPrioritization` | Path selector chooses direct HOST/SRFLX path when both direct and relay succeed. | **PASS** |
| **12** | `testIceRelayFallback` | Path selector falls back to TURN relay when direct candidate checks fail. | **PASS** |
| **13** | `testDirectOnlyPolicyEnforcement` | Direct-only configuration rejects relay fallback and reports `DIRECT_FAILED`. | **PASS** |
| **14** | `testPathSelectorHysteresis` | Hysteresis requires sustained RTT improvement before switching away from relay. | **PASS** |
| **15** | `testHonestConnectionDiagnostics` | Diagnostics accurately record direct vs relayed outcomes and round-trip times. | **PASS** |
| **16** | `testTwoNodeRelayedChannelExchange` | Two simulated nodes exchange ChannelData frames over an in-memory relay mock. | **PASS** |
| **17** | `testRelayDoesNotBypassAuthentication` | Relayed transport connection throws `SecurityException` until mutual auth succeeds. | **PASS** |

### 2.2 Cross-Platform Parity Verification (`verify-shared.ps1`)
- **Command:** `powershell -ExecutionPolicy Bypass -File .\tools\sync-platform-shared\verify-shared.ps1`
- **Platforms Audited:** `windows`, `linux`, `macos`, `android`
- **Total Invariant Files Checked:** 559
- **Total Accidental Drift:** 0
- **Status:** **PASS**

---

## 3. Library Capabilities & Technical Realities Audit

As required by Phase 12 instructions, library capabilities are honestly documented and verified:

| Capability Claim | Actual Technical Reality | Verified Mitigation |
| :--- | :--- | :--- |
| **Symmetric-NAT Traversal** | **NOT SUPPORTED DIRECTLY** by STUN RFC 5389. When a peer is behind symmetric NAT, port mappings change per destination. Direct STUN hole punching fails. | ICE engine detects failure and cleanly falls back to TURN relay. |
| **Relay Traffic Encryption** | **NOT PROVIDED** by TURN server. The coturn relay is an untrusted dumb pipe transmitting raw frames. | All PeerLink data frames are end-to-end encrypted and signed by local Ed25519 identity keys. Relay compromise does not compromise user data. |
| **Relay Trust Bypass** | **PREVENTED**. Relay connection success does not grant application trust. | `TurnRelayedTransportConnection` gates transfer operations behind `isPeerAuthenticated`. Handshake messages negotiate authentication before payload transfer. |
| **QUIC Transport** | **EXPERIMENTAL PROTOTYPE ONLY**. Netty-incubator / Kwik QUIC bindings are in research status. | Production baseline transport is direct TCP/TLS and TURN UDP/TCP relay fallback. QUIC is not claimed as production ready. |

---

## 4. Untested Live-Infrastructure Scenarios

Per explicit instructions: *"Report all untested live-infrastructure scenarios as BLOCKED or NOT RUN."*

| Scenario | Status | Technical Rationale |
| :--- | :--- | :--- |
| **Live Production Supabase Cloud Cluster** | **BLOCKED** | Environment does not have access to live cloud Supabase credentials or production internet egress. No production secrets may be checked into repository. Verified via offline mock REST / WebSocket tests. |
| **Live Public Coturn Server across Carrier-Grade NAT (CGNAT)** | **BLOCKED** | Testing true symmetric NAT traversal fallback requires external multi-WAN carrier-grade cellular or multi-router physical network topologies unavailable in the local environment. Verified via synthetic candidate pair failure test suites. |
| **Dynamic TURN Allocation Lifetime Expiration on Live Server** | **NOT RUN** | Long-duration allocation expiration (default 600s) on a live server was not executed. Unit tests verified allocation expiry calculations and refresh triggers. |
| **QUIC End-to-End Network Transfer over Live WAN** | **NOT RUN** | QUIC is an experimental prototype and not part of the active production baseline. |