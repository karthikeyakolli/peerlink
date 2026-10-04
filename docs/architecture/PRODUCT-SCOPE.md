# PeerLink — Frozen Product Scope

## Primary intents

- SEND: one-time copy.
- ACCESS: authorized on-demand remote use.
- SYNC: convergent replicas.
- BACKUP: versioned historical preservation.
- CONNECT: trusted-device relationship underneath the intents.

## Networking

- LAN and local-network connectivity.
- Internet P2P.
- discovery.
- QR/manual pairing.
- NAT traversal.
- direct path selection.
- relay fallback through TURN.
- reconnection/network handoff.
- direct-only policy.
- per-transfer relay policy.
- connection diagnostics/topology.
- optional opt-in peer relay with resource controls.

## Transfers

- files and folders.
- large-file streaming.
- chunking and parallelism.
- pause/resume/cancel/retry.
- crash and restart recovery.
- offline queue/scheduling.
- integrity verification.
- SHA-256 and optional chunk hashes.
- delta/block reuse.
- duplicate/replacement policies.
- transfer receipts.
- deterministic transfer outcome states.

## Access/search

- remote browsing.
- remote metadata.
- authorized remote search.
- remote download.
- safe preview/streaming pipelines.
- result/time/depth limits.
- path traversal and symlink escape protection.
- who-has-this-file using minimal authorized presence information.

## Sync/backup

- bidirectional sync.
- one-way replication.
- versioned backup.
- receive-only import.
- explicit destructive Exact Mirror.
- causal versioning.
- tombstones.
- conflict preservation/resolution.
- selective sync.
- ignore rules.
- ransomware/mass-change pause/safety.
- sync dry run/change preview.
- backup retention/GC.
- restore creates a new version.

## Sharing/workspaces

- peer-specific shares.
- temporary/one-time/expiring/revocable shares.
- opaque capability links/QR.
- guest web capability as optional, scoped feature.
- shared workspaces with owner/admin/editor/contributor/viewer/observer roles.
- membership lifecycle and signed policy epochs.

## Clipboard

- text.
- URLs.
- supported images.
- opt-in modes.
- size/retention/sensitivity limits.
- loop prevention and origin metadata.

## Compatibility/intelligence

- extension/MIME/magic-byte inspection.
- metadata and embedded media metadata.
- OS/CPU/filesystem/path capability analysis.
- application/file association checks.
- compatibility categories: transfer/storage/open/application/execution/metadata.
- verdicts: COMPATIBLE/PARTIALLY_COMPATIBLE/INCOMPATIBLE/UNKNOWN/REQUIRES_USER_DECISION.
- no silent conversion, rename, deletion or execution.

## Security

- cryptographic device identity.
- secure pairing/fingerprint verification.
- trust and authorization separation.
- revocation.
- secure key storage.
- E2E protected peer sessions.
- resource-exhaustion defenses.
- replay protection.
- malformed input handling.
- path traversal/symlink/archive protection.
- data sensitivity classification.
- malware scanning through provider adapters.
- quarantine.
- privacy metadata inspection.
- relay/AI restrictions by sensitivity.

## AI

- natural-language file search.
- Smart Share.
- Smart Bundles.
- Transfer Recipes.
- Smart Drop Zones.
- Send Later/Send Again.
- diagnostics assistant.
- compatibility explanation.
- sync assistant.
- smart organization.
- AI Gateway/provider abstraction.
- AI proposal -> deterministic policy/validation -> operation.

## Reliability/operations

- operation journal.
- idempotency.
- unknown outcomes.
- filesystem/DB reconciliation.
- crash/power-loss recovery.
- temp/version/tombstone GC.
- signed updates.
- schema compatibility/migration dry-run.
- rollback.
- diagnostics bundles.
- emergency stop.

## UX

Top-level navigation:

- Home
- Devices
- Files
- Activity
- Spaces
- Search
- Settings

Files contains SEND/ACCESS/SYNC/BACKUP.

Activity contains Active/Problems/History.

Settings contains Trust/Privacy/Network/Storage/AI/Advanced.

## Explicit exclusions

- remote desktop.
- remote shell.
- arbitrary remote process execution.
- full VPN/overlay replacement.
- social/chat platform.
- centralized cloud file storage.
- full antivirus replacement.
- autonomous AI computer control.
- hidden surveillance/network scanning.
