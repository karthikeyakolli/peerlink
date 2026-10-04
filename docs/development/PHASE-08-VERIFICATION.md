# Phase 08 Verification: Supabase Control Plane

## Objective
Integrate Supabase without violating PeerLink's distributed architecture:
- Supabase responsibilities: account auth, device registry, durable control-plane records, presence metadata, signaling coordination, share/control metadata, policy support.
- **CRITICAL INVARIANT:** Supabase **MUST NOT** store normal PeerLink file contents.
- Realtime: Used exclusively for ephemeral notification/coordination; never assume received; durable state must be queryable via REST/database.
- Implement Java-side Supabase adapter rather than relying on an unofficial Java SDK.

---

## 1. Architecture & Deliverables

### 1.1 PostgreSQL Schema & Migrations (`supabase/migrations/`)
- `20261002000000_control_plane_baseline.sql`: Core baseline tables (`device_registry`, `device_presence`, `pairing_requests`, `share_metadata`, `control_audit_log`).
- `20261002000001_presence_signaling_and_rls.sql`:
  - Ephemeral WebRTC `signaling_messages` with automatic cleanup.
  - Enhanced presence with configurable `ttl_seconds` and `active_device_presence` view.
  - Row Level Security (RLS) policies for least-privilege authenticated access.

### 1.2 Java Native Supabase Adapter (`org.peerlink.core.cloud.supabase`)
- Zero external third-party SDK dependencies.
- Components built using Java 17 standard libraries (`java.net.http.HttpClient`, `WebSocket`):
  - `SupabaseConfig`: Configuration management with programmatic service-role key rejection and environment constraints (`DEV`, `STAGING`, `PROD`).
  - `SimpleJson`: Zero-dependency JSON serializer and parser for high-performance transport mapping.
  - `SupabaseAuthSession`: JWT access and refresh token lifecycle model.
  - `SupabaseAuthClient`: HTTPS client for GoTrue auth (signup, password login, token refresh, logout).
  - `SupabaseRestClient`: PostgREST HTTP client with automated retries and circuit breaker protection.
  - `SupabaseRealtimeClient`: Phoenix Channel WebSocket client with heartbeat, subscribe, and deduplication.
  - `CircuitBreaker`: Outage detection, failure tracking, and degraded mode isolation.
  - `RetryPolicy`: Exponential backoff with jitter.
  - `SupabaseControlPlaneCoordinator`: Central orchestrator tying auth, device registration, presence heartbeats, signaling dispatch, and durable catch-up.

---

## 2. Test Verification Matrix

All 9 required test scenarios implemented in `SupabaseControlPlaneTest.java` and verified:

| Test Scenario | Implementation & Verification | Result |
| :--- | :--- | :--- |
| **1. login** | `testAuthLogin`: Verifies password sign-in against `/auth/v1/token?grant_type=password`, acquiring access and refresh tokens, user ID, and expiration. | **PASS** |
| **2. register device** | `testRegisterDevice`: Verifies account-to-device binding in `device_registry` linking `user_id` to cryptographic Ed25519 `public_key` and stable `peer_id`. | **PASS** |
| **3. device appears/disappears** | `testDeviceAppearsAndDisappears`: Verifies publishing candidate endpoints with status `ONLINE` and graceful departure to `OFFLINE`. | **PASS** |
| **4. reconnect** | `testReconnectHandling`: Verifies Phoenix channel subscription, automated heartbeat pinging, and connection recovery handlers. | **PASS** |
| **5. duplicate event** | `testDuplicateEventSuppression`: Verifies bounded LRU deduplication cache discarding duplicate message IDs from Realtime. | **PASS** |
| **6. missed event** | `testMissedEventDurableCatchUp`: Verifies falling back to durable PostgREST query on `signaling_messages` when Realtime delivery is missed. | **PASS** |
| **7. Supabase outage** | `testSupabaseOutageAndCircuitBreaker`: Verifies circuit breaker tripping to `OPEN` after threshold failures, throwing `SupabaseOutageException`, fast-failing during outage, and recovering to `CLOSED` after reset timeout. | **PASS** |
| **8. stale presence** | `testStalePresenceDetection`: Verifies TTL calculation identifying heartbeats older than `ttl_seconds` as stale/offline. | **PASS** |
| **9. expired session** | `testExpiredSessionRefresh`: Verifies session expiration detection and automatic refresh token exchange. | **PASS** |
| **Security Invariant 1** | `testRejectsServiceRoleKey`: Verifies client rejects service-role keys at construction. | **PASS** |
| **Full Lifecycle Invariant** | `testCoordinatorLifecycle`: Verifies end-to-end coordinator start, heartbeat, signaling dispatch, and shutdown. | **PASS** |

---

## 3. Test Execution Summary

### Core Test Suite
- `org.peerlink.core.cloud.supabase.SupabaseControlPlaneTest`: **11/11 tests passed**
- Total `peerlink-core` tests: **53/53 tests passed**
- Total `peerlink-desktop-node` tests: **32/32 tests passed**
- Total Flutter UI / Protocol tests: **12/12 tests passed**
- Total test count across all suites: **97/97 tests passed** with **0 failures, 0 errors, 0 skipped**.

---

## 4. Status

PHASE 08 STATUS: PASS
