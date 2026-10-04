# PeerLink Control Plane Architecture

## 1. Overview and Invariant
PeerLink integrates **Supabase** exclusively as an auxiliary **control plane**. PeerLink is an inherently distributed, local-first, peer-to-peer system.

> **CRITICAL ARCHITECTURAL INVARIANT:**
> Supabase **MUST NOT** store normal PeerLink user file contents, payload chunks, or transfer data.
> File payload transfers remain strictly direct peer-to-peer (via TLS over TCP or QUIC), or relayed through private P2P relays.

```
       +---------------------------------------------+
       |           Supabase Control Plane            |
       |  (Auth, Device Registry, Presence, Relay)   |
       +---------------------------------------------+
              ^                               ^
   HTTPS / WSS| (Control only)     HTTPS / WSS| (Control only)
              v                               v
       +--------------+               +--------------+
       | PeerLink     |               | PeerLink     |
       | Desktop Node |<=============>| Mobile Node  |
       +--------------+ Direct P2P    +--------------+
                        (TLS/QUIC)
                        File Payloads
```

---

## 2. Supabase Responsibilities
1. **Account Authentication (GoTrue / Auth v1):**
   - User identity credentials, JWT tokens, session lifecycle, and password resets.
2. **Device Registry (`device_registry`):**
   - Mapping account identity (`user_id`) to cryptographic device identity (Ed25519 `public_key` and stable `peer_id`).
3. **Presence Metadata (`device_presence`):**
   - Heartbeat-driven online/offline status, TTL expiration, and short-lived connectivity candidate endpoints (local IP/ports, public candidates).
4. **Signaling Coordination (`signaling_messages`):**
   - Ephemeral NAT traversal coordination: WebRTC Offers, Answers, ICE candidates, and pairing invites.
5. **Durable Control-Plane Records (`control_audit_log`):**
   - Audit trail of security events (device enrollment, revocation, key rotation).
6. **Policy & Share Metadata (`share_metadata`):**
   - Metadata for cross-device shared folder permissions and synchronization policies.

---

## 3. Realtime Protocol Principles
- Realtime WebSockets (Phoenix Channels protocol) are used **strictly as ephemeral hints and triggers**.
- PeerLink **never assumes** a Realtime event was delivered or received.
- **Durable PostgREST fallback:**
  - On startup, reconnection, or timer intervals, the client queries durable Postgres tables directly.
  - Ephemeral signaling messages are recorded in Postgres with `is_consumed = FALSE` and marked consumed after processing.
- **Deduplication:**
  - Client-side LRU cache suppresses duplicate event IDs if Realtime messages arrive multiple times.

---

## 4. Resilience & Outage Handling
- When Supabase is unreachable (HTTP 503, DNS failure, cloud outage):
  - Client-side `CircuitBreaker` trips to `OPEN` state after consecutive failures.
  - Prevents cascading blocking delays in desktop and mobile nodes.
  - PeerLink engine enters **degraded local-first mode**, continuing local transfers, LAN discovery (mDNS), and direct IP connections uninterrupted.
  - When connection is restored, the circuit breaker enters `HALF_OPEN`, confirms connectivity, returns to `CLOSED`, and initiates a durable catch-up query.
