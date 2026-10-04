# Internet P2P Networking Architecture

## 1. Overview
PeerLink's Phase 09 transitions the system from local-area-network (LAN) operation to full Internet peer-to-peer connectivity across arbitrary firewalls, home NATs, and symmetric enterprise boundaries.

```
+-------------------------------------------------------------------+
|                        Signaling Plane                            |
|             (Supabase ephemeral signaling_messages)               |
+-------------------------------------------------------------------+
                                  |
                                  v
+-------------------------------------------------------------------+
|                         ICE Engine                                |
|        (Candidate gathering: HOST, STUN srflx, coturn relay)      |
+-------------------------------------------------------------------+
                                  |
                                  v
+-------------------------------------------------------------------+
|                       Path Selection                              |
|           Direct-first priority, Anti-flapping Hysteresis         |
+-------------------------------------------------------------------+
              /                                           \
             v                                             v
+--------------------------+                 +--------------------------+
|       Direct Path        |                 |      Relayed Path        |
|  (QUIC UDP or TCP/TLS)   |                 | (coturn TURN UDP or TCP) |
+--------------------------+                 +--------------------------+
             |                                             |
             +---------------------+-----------------------+
                                   |
                                   v
+-------------------------------------------------------------------+
|               End-to-End Cryptographic Session                    |
|      (Ed25519 identity, Mutual TLS / Noise session cipher)        |
+-------------------------------------------------------------------+
```

---

## 2. Invariant: Separation of Transport and Content
- **Supabase is never used as file storage.**
- **Relay never sees application plaintext.**
- All file chunks and control messages transmitted across either direct paths or coturn TURN relays are fully end-to-end encrypted under the session cryptographic keys derived during mutual peer authentication.

---

## 3. Path Selection Hierarchy
1. **HOST (Direct LAN):** Highest preference. Latency < 5ms.
2. **SRFLX (STUN Reflexive WAN):** Direct peer-to-peer connection punched through router NATs using public reflexive mappings. Latency 15ms - 80ms.
3. **RELAY (coturn TURN):** Used strictly as a fallback when direct connectivity checks fail (e.g. double symmetric NAT, restrictive enterprise firewalls, or UDP blockage).
