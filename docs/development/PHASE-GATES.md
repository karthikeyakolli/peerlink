# PeerLink — Phase Gate Rules

A phase cannot be considered complete merely because its code exists.

## Gate format

Every phase must have:

```text
INPUTS
  ↓
IMPLEMENTATION
  ↓
UNIT / COMPONENT TESTS
  ↓
INTEGRATION SCENARIO
  ↓
FAILURE SCENARIO
  ↓
EVIDENCE
  ↓
HUMAN REVIEW
  ↓
COMMIT
```

## Gate levels

### Gate A — Build

- source compiles
- generated code is reproducible
- no unexpected dependency conflicts

### Gate B — Automated correctness

- applicable unit/component tests pass
- important negative cases exist

### Gate C — Runtime

- real application starts
- acceptance scenario succeeds

### Gate D — Recovery

For stateful/network features:

- restart
- crash
- disconnect
- cancellation
- retry

must be tested as applicable.

### Gate E — Security

- authorization
- malformed input
- resource limits
- secret handling
- trust boundaries

must be reviewed for applicable features.

### Gate F — Cross-platform

When a feature touches platform APIs:

- platform capability declared
- at least one real target tested
- unsupported behavior is explicit

### Gate G — Release hygiene

- focused diff
- docs updated
- verification record stored
- no debug credentials/data
- ADR created if architecture changed

## Stop-the-line conditions

Stop the phase immediately if:

- data loss is observed
- authorization can be bypassed
- cryptographic trust can be bypassed
- operation outcome can be incorrectly marked as committed
- a destructive operation can be blindly replayed
- protocol peers disagree on message meaning
- a platform implementation silently corrupts metadata/data
