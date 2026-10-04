# ICE, STUN, and TURN Protocol Integration

## 1. RFC 8445 Interactive Connectivity Establishment (ICE)
PeerLink implements an RFC 8445 compliant ICE subsystem in `org.peerlink.core.net.ice`:
- **Candidate Gathering:** Gathers local `HOST` candidates from network interfaces, queries STUN servers for `SRFLX` candidates, and allocates `RELAY` candidates on coturn servers.
- **Candidate Priority Computation:** Follows RFC 8445 Section 5.1.2.1:
  $$\text{priority} = (2^{24} \cdot \text{typePref}) + (2^8 \cdot \text{localPref}) + (256 - \text{componentId})$$
  - HOST: 126
  - PRFLX: 110
  - SRFLX: 100
  - RELAY: 0
- **Candidate Pairing:** Cross-multiplies local and remote candidates by protocol (UDP with UDP, TCP with TCP), computing standard pair priorities.
- **Hysteresis Algorithm:** Prevents flapping between direct and relay paths during network fluctuations.

---

## 2. RFC 5389 STUN Client
- Operates over UDP.
- Sends standard 20-byte Binding Request (`0x0001`) with magic cookie `0x2112A442`.
- Parses `XOR-MAPPED-ADDRESS` (`0x0020`) and `MAPPED-ADDRESS` (`0x0001`) to discover public WAN IP and reflexive NAT port.

---

## 3. RFC 5766 / RFC 6156 TURN Client
- Connects to coturn servers using UDP or TCP.
- Authenticates using long-term credentials (`USERNAME`, `REALM`, `NONCE`, `MESSAGE-INTEGRITY` with HMAC-SHA1).
- Issues `ALLOCATE` requests, receiving a relayed public IP and port (`XOR-RELAYED-ADDRESS`).
- Creates permissions for remote peer IP before forwarding traffic.

---

## 4. Multi-Transport Policy
1. **QUIC over UDP:** Preferred for low-latency multiplexed transfers.
2. **TCP/TLS:** Direct TCP/TLS fallback when UDP is blocked by corporate firewalls.
3. **TURN over UDP:** Default relay when direct WAN hole-punching fails.
4. **TURN over TCP / TLS:** Fallback relay for restricted environments permitting only outbound TCP (ports 80/443).
5. **Direct-Only Policy:** Configurable option that completely disables relay allocation for strict local/air-gapped or compliance requirements.
