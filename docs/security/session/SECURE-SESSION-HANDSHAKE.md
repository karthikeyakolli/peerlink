# Secure Peer Session & Cryptographic Handshake Specification

## 1. Security Invariants and Trust Model

### 1.1 Discovery is NOT Trust
- In PeerLink, local network discovery (mDNS/LAN broadcast) or cloud rendezvous (Supabase signaling) merely locates an addressable peer; **it conveys zero trust**.
- An incoming connection from a LAN IP or valid hostname is completely untrusted until authenticated cryptographically.

### 1.2 No Network Anchors
- **No IP address, port, hostname, or user alias may act as a trust anchor.**
- Trust is strictly rooted in:
  1. The peer's durable Ed25519 public key (`CryptographicKey`).
  2. The local device's `TrustStore` containing pre-paired or explicit user-verified peer identities (`TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED`).

---

## 2. Cryptographic Handshake Protocol (3-Way Mutual Authentication)

```
Initiator (Alice)                               Responder (Bob)
   │                                               │
   │  1. SYN Frame (Challenge & Transports)         │
   ├──────────────────────────────────────────────>│
   │                                               │ [Verify Sig, Nonce, Time]
   │                                               │ [Check Bob's TrustStore]
   │                                               │ [Select Mutual Transport]
   │  2. SYN_ACK Frame (Response Challenge)       │
   │<──────────────────────────────────────────────┤
   │                                               │
[Verify Bob's Sig, Nonce]                          │
[Check Alice's TrustStore]                         │
   │  3. ACK Frame (Session Established)           │
   ├──────────────────────────────────────────────>│
   │                                               │
=== AUTHENTICATED ENCRYPTED SESSION ESTABLISHED ===
```

### 2.1 Challenge Structure
Both peers sign a challenge constructed as:
$$\text{Challenge} = \text{SHA256}(\text{peer\_id} \mathbin{\Vert} \text{connection\_id} \mathbin{\Vert} \text{session\_id} \mathbin{\Vert} \text{nonce} \mathbin{\Vert} \text{timestamp\_ms})$$

Signed using Ed25519 (`Ed25519Signer` / JCA `EdDSA`).

### 2.2 Phase 1: `HANDSHAKE_PHASE_SYN` (Initiator -> Responder)
The initiator generates:
- Unique `SessionId` (e.g., `sess_<UUID>`)
- Local `ConnectionId`
- 32-byte cryptographically secure random `nonce`
- Current UTC timestamp in milliseconds
- Ed25519 signature over challenge
- List of supported transports sorted by priority

### 2.3 Phase 2: `HANDSHAKE_PHASE_SYN_ACK` (Responder -> Initiator)
The responder validates:
1. **Protocol Version Compatibility:** Major version must match (`isVersionCompatible`). Rejects with `ERROR_CODE_INCOMPATIBLE_PROTOCOL_VERSION` if incompatible.
2. **Malformed Checks:** Missing identity, nonce, or signature rejects with `ERROR_CODE_UNAUTHENTICATED`.
3. **Replay & Freshness Protection:**
   - Freshness window: $|\text{timestamp} - \text{now}| \le 30\text{ seconds}$.
   - Nonce freshness: Nonce hex checked against `seenNonces` set. If duplicate, rejects with `ERROR_CODE_UNAUTHENTICATED`.
4. **Cryptographic Proof:** Remote Ed25519 public key verifies the challenge signature. Rejects with `ERROR_CODE_UNAUTHENTICATED` on failure.
5. **TrustStore Verification:** Remote `peer_id` must exist in local `TrustStore` with trusted status. Rejects with `ERROR_CODE_UNAUTHORIZED` if untrusted.
6. **Duplicate Session Prevention:** If an active session already exists for `peer_id`, rejects with `ERROR_CODE_CONFLICT_DETECTED`.
7. **Transport Negotiation:** Selects highest-priority mutual transport.

The responder then generates its own 32-byte nonce, signs the challenge, and returns `HANDSHAKE_PHASE_SYN_ACK`.

### 2.4 Phase 3: `HANDSHAKE_PHASE_ACK` (Initiator -> Responder)
The initiator validates responder's signature and trust status, then emits `HANDSHAKE_PHASE_ACK`. Both nodes mark the session state as `SESSION_STATE_ESTABLISHED`.

---

## 3. Resource Bounds and Defensive Engineering

| Constraint | Limit | Rationale |
| :--- | :--- | :--- |
| **Max Concurrent Handshakes** | 64 | Prevents resource exhaustion / handshake DoS |
| **Handshake Timeout** | 5 seconds | Aborts hung or unresponsive handshakes |
| **Max Timestamp Skew** | 30 seconds | Bounds replay attack windows |
| **Max Frame Size** | 16 MB | Protects against memory exhaustion from oversized frames |
| **Replay Cache** | Monotonic set | Disallows reused nonces across sessions |

---

## 4. Machine-Readable Error Codes

When a handshake is rejected, a `HANDSHAKE_PHASE_REJECT` frame is returned containing an `ErrorDetail`:
- `ERROR_CODE_UNAUTHENTICATED` (1004): Signature failure, timestamp expired, replay attack, or malformed frame.
- `ERROR_CODE_UNAUTHORIZED` (1005): Peer identity valid cryptographically but not present in local `TrustStore`.
- `ERROR_CODE_INCOMPATIBLE_PROTOCOL_VERSION` (1007): Major protocol version mismatch.
- `ERROR_CODE_RESOURCE_EXHAUSTED` (1008): Exceeded maximum concurrent handshakes limit.
- `ERROR_CODE_CONFLICT_DETECTED` (1010): Duplicate active session already exists for this peer.
