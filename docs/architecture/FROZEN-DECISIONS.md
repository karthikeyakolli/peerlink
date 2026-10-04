# PeerLink — Frozen Decisions

## Product

- Desktop-first implementation; Android is planned as a full node.
- Product is a P2P personal data platform, not a cloud file-storage application.
- Primary user intents: SEND, ACCESS, SYNC, BACKUP.
- No remote desktop, remote shell, arbitrary remote execution, full VPN replacement, social/chat platform, autonomous PC-control AI, hidden surveillance, or full antivirus product.

## Architecture

- Flutter is the cross-platform application/UI layer.
- Java is the primary PeerLink implementation language on desktop.
- Desktop Local Node is separate from Flutter at the process boundary.
- Android uses Kotlin + Java/native Android APIs around portable PeerLink logic.
- Protocol-first design; platform-specific adapters are expected.
- Supabase is control plane only.
- Files remain on peer-owned storage for normal P2P operations.

## Protocol

- Protocol Buffers is the shared wire/schema contract.
- Protocol versioning and capability negotiation are mandatory.
- Object identity is separate from path and content hash.
- Content version is separate from metadata version.
- Timestamps do not decide sync truth.

## Transport

- Transport is abstracted.
- Desktop may use Netty 4.2 with QUIC as preferred transport where supported.
- TCP/TLS is the universal compatibility path.
- TURN is a relay path, not a security authority.
- Android/future platforms are not required to use Netty.
- Future WebRTC DataChannel is allowed as a transport adapter after validation; it is not the core protocol.

## Local state

- Desktop uses SQLite + WAL.
- Android may use Room over SQLite.
- Actual file bytes are stored outside SQLite.
- Filesystem watchers are hints; reconciliation/scanning remain authoritative.

## Cloud

- Supabase Auth for account identity.
- Supabase Postgres for durable control-plane state.
- Supabase Realtime for ephemeral presence/signaling/notifications, never as the durable operation source of truth.
- Supabase Storage is not the normal PeerLink file plane.
- Edge Functions are used only where server-side trusted logic is actually needed.

## Security

- PeerLink device identity is distinct from Supabase account identity.
- Discovery does not grant trust.
- Local IPC must be authenticated.
- OS key stores are preferred for private-key protection.
- Malware scanning uses provider adapters such as Defender/ClamAV where available.
- Unscanned does not mean safe.
- Executables are never automatically executed.
- AI is non-authoritative.

## Android

- Android is a full node, not merely a remote-control companion.
- Android background behavior is capability/OS constrained.
- User-initiated long transfers use Android-appropriate mechanisms; WorkManager is used for suitable deferrable work.
- Android file access uses SAF/ContentResolver/MediaStore as appropriate.

## Future platforms

- Linux/macOS are architecture-compatible desktop targets.
- iOS/iPadOS are protocol-compatible future clients; shared Java core is not an iOS runtime requirement.

## Change rule

Architecture changes require an ADR and updated contradiction review. Silent drift is prohibited.
