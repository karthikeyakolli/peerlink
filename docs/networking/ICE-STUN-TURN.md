# ICE, STUN, and TURN Protocol Integration & Transport Capabilities

## 1. Verified Transport Capabilities & Technical Realities

> [!CAUTION]
> **Honest Assessment of NAT Traversal & Protocols:**
> - **Symmetric NAT Traversal:** RFC 5389 STUN **cannot** traverse symmetric NAT (where the NAT device allocates a different external port for each remote destination). In symmetric NAT environments, direct connection negotiation fails and connections **must fall back to TURN relay**.
> - **Relay Encryption & Trust Model:** The coturn TURN relay is an **untrusted dumb pipe**. It implements RFC 5766 ChannelData framing, but does **not** provide application encryption. PeerLink payloads are end-to-end encrypted and mutually authenticated at the application layer.
> - **QUIC Status:** QUIC is currently an **experimental prototype**; the verified production baseline is TCP/TLS socket transport with TURN UDP/TCP relay fallback.
> - **Relay Authentication:** Relayed connections **never bypass** PeerLink cryptographic authentication or application authorization. `TurnRelayedTransportConnection` gates transfer requests behind `isPeerAuthenticated`.

---

## 2. Interactive Connectivity Establishment (RFC 8445 ICE Lite / Full)

PeerLink implements an ICE candidate gathering and path selection engine in `org.peerlink.core.net.ice`:

### 2.1 Candidate Gathering & Priority Computation
Candidates are gathered across three types:
1. `HOST`: Direct local network interface IP and port (RFC 8445 priority preference 126).
2. `SRFLX`: Server-reflexive public IP and port discovered via STUN (priority preference 100).
3. `RELAY`: Relayed IP and port allocated on a coturn TURN server (priority preference 0).

Candidate priority follows RFC 8445 Section 5.1.2.1:
$$\text{priority} = (2^{24} \cdot \text{typePref}) + (2^8 \cdot \text{localPref}) + (256 - \text{componentId})$$

### 2.2 Path Selection & Hysteresis
- **Direct Prioritization:** When both direct (`HOST`/`SRFLX`) and relayed candidate pairs succeed, the path selector always selects the direct path.
- **Relay Fallback:** If all direct candidate checks fail or time out, the engine falls back to `RELAY` candidates.
- **Direct-Only Policy:** Nodes configured with a strict direct-only policy reject relay fallback and report `DIRECT_FAILED` rather than routing traffic through third-party relays.
- **Anti-Flapping Hysteresis:** When transitioning from relay to direct, the direct path must exhibit at least 20% lower RTT for multiple consecutive intervals to prevent oscillation.

---

## 3. RFC 5389 STUN Client Implementation

The STUN client implementation (`StunClient`) provides:
- UDP transaction with 20-byte STUN Binding Request (`0x0001`) and Magic Cookie (`0x2112A442`).
- 96-bit cryptographically secure transaction IDs.
- Decoding of `XOR-MAPPED-ADDRESS` (`0x0020`) with XOR unmasking against the magic cookie and transaction ID to discover public WAN IP and port.
- Timeout detection and retry handling.

---

## 4. RFC 5766 TURN Client & ChannelData Framing

### 4.1 Allocation Lifecycle & Credential Expiration
The `TurnClient` manages allocations on coturn servers:
- Long-term credential authentication via HMAC-SHA1 `MESSAGE-INTEGRITY`.
- Allocation creation via `ALLOCATE` request, obtaining a public relayed endpoint.
- Tracking allocation lifetime:
  - `TurnAllocation.isExpired()` checks whether the allocation has elapsed its granted lifetime.
  - `TurnAllocation.needsRefresh(marginSeconds)` prompts proactive refresh before expiration.
- Peer permissions (`CREATE-PERMISSION`) to authorize remote peer traffic.

### 4.2 ChannelData Framing (RFC 5766 Section 11)
When high-bandwidth data transfers occur over TURN, the client binds a channel (e.g., `0x4000`) and encapsulates data using 4-byte ChannelData headers:
- `[2 bytes Channel Number (0x4000..0x7FFF)]`
- `[2 bytes Payload Length (N)]`
- `[N bytes Application Payload]`
- `[0..3 bytes Padding to 4-byte boundary]`

---

## 5. Relay Security & Authentication Gates

### 5.1 Zero Relay Trust
The relay server is strictly untrusted:
1. Relayed data contains encrypted and signed PeerLink frames (`TransportFrame`).
2. Turn relay servers cannot inspect, forge, or modify payloads without failing cryptographic verification.

### 5.2 Mandatory Peer Authentication Gate
Establishing a connection through a TURN relay **does not** imply mutual trust or authorization.
In `TurnRelayedTransportConnection`:
- `isPeerAuthenticated` starts as `false`.
- Calling `checkApplicationTransferAuthorization()` before completing mutual cryptographic identity verification throws a `SecurityException`.
- Transfer sessions only commence once both peers have completed the Ed25519 handshake and verified peer identities.

---

## 6. Honest Diagnostics Reporting

Connection outcomes are recorded in `ConnectionDiagnostics`:
- `DIRECT_SUCCEEDED`: Direct HOST or SRFLX path connected.
- `RELAY_SUCCEEDED`: Fallback to TURN relay path used.
- `DIRECT_FAILED`: Direct connection failed (e.g., under direct-only policy).
- `TOTAL_FAILURE`: Both direct and relay paths failed.

The runtime logs and surfaces the exact path used (`isDirect()` vs `isRelayed()`) without obfuscating relay usage.
