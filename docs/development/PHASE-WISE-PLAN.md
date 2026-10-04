# PeerLink — Phase-Wise Build Plan

## Planning principle

Build **vertical slices**, not isolated piles of classes. Every phase must produce something executable and testable.

A phase is complete only when its exit gate is satisfied.

---

## Phase 0 — Repository and engineering foundation

### Goal
Create a clean monorepo and reproducible build environment.

### Deliver

- repository structure
- Flutter application shell
- Java core/local-node skeleton
- protocol module
- Supabase project configuration
- test harness skeleton
- CI skeleton
- coding standards
- ADR process

### Verification gate

- clean clone builds
- Flutter starts
- Java tests run
- generated Protobuf code builds
- basic CI pipeline passes

---

## Phase 1 — Cross-platform contract foundation

### Goal
Define the APIs before feature implementation.

### Deliver

- `proto/` contracts
- versioning rules
- capability model
- operation/error model
- platform interfaces
- Flutter ↔ desktop Local Node gRPC contract
- Flutter ↔ Android Pigeon contract

### Verification gate

- Java and Dart generated code builds from the same `.proto`
- contract compatibility tests pass
- no platform-specific implementation leaks into protocol/domain contracts

---

## Phase 2 — Flutter ↔ Java Local Node proof

### Goal
Prove the unusual part of the architecture before building features on top.

### Deliver

- separate Java Local Node process
- authenticated localhost IPC
- gRPC streaming
- lifecycle handling
- node start/stop/restart
- Flutter event subscription

### Verification gate

```text
Flutter → Java Node → response/event → Flutter
```

and:

- Node crash → restart → UI reconnects
- unauthorized local IPC attempt → rejected

---

## Phase 3 — Identity, pairing and trust

### Goal
Create cryptographic device identity and secure pairing.

### Deliver

- Ed25519 device identity
- stable Peer ID
- fingerprint display
- pairing flow
- trust store
- revocation
- local key lifecycle and trust store
- account-to-device binding contract placeholder (cloud binding is completed in Phase 7)

### Verification gate

- unknown peer cannot become trusted through discovery alone
- fingerprint mismatch is blocked
- revocation prevents new authorized work
- key material is not stored as plaintext

---

## Phase 4 — Local P2P connectivity

### Goal
Connect two nodes without cloud file transfer.

### Deliver

- discovery provider abstraction
- manual/QR pairing path
- session protocol
- transport abstraction
- first direct transport
- TCP/TLS path
- initial QUIC path on desktop

### Verification gate

Two local nodes establish an authenticated session and exchange a protocol message.

---

## Phase 5 — SEND v1

### Goal
Deliver the smallest complete file-transfer vertical slice.

### Deliver

- file/folder selection
- preflight
- chunked transfer
- progress
- SHA-256 verification
- temporary staging
- atomic commit
- Reveal in Folder

### Verification gate

Windows Node A → Windows Node B:

- small file
- empty file
- folder
- large file
- duplicate name handling
- hash match

---

## Phase 6 — Transfer reliability + recovery + safety

### Goal
Make SEND trustworthy.

### Deliver

- pause/resume
- operation journal
- retry
- crash recovery
- `OUTCOME_UNKNOWN`
- disk-space preflight
- source mutation detection
- replacement policy
- batch transaction semantics
- resource limits
- transfer receipts

### Verification gate

- kill sender during transfer
- kill receiver during transfer
- lose ACK after remote commit
- disk full
- network disconnect/reconnect
- no destructive blind replay

---

## Phase 7 — Internet connectivity + Supabase control plane

### Goal
Add Internet peer coordination without putting files into Supabase.

### Deliver

- Supabase Auth
- device registry
- presence
- signaling
- session coordination
- ICE abstraction
- TURN/coturn
- path selection
- path migration/hysteresis
- offline control behavior

### Verification gate

- LAN direct transfer
- different-network direct attempt
- relay transfer
- Supabase interruption
- new pairing blocked when control plane unavailable as designed
- existing permitted session behavior matches policy

---

## Phase 8 — ACCESS + remote search + sharing

### Goal
Add authorized on-demand access.

### Deliver

- remote folder browse
- remote metadata
- paginated remote search
- remote download
- preview safety pipeline
- temporary/expiring/one-time shares
- guest capability isolation

### Verification gate

- unauthorized path access blocked
- path traversal blocked
- bounded result/resource limits enforced
- share expiry/revocation behaves correctly

---

## Phase 9 — SYNC

### Goal
Implement convergent synchronization.

### Deliver

- manifests
- change detection
- object continuity
- causal metadata
- delta/block reuse
- tombstones
- conflict preservation
- selective sync
- dry-run/change preview
- mass-change/ransomware safety

### Verification gate

Scenarios:

- A-only change
- B-only change
- same change
- concurrent edits
- concurrent rename/delete
- offline divergence
- reconnection convergence
- watcher event loss followed by reconciliation

---

## Phase 10 — BACKUP + RESTORE

### Goal
Make historical preservation distinct from sync.

### Deliver

- versioned backup
- receive-only default
- retention policy
- protected versions
- backup verification
- restore-to-new-version
- explicit Exact Mirror mode

### Verification gate

- accidental local deletion recovered
- restore does not rewrite history
- backup target cannot unexpectedly mutate source
- historical versions remain discoverable according to policy

---

## Phase 11 — Security scanning + compatibility + privacy safety

### Goal
Treat received/restored data as untrusted until checked.

### Deliver

- quarantine
- scanner provider abstraction
- Windows Defender adapter
- ClamAV adapter where applicable
- archive inspection limits
- executable handling
- file signature/magic-byte checks
- metadata privacy inspection
- compatibility matrix
- scan cache
- rescan policy

### Verification gate

- clean file accepted
- known detection blocked/quarantined when engine reports it
- scanner unavailable follows policy
- malicious archive/resource exhaustion is contained
- executable is never automatically executed

---

## Phase 12 — Shared Spaces + Clipboard + smart operations

### Goal
Complete the collaboration/data-control features.

### Deliver

- workspace roles
- policy epochs
- invitation/removal
- clipboard sync
- Smart Share
- Smart Bundles
- Transfer Recipes
- Smart Drop Zones
- Send Later/Send Again
- operation dependency handling

### Verification gate

- permissions are scoped
- clipboard loops prevented
- revoked members cannot create new authorized operations
- scheduled objects replay against current state, not stale paths

---

## Phase 13 — Android full node

### Goal
Bring Android into the same PeerLink protocol ecosystem.

### Deliver

- Flutter Android app
- Kotlin/Java bridge
- portable Java logic where valid
- Room/SQLite
- Android Keystore
- SAF/ContentResolver/MediaStore integration
- Android discovery adapters
- user-initiated data transfer handling
- WorkManager for suitable deferred tasks
- background capability states

### Verification gate

Minimum matrix:

```text
Windows ↔ Android
Android ↔ Android
```

Validate:

- transfer
- resume
- permissions
- app restart
- background/foreground transitions
- Wi-Fi changes
- battery constraints
- storage access

---

## Phase 14 — OS integrations

### Goal
Make the product native on each desktop OS.

### Deliver

- Windows shell/share/notification integration
- macOS Finder/share/keychain/File Provider adapters where justified
- Linux file-manager/XDG/notification integration
- startup/background behavior
- single-instance logic
- native credential stores

### Verification gate

Each OS must pass an OS integration checklist independently.

---

## Phase 15 — AI Gateway

### Goal
Add useful AI without allowing AI to become an authority.

### Deliver

- provider-neutral AI gateway
- Gemini provider first
- structured action schema
- context minimization
- privacy classification
- action confirmation rules
- audit trail
- cost/rate budget
- prompt-injection isolation

### Verification gate

AI can propose but cannot bypass:

- trust
- authorization
- encryption
- integrity
- deletion policy
- sync truth
- execution policy

---

## Phase 16 — Production hardening

### Goal
Prepare for real-world release.

### Deliver

- self-diagnostics
- watchdog/self-healing
- emergency stop
- update signing
- migration dry run
- rollback
- crash recovery
- database recovery
- performance tuning
- privacy-safe diagnostics
- release signing/notarization

### Verification gate

Full fault-injection, cross-platform and release test suite passes.

---

## Phase 17 — Release candidate

### Goal
Freeze implementation behavior and validate the complete system.

### Deliver

- release builds
- documentation
- installation/uninstallation tests
- migration tests
- backup/restore tests
- threat-model review
- dependency/SBOM inventory
- final protocol compatibility suite

### Final gate

No open P0/P1 correctness or security issues. All declared product capabilities have either a verified implementation or an explicitly documented platform limitation.

---

## Milestones

### M1 — Proof

Phases 0–4: two nodes securely connect.

### M2 — Reliable SEND

Phases 5–6: files transfer, verify, resume and recover.

### M3 — Real Internet P2P

Phase 7: cloud coordination + direct/relay paths.

### M4 — Personal Data Platform

Phases 8–10: ACCESS + SYNC + BACKUP.

### M5 — Safety and Collaboration

Phases 11–12.

### M6 — Cross-platform

Phases 13–14.

### M7 — Intelligence and Release

Phases 15–17.

## Rule for smooth development

Do not start a later phase when an earlier phase has a broken invariant. Later features must consume stable contracts rather than work around known failures.
