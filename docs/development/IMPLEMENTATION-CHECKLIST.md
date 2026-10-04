# PeerLink — Master Implementation Checklist

## Foundation

- [ ] Repository created
- [ ] Flutter toolchain locked
- [ ] Java 25 toolchain locked for desktop
- [ ] Portable core baseline locked
- [ ] Maven wrapper
- [ ] Android/Gradle toolchain
- [ ] CI runners configured
- [ ] Supabase dev project
- [ ] coturn dev environment

## Contracts

- [ ] Protobuf package structure
- [ ] Versioning policy
- [ ] Capability contract
- [ ] Error contract
- [ ] Object model
- [ ] Operation model
- [ ] Transfer contract
- [ ] Sync contract
- [ ] Backup contract
- [ ] Share contract
- [ ] Workspace contract
- [ ] Security contract

## Core

- [ ] Local Node lifecycle
- [ ] Authenticated local IPC
- [ ] Identity
- [ ] Trust
- [ ] Policy
- [ ] Filesystem abstraction
- [ ] SQLite state
- [ ] Operation journal
- [ ] Recovery manager

## Networking

- [ ] Discovery abstraction
- [ ] Session manager
- [ ] TCP/TLS transport
- [ ] QUIC desktop transport
- [x] ICE abstraction (Phase 09 — STUN, TURN, candidate exchange, path selection)
- [x] TURN/coturn (Phase 09 — coturn integration, relay transport, anti-flapping hysteresis)
- [x] Connection migration (Phase 09 — network handoff, path re-evaluation)
- [x] Relay policy (Phase 09 — direct-only policy, relay fallback, diagnostics)

## Data features

- [x] SEND (Phase 06 + 07 — basic send, resumable/fault-tolerant transfer)
- [x] ACCESS (Phase 10 — remote folder browse, search, preview, archive inspect)
- [ ] SYNC
- [ ] BACKUP
- [ ] SHARE
- [ ] WORKSPACES
- [ ] CLIPBOARD

## Safety

- [ ] Quarantine
- [ ] Malware scanner abstraction
- [ ] Defender adapter
- [ ] ClamAV adapter
- [ ] Archive limits
- [ ] Privacy metadata inspection
- [ ] Compatibility analysis
- [ ] No automatic execution

## Android

- [ ] Flutter Android shell
- [ ] Kotlin/Java bridge
- [ ] Keystore
- [ ] SAF integration
- [ ] Background capability model
- [ ] User-initiated transfer
- [ ] WorkManager integration
- [ ] physical-device P2P testing

## Cross-platform OS

- [ ] Windows shell/share integration
- [ ] macOS integration
- [ ] Linux integration
- [ ] native notifications
- [ ] OS credential storage
- [ ] startup/background behavior

## AI

- [ ] AI Gateway
- [ ] Gemini provider
- [ ] structured action schema
- [ ] policy gate
- [ ] context minimization
- [ ] audit
- [ ] cost/rate budget

## Release

- [ ] Signed desktop builds
- [ ] macOS notarization path
- [ ] Android signed bundle
- [ ] migrations
- [ ] rollback
- [ ] backup verification
- [ ] diagnostic bundle
- [ ] SBOM/dependency inventory
- [ ] full release matrix
