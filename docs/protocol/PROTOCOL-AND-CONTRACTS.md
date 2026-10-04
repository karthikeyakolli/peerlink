# PeerLink — Protocol and Contract Plan

## 1. Contract hierarchy

```text
PeerLink Protocol
├── Identity
├── Pairing
├── Capability
├── Session
├── Operation
├── Object
├── Transfer
├── Sync
├── Backup
├── Share
├── Workspace
├── Clipboard
├── Search
├── Compatibility
├── Security
└── Diagnostics
```

## 2. Protocol rules

- Every protocol surface is versioned.
- Unknown fields must be safely ignored where possible.
- Feature capability negotiation is mandatory for optional features.
- Request IDs and operation IDs must be stable enough for retry/recovery.
- Destructive operations require explicit authorization and idempotency semantics.
- Large data is streamed; never put large file content into ordinary control messages.

## 3. Core identifiers

```text
peer_id
identity_key_id
session_id
connection_id
operation_id
object_id
version_id
content_hash
transfer_id
chunk_id
share_id
workspace_id
trace_id
```

## 4. Operation contract

An operation should contain:

- operation_id
- intent/type
- actor peer/device
- target object(s)
- authorization context
- preconditions
- resource reservation
- current state
- retry/recovery policy
- created/updated timestamps
- outcome/evidence reference

## 5. Transfer contract

A transfer records:

- transfer_id
- operation_id
- object_id
- source/destination peer
- source identity
- destination mapping
- total bytes/files
- chunking parameters
- hash algorithm
- verification state
- resume state
- final commit state

Transfer state:

```text
PREPARING
CONNECTING
TRANSFERRING
RECEIVED
VERIFYING
COMMITTING
COMPLETED
```

Failure/result states include `PARTIAL`, `FAILED`, `CANCELLED`, `RECOVERABLE`, `OUTCOME_UNKNOWN`.

## 6. Capability model

Capabilities should be explicit and have TTL/refresh semantics.

Examples:

```text
FEATURE_TRANSFER_RESUME
FEATURE_REMOTE_SEARCH
FEATURE_CLIPBOARD_IMAGE
FEATURE_BACKGROUND_SYNC
FEATURE_QUIC
FEATURE_TCP_TLS
FEATURE_TURN
FEATURE_MALWARE_SCAN
FEATURE_ARCHIVE_INSPECTION
FEATURE_FILE_PROVIDER
```

Capability says what a client can support. It does not guarantee the current environment permits it.

## 7. Sync contract

Sync state must represent:

- object identity
- version identity
- parent/location
- content hash
- metadata version
- causal version information
- tombstone state
- conflict state

Conflict is determined by causality, not timestamps.

## 8. Share contract

Shares contain:

- share_id
- owner
- subject peer/guest capability
- allowed operations
- scope
- creation time
- expiration
- revocation state
- optional identity binding

Expiry blocks new operations; already-authorized operations may complete only within the bounded policy window.

## 9. Security contract

Security verdicts should be deterministic:

```text
CLEAN
SUSPICIOUS
MALICIOUS
UNKNOWN
SCAN_FAILED
UNAVAILABLE
```

Transport encryption is not the same as file safety scanning.

## 10. Error model

Every error should have:

- stable machine-readable code
- human-readable summary
- retryability
- recovery action
- operation/session context
- optional evidence reference

The UI uses the error model to provide deterministic “Why?” explanations.

## 11. Protocol evolution

- Never reuse field numbers.
- Deprecate before removal.
- Maintain compatibility windows.
- Add capability negotiation before activating optional behavior.
- Add protocol conformance tests for every new message/service.
