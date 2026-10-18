# PeerLink Android Studio Edition — Competitive Reverse-Engineering Matrix

**Document Version:** 1.0.0  
**Research Date:** 2026-10-18  
**Author:** Lead Android / Flutter / P2P Systems Engineer  
**Target Project:** `peerlink-android-studio/`  
**Purpose:** Reverse-engineer observable workflows, public technical architectures, protocol designs, and implementation patterns across leading file-sharing and synchronization platforms. Formulate concrete, evidence-backed ADOPT / ADAPT / LATER / REJECT recommendations tailored to PeerLink's frozen privacy-first, decentralized architecture.

---

## 1. Executive Summary & Evaluation Taxonomy

PeerLink aims to deliver zero-configuration, dependable peer-to-peer file sharing and synchronization on Android without routing user data through centralized cloud intermediaries or sacrificing cryptographic verification.

To prevent architectural reinventing and identify battle-tested patterns, eight industry reference systems were audited across mobile and desktop runtimes:
- **Reference A: LocalSend** (LAN Multicast + HTTP/REST + TLS)
- **Reference B: Google Quick Share & Nearby Connections** (Multi-Radio Transport Abstraction + UKEY2)
- **Reference C: Syncthing** (BEP Block Exchange + Causal Vector Clocks + Selective Retransmit)
- **Reference D: KDE Connect** (Long-term Pairing + Device Capability Contracts + TLS Sockets)
- **Reference E: PairDrop** (WebRTC DataChannels + WebSocket Signaling + ICE/STUN/TURN)
- **Reference F: Magic Wormhole** (Mailbox Rendezvous + SPAKE2 PAKE + Transit Relay)
- **Reference G: Resilio Sync** (Selective Sync Placeholders + Read/Write/Encrypted Keys)
- **Reference H: WhatsApp & Telegram** (Consumer UX Mental Models: Recipient-first, Jargon-free State)

### Decision Taxonomy
Each evaluated mechanism receives one of four explicit determinations:
1. **ADOPT:** Suitable for PeerLink with minimal adaptation; directly conforms to existing contracts and architecture.
2. **ADAPT:** Valuable concept, but must be redesigned to conform to PeerLink's protocol, security model, and Android implementation.
3. **LATER:** Valid pattern, but deferred until the foundational local transport, pairing, or remote signaling phases are complete.
4. **REJECT:** Unnecessary, insecure, incompatible with privacy-first principles, or violates frozen architecture rules.

---

## 2. Competitive Reverse-Engineering In-Depth Analysis

### Reference A — LocalSend
- **Sources & Evidence:**
  - Protocol Specification: [https://github.com/localsend/protocol](https://github.com/localsend/protocol)
  - Application Repository: [https://github.com/localsend/localsend](https://github.com/localsend/localsend) (v1.14.0+)
- **Observed Workflow:**
  1. Multicast UDP packet broadcasted on `224.0.0.167:53317` announcing device metadata (alias, device model, device type, port, protocol version, download token).
  2. Fallback: If multicast fails or is disabled (e.g. AP isolation), devices perform manual IP subnet scan (e.g. `192.168.1.0/24`) sending HTTP `GET /api/localsend/v2/info`.
  3. Sender sends HTTP `POST /api/localsend/v2/prepare-upload` containing JSON file metadata (file IDs, names, sizes, file types, SHA-256 preview if available).
  4. Receiver displays native confirmation dialog. If user accepts, receiver generates session-specific upload tokens for each file.
  5. Sender streams file payloads via HTTP `POST /api/localsend/v2/upload?fileId=...&token=...` over TLS using self-signed certificates with SHA-256 fingerprint validation.
  6. Receiver tracks byte offsets and writes directly to target directory.
- **Underlying Architectural Pattern:**
  - Metadata-first preflight negotiation over HTTP/2 / REST, followed by distinct payload streaming endpoints.
  - Discovery fallback ladder (Multicast UDP -> Subnet IP Sweep -> Manual IP/Port).
- **Advantages & Limitations:**
  - *Advantages:* Extremely low latency on permissive LANs; firewall-friendly because standard HTTP ports/verbs are used; easy receiver-side flow control.
  - *Limitations:* Fails completely across distinct subnets or cellular networks; TLS uses ad-hoc self-signed certs rather than persistent asymmetric cryptographic identities; prone to man-in-the-middle without out-of-band certificate verification.
- **Security & Privacy Implications:**
  - Multicast broadcasts device model and IP unencrypted to anyone on the LAN.
  - No mutual asymmetric authentication before metadata exchange.
- **PeerLink Evaluation & Decisions:**
  - **ADAPT (Metadata-First Preflight & Receiver Consent):** Adopt the two-phase handshake pattern where file metadata and chunk manifests are accepted/rejected by the receiver *before* any byte streaming begins. Adapt to PeerLink's Protobuf framing over TLS/TCP.
  - **ADAPT (Subnet Sweep Discovery Fallback):** When NSD/mDNS multicast is blocked by enterprise Wi-Fi or router AP isolation, adapt a bounded local subnet probe to discover active PeerLink listeners.
  - **REJECT (Unauthenticated Self-Signed TLS & Raw HTTP REST):** PeerLink requires Ed25519 mutual authentication (`DERIVATION_RULE_V1`) and Protobuf RPC framing; raw unpinned HTTPS REST is rejected.
- **Licensing:** MIT License. Cleanroom conceptual adaptation.

---

### Reference B — Google Quick Share & Nearby Connections
- **Sources & Evidence:**
  - Developer Documentation: [https://developers.google.com/nearby/connections/overview](https://developers.google.com/nearby/connections/overview)
  - Android Open Source Project (AOSP) Nearby references & Nearby Connections C++ Core: [https://github.com/google/nearby](https://github.com/google/nearby)
- **Observed Workflow:**
  1. Advertiser broadcasts BLE service UUID with encrypted ephemeral identifier; discoverer scans BLE.
  2. BLE exchange triggers high-bandwidth radio upgrade negotiation: Wi-Fi Direct (P2P Group Owner / Client), Wi-Fi Aware (NAN), or Local Hotspot.
  3. Devices perform cryptographic handshake using UKEY2 (derived symmetric key + 4-digit numeric authentication verification).
  4. User accepts transfer on receiver notification or bottom sheet.
  5. Payload transfer executed using chunked ByteStreams with automatic reconnect/retry across radio disconnects.
- **Underlying Architectural Pattern:**
  - Layered Transport Abstraction: Separation of Discovery Medium (BLE/mDNS) from Transfer Medium (Wi-Fi Direct/Hotspot/LAN).
  - Dynamic Medium Upgrade: Initial low-power discovery automatically triggers high-bandwidth connection without user intervention.
- **Advantages & Limitations:**
  - *Advantages:* Zero user configuration required (no IP addresses, no manual Wi-Fi joining); seamless bypass of router AP isolation via Wi-Fi Direct / Hotspot.
  - *Limitations:* Heavily dependent on Google Play Services (GmsCore) proprietary binaries; platform-restricted on AOSP/F-Droid devices; complex radio state machines on older Android chipsets.
- **Security & Privacy Implications:**
  - UKEY2 protocol ensures forward secrecy and mutual authentication with numeric comparison.
  - Ephemeral BLE rotating IDs protect against physical location tracking.
- **PeerLink Evaluation & Decisions:**
  - **ADAPT (Transport Abstraction & Automatic Radio Upgrades):** Retain and adapt PeerLink's `TransportProvider` and `DiscoveryAdapter` hierarchy to hide TCP/Wi-Fi Direct/Hotspot details behind a unified `PeerSession` abstraction.
  - **ADAPT (Domain-Separated Verification Numbers):** Quick Share's 4-digit UKEY2 number corresponds to PeerLink's 6-digit `computeSessionAuthCode` and 30-digit `computeSafetyNumber`. PeerLink exposes these transparently.
  - **REJECT (Mandatory Google Play Services / Proprietary Blobs):** PeerLink must remain 100% open-source, runnable on pure AOSP, emulators, and GmsCore-free environments.
- **Licensing:** Apache 2.0 (Nearby Core). Cleanroom conceptual adaptation.

---

### Reference C — Syncthing
- **Sources & Evidence:**
  - BEP v1 Protocol Spec: [https://docs.syncthing.net/specs/bep-v1.html](https://docs.syncthing.net/specs/bep-v1.html)
  - Syncthing Core Source: [https://github.com/syncthing/syncthing](https://github.com/syncthing/syncthing)
- **Observed Workflow:**
  1. Peers exchange device IDs (SHA-256 fingerprint of TLS certificate).
  2. Index exchange (`Index` and `IndexUpdate` messages) transfers file metadata: path, size, modification time, permissions, and sequence of 128 KiB chunk SHA-256 hashes.
  3. Pull-based file transfer: Receiver inspects local blocks, identifies missing or altered blocks, and sends targeted `Request` messages (offset + length + hash) across available connected peers.
  4. Concurrent block downloading with backpressure and block verification upon receipt.
  5. File assembly into temp file (`.syncthing.<filename>.tmp`), verified against master hash, then atomically renamed.
  6. Conflicts detected via vector clocks (`Vector` containing `{DeviceID: Sequence}`); divergent versions written to `<filename>.sync-conflict-<date>-<time>-<id>.<ext>`.
- **Underlying Architectural Pattern:**
  - Block-level content-addressable storage + Causal version vectors for multi-master synchronization.
- **Advantages & Limitations:**
  - *Advantages:* Exceptional bandwidth efficiency on mutated files (only changed 128 KiB blocks transmitted); highly robust against partial transfer interruptions; native conflict preservation.
  - *Limitations:* High CPU and storage I/O overhead on mobile devices due to continuous block hashing and SQLite index maintenance; complex state machine unsuitable for simple one-off SEND.
- **Security & Privacy Implications:**
  - Strict TLS certificate pinning based on Device ID prevents rogue eavesdropping.
  - Relay servers only see encrypted TLS streams (BEP over TLS).
- **PeerLink Evaluation & Decisions:**
  - **ADAPT for SYNC Mode (Block Hashing & Causal Vectors):** Adopt 256 KiB / 1 MiB chunk hashes and vector clock causal tracking (`CausalVersion.java`) for continuous Space synchronization (Phase 10).
  - **ADAPT for SEND Mode (Chunk-Level Integrity & Resumption):** Use chunk hash verification in `TransferSessionReceiver.java` to resume partial transfers without restarting whole files.
  - **REJECT (Heavy Continuous Background Block Scanning for One-off SEND):** Ordinary SEND must not invoke file block indexing overhead.
- **Licensing:** MPL 2.0. Cleanroom protocol design.

---

### Reference D — KDE Connect
- **Sources & Evidence:**
  - KDE Connect Android: [https://github.com/KDE/kdeconnect-android](https://github.com/KDE/kdeconnect-android)
  - Architecture Documentation: [https://invent.kde.org/network/kdeconnect-kde](https://invent.kde.org/network/kdeconnect-kde)
- **Observed Workflow:**
  1. Broadcast UDP packets on port `1716` containing device ID, device name, protocol version, and incoming TCP port.
  2. TCP socket established on port 1716 over TLS using self-signed RSA-2048/4096 certificates.
  3. First connection initiates Pairing state: User must explicitly approve pairing on both sides. Once approved, certificates are permanently stored in device trust store.
  4. Communication is structured into modular JSON packet types (`kdeconnect.share.request`, `kdeconnect.telephony`, `kdeconnect.clipboard`).
  5. File sharing sends metadata payload, followed by dedicated TCP socket stream for payload bytes with socket transfer progress listener.
- **Underlying Architectural Pattern:**
  - Long-term bilateral pairing store with granular capability-based plugin routing.
- **Advantages & Limitations:**
  - *Advantages:* True persistent trust (pair once, share forever); clean separation between identity verification and individual capability permissions; dependable desktop-mobile interoperability.
  - *Limitations:* UDP broadcast fails on corporate networks; TLS setup requires manual key generation and certificate management; UI can become complex with too many disparate plugins.
- **Security & Privacy Implications:**
  - Trusted devices can execute granted plugins without repeated prompts; revocation must be instantaneous and absolute.
- **PeerLink Evaluation & Decisions:**
  - **ADOPT (Long-Term Device Trust Store & Revocation):** Retain `DeviceTrustService` with persistent trusted peer records, public-key pinning, safety number verification, and instant one-tap revocation.
  - **ADAPT (Plugin/Capability Isolation):** Enforce strict scoping between SEND, ACCESS, SYNC, and BACKUP operations so device trust does not grant blanket filesystem access.
- **Licensing:** GPLv2 / GPLv3. Cleanroom conceptual adaptation.

---

### Reference E — PairDrop
- **Sources & Evidence:**
  - Technical Documentation: [https://github.com/schlagmichdoch/PairDrop/blob/master/docs/technical-documentation.md](https://github.com/schlagmichdoch/PairDrop/blob/master/docs/technical-documentation.md)
  - WebRTC DataChannel Implementation: [https://github.com/schlagmichdoch/PairDrop](https://github.com/schlagmichdoch/PairDrop)
- **Observed Workflow:**
  1. Clients connect via WebSocket to a signaling server (e.g. running on Node.js/Docker).
  2. Signaling server groups clients sharing the same public IP (NAT) or matching a 6-digit room code / paired secret.
  3. Clients exchange SDP offers/answers and ICE candidates (host, srflx from STUN, relay from TURN) via the signaling channel.
  4. WebRTC `RTCDataChannel` established directly between browsers.
  5. Files read via JavaScript `FileReader`, sliced into 64 KiB chunks, and buffered into `RTCDataChannel` using `bufferedAmount` backpressure.
  6. If direct P2P fails due to symmetric NAT, WebRTC automatically routes encrypted packets through TURN relay.
- **Underlying Architectural Pattern:**
  - Signaling Channel separated from Bulk Payload Transport.
  - ICE / STUN / TURN NAT traversal with transparent direct-to-relay fallback.
- **Advantages & Limitations:**
  - *Advantages:* Works across different networks and NATs without port forwarding; zero install on desktop (browser-accessible); TURN fallback ensures ~99% connectivity.
  - *Limitations:* WebRTC stack is heavy (native WebSockets/ICE needed on Android); signaling server is a point of coordination failure; public TURN relays consume high server bandwidth.
- **Security & Privacy Implications:**
  - WebRTC uses DTLS-SRTP: End-to-end encrypted; TURN server cannot read payload data.
  - Signaling server learns client IP addresses and metadata unless end-to-end encrypted signaling envelopes are used.
- **PeerLink Evaluation & Decisions:**
  - **ADAPT for Remote Sharing (Phase 9):** Implement direct-first remote connection with signaling separation: use short-lived rendezvous signaling (over secure WebSocket/RPC), attempt direct TCP/UDP punch, and fall back to encrypted relay transit only when direct route fails.
  - **ADAPT (Backpressure-Driven Chunk Streaming):** Adopt bounded-buffer backpressure monitoring to prevent Out-Of-Memory (OOM) during high-speed transfers.
  - **REJECT (Browser-only WebRTC as Core Android Transport):** Native Android TCP/QUIC sockets are significantly more efficient, lighter, and more maintainable than bundling full WebRTC libraries.
- **Licensing:** GPLv3. Cleanroom conceptual adaptation.

---

### Reference F — Magic Wormhole
- **Sources & Evidence:**
  - Transit Protocol Specification: [https://github.com/magic-wormhole/magic-wormhole-protocols/blob/main/transit.md](https://github.com/magic-wormhole/magic-wormhole-protocols/blob/main/transit.md)
  - Magic Wormhole Repository: [https://github.com/magic-wormhole/magic-wormhole](https://github.com/magic-wormhole/magic-wormhole)
- **Observed Workflow:**
  1. Sender generates human-memorable code phrase: `<mailbox-number>-<word>-<word>` (e.g., `7-guitarist-revenge`).
  2. Sender and receiver connect to Mailbox Server and open the shared mailbox channel.
  3. Peers execute SPAKE2 Password-Authenticated Key Exchange (PAKE) using the code phrase as the password, establishing a high-entropy symmetric session key without transmitting the password.
  4. Peers exchange connection hints: local LAN IPs, public WAN IP, and transit relay endpoints.
  5. Both peers attempt simultaneous direct TCP connections to each other's hints; simultaneously connect to the Transit Relay.
  6. First direct socket to complete handshake wins; if all direct connections fail or timeout (typically 5 seconds), connection switches seamlessly to Transit Relay.
  7. Data streamed over transit connection encrypted with HKDF-derived keys using NaCl SecretBox.
- **Underlying Architectural Pattern:**
  - Rendezvous signaling + PAKE authenticated key exchange + Direct-First / Relay-Fallback Transit Socket.
- **Advantages & Limitations:**
  - *Advantages:* Unrivaled ease of pairing across networks (short 3-word code); zero pre-shared keys or certificates needed; guarantees confidentiality even if mailbox server is malicious.
  - *Limitations:* Mailbox rendezvous server required; direct connection requires TCP simultaneous open or compatible NATs; relay required for double-NAT.
- **Security & Privacy Implications:**
  - PAKE prevents offline dictionary attacks.
  - Forward-secure session keys derived per transfer session.
- **PeerLink Evaluation & Decisions:**
  - **ADOPT (Direct-First Connection Race with Transit Relay Fallback):** For cross-network sharing (Phase 9), race direct IP/port hints against relay fallback with bounded timeout.
  - **ADAPT (Session Auth Code Pairing):** Adapt the ephemeral code concept for QR invitations and short-lived manual pairing codes (`SESSION_AUTH_DOMAIN_V1`).
- **Licensing:** MIT License. Cleanroom design.

---

### Reference G — Resilio Sync
- **Sources & Evidence:**
  - Selective Sync Documentation: [https://help.resilio.com/hc/en-us/articles/205458095-Selective-Sync](https://help.resilio.com/hc/en-us/articles/205458095-Selective-Sync)
  - Synchronization Modes: [https://help.resilio.com/hc/en-us/articles/205457775-Synchronization-Modes](https://help.resilio.com/hc/en-us/articles/205457775-Synchronization-Modes)
- **Observed Workflow:**
  1. Folders are shared using 33-character cryptographic keys (Read-Write secret, Read-Only secret, or Encrypted secret).
  2. Mobile clients default to Selective Sync: Directory structure and file metadata are replicated immediately, but file contents are represented by zero-byte placeholder files (`.rsls`).
  3. When the user taps a placeholder or requests a file, the client requests blocks on-demand over BitTorrent P2P protocol.
  4. Once downloaded, the placeholder is converted to a regular file. Files can be evicted back to placeholder to save space.
- **Underlying Architectural Pattern:**
  - Metadata-first directory replication + On-demand sparse block materialization (Selective Sync).
- **Advantages & Limitations:**
  - *Advantages:* Solves mobile storage limitations; users can navigate terabyte workspaces on phones with 64 GB storage.
  - *Limitations:* Proprietary protocol; placeholder file systems require deep OS virtual filesystem hooks (FUSE / SAF DocumentsProvider) which are fragile on modern Android.
- **Security & Privacy Implications:**
  - Encrypted secret allows backing up to untrusted cloud nodes/NAS without disclosing plaintext.
- **PeerLink Evaluation & Decisions:**
  - **ADAPT for SYNC Mode (Selective Sync & Metadata Placeholders):** Adopt selective sync metadata-only mode for Spaces on Android, allowing users to view file lists and download on demand without consuming full device storage (Phase 10).
  - **REJECT (Proprietary BitTorrent DHT Tracking):** PeerLink uses local discovery and authenticated direct/relay channels rather than public DHT swarms.
- **Licensing:** Proprietary. Reverse-engineered from public documentation.

---

### Reference H — WhatsApp & Telegram
- **Sources & Evidence:**
  - Consumer Application Interaction Analysis (Android 14/15/16/17):
    - Recipient-first workflow vs File-first workflow.
    - Inline circular progress indicators with dynamic transfer speed (KiB/s, MiB/s) and estimated time remaining (ETA).
    - Multi-file staging with thumbnail previews before transmission.
    - Clear, human-centric state indicators: Queued -> Sending -> Sent -> Delivered -> Read / Saved.
- **Observed Workflow:**
  1. Recipient is selected first from recent/active contacts, OR file is shared from gallery via system Share Sheet (`ACTION_SEND`).
  2. Selected media is queued in an inline bubble or transfer drawer.
  3. Zero networking terminology is displayed: No IP addresses, subnet masks, port numbers, socket errors, or protocol abbreviations.
  4. Network interruptions trigger subtle status changes ("Waiting for Wi-Fi", "Retrying...", "Paused") with an explicit manual Retry button.
- **Underlying Architectural Pattern:**
  - Intent-driven user workflows with layered technical progressive disclosure: surface states are entirely non-technical; technical diagnostics are tucked into details or logs.
- **Advantages & Limitations:**
  - *Advantages:* High usability for non-technical users; eliminates fear and confusion; resilient error states.
  - *Limitations:* Hides underlying topology, which can make debugging difficult when direct P2P connections fail.
- **Security & Privacy Implications:**
  - Consumer familiarity with status ticks and progress rings.
- **PeerLink Evaluation & Decisions:**
  - **ADOPT (Dual Entry Flow: File-First & Recipient-First):** Support both opening PeerLink -> selecting peer -> choosing files, AND system Share Sheet -> opening PeerLink with preselected files.
  - **ADOPT (Jargon-Free UI Surfaces with Technical Diagnostics Drawer):** Keep the Home screen and Send flow free of socket/IP details. Provide a dedicated Technical Diagnostics Sheet for network engineers and power users.
  - **ADOPT (Real Progress Feedback):** Replace all simulated delays with measured byte throughput, ETA, and cancellation triggers.

---

## 3. Comprehensive Competitor Reverse-Engineering Matrix

| Dimension | PeerLink (Target) | LocalSend | Quick Share (Nearby) | Syncthing | KDE Connect | PairDrop | Magic Wormhole | Resilio Sync |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Primary Discovery** | NSD (mDNS) + Wi-Fi Direct + BLE | Multicast UDP + IP Sweep | BLE Scanning + mDNS | Global Announce + Local Broadcast | UDP Broadcast (Port 1716) | WebSocket Signaling Server | Mailbox Server (Rendezvous) | Local Broadcast + Tracker / DHT |
| **AP Isolation Bypass** | Wi-Fi Direct / Local Hotspot | Subnet IP Sweep (Partial) | Wi-Fi Direct / Hotspot | Relay servers (public) | None (LAN only) | TURN Relay | Transit Relay | Relay / Tracker |
| **Transport Protocol** | TLS over TCP / QUIC | TLS over HTTP/1.1-2 | Wi-Fi Direct TCP / BLE | TLS over TCP / KCP | TLS over TCP (1716) | WebRTC DataChannels | TLS / TCP Sockets | uTP / TCP (BitTorrent) |
| **Identity & Trust** | Ed25519 Keypair + AndroidKeyStore | Self-signed TLS Cert Fingerprint | UKEY2 + Google Account / Device ID | TLS Cert SHA-256 Fingerprint | RSA Keypair (Pairing Dialog) | Ephemeral Room Code / Pair Secret | SPAKE2 PAKE Code Phrase | Cryptographic Secrets (RW/RO) |
| **Authentication Flow** | 3-Way Cryptographic Handshake | HTTP Preflight Accept/Reject | Numeric comparison + OS Prompt | Pre-shared Device ID whitelist | Mutual user approval dialog | In-browser prompt | Shared code input | Key possession |
| **Transfer Model** | Chunked SHA-256 Stream + Atomic Commit | Streamed HTTP POST to temp file | Chunked ByteStream via P2P socket | Pull-based 128 KiB Block Requests | Streamed TCP payload socket | Sliced ArrayBuffer over DataChannel | Encrypted stream via Transit Socket | Block-level BitTorrent piece requests |
| **Interruption Recovery** | SQLite Journal + 5-State Resumption | Manual re-send (no block resume) | Automatic retry on socket reconnect | Resumes missing blocks via index | Basic restart from beginning | Reconnects DataChannel if possible | Manual re-connection | Resumes missing pieces |
| **Cross-Network (WAN)** | Direct-first + Relay fallback | None (LAN only) | Google Account signaling + Relay | Syncthing Relays | None (Requires VPN) | STUN / TURN Relay | Transit Relay | Relays + BitTorrent Tracker |
| **Sync Semantics** | Causal Vector Clocks + Conflict Tombstones | None (SEND only) | None (SEND only) | Vector Clocks + Conflict files | None (SEND only) | None (SEND only) | None (SEND only) | Vector Clocks + Conflict resolution |
| **Mobile Background** | Foreground Service + WorkManager | Foreground Service (Android) | OS System Service | Android Foreground Service | Android Foreground Service | Background Tab (Browser throttled) | CLI / Process bound | Android Service + WakeLock |
| **Licensing / Stack** | Cleanroom Flutter + Kotlin/Java | MIT / Flutter | Proprietary + Apache 2.0 Nearby | MPL 2.0 / Go | GPLv2/3 / C++ & Kotlin | GPLv3 / Node + Web | MIT / Python & Rust | Proprietary / C++ |

---

## 4. Architectural Synthesis & Implementation Directives for PeerLink

Based on this audit, the following actionable architectural principles are locked in for the implementation phases:

1. **Zero-Configuration Startup (Phase 1 & 2):**
   - Automatically initialize local node, load persistent Ed25519 identity from AndroidKeyStore, bind active TCP listener to ephemeral OS port, and start NSD adapter without asking user for IP or port configuration.
2. **Multi-Adapter Discovery with AP Isolation Fallback (Phase 4):**
   - NSD/mDNS is the default discovery mechanism.
   - If AP isolation blocks mDNS, provide seamless fallback to Wi-Fi Direct and Direct Hotspot.
   - Deduplicate peers discovered across multiple adapters by matching their canonical Ed25519 `PeerId`.
3. **Genuine QR Pairing (Phase 3):**
   - Replace `_SimulatedQrPainter` and hardcoded `"peer-scanned-01"` with production QR encoding (`qr_flutter`) and real CameraX scanning (`mobile_scanner`).
   - Format QR payloads as versioned JSON: `{"v":1,"peerId":"...","name":"...","fp":"...","ep":["192.168.1.50:52001"],"exp":1700000000,"nonce":"..."}`.
   - Validate expiry, require explicit confirmation, and bind identity to Ed25519 public key.
4. **Metadata-First Two-Phase Transfer with Receiver Consent (Phase 5):**
   - Sender submits metadata manifest before transferring payload bytes.
   - Receiver evaluates trust policy: Auto-accept for trusted peers; prompt interactive consent bottom sheet for unknown peers.
   - Stream data in bounded 64 KiB chunks with backpressure; verify each chunk with SHA-256.
5. **Durable SQLite Journaling & Resumption (Phase 6):**
   - Every transfer creates an atomic SQLite journal entry.
   - On crash or connection drop, valid staged `.part` chunks are preserved and reused on resumption; corrupted chunks are quarantined to `.corrupt`.
6. **Jargon-Free UI with Technical Observability (Phase 8):**
   - Home screen displays truthful readiness, discovered peer avatars, and one-tap send/receive.
   - Diagnostics view exposes technical transport details, socket ports, active listeners, and cryptographic security levels with sensitive secrets redacted.
7. **Direct-First WAN Route (Phase 9):**
   - Separate signaling from payload transfer; attempt direct connection hints before falling back to encrypted relay transport.

---
*End of Competitive Reverse-Engineering Matrix.*
