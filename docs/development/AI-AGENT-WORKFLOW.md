# PeerLink — AI/Antigravity Development Workflow

## 1. Operating model

Use AI as an implementation accelerator, not as the authority on correctness.

```text
Specification
 -> AI plan
 -> Human review
 -> Implementation
 -> Build
 -> Automated tests
 -> Real runtime test
 -> Fault test
 -> AI/self-review
 -> Human review
 -> Commit
```

## 2. Every AI task must contain

- objective
- in-scope files/modules
- out-of-scope areas
- contract references
- acceptance criteria
- required tests
- verification commands
- security considerations

## 3. Preferred task size

One vertical slice or one tightly related subsystem.

Bad:

> Build PeerLink completely.

Good:

> Implement Phase 5 SEND v1 using the existing operation and transfer contracts. Add a two-node test for a 100 MB file, SHA-256 verification and atomic commit. Do not modify sync, backup or Android modules.

## 4. AI completion contract

The agent must not mark work complete until it has:

1. compiled
2. run automated tests
3. launched the relevant runtime
4. executed the acceptance scenario
5. inspected logs/results
6. checked the diff for unrelated changes
7. reported failures/limitations

## 5. Separate AI roles

### Architect

Checks contracts and module boundaries.

### Implementation Agent

Writes code only for the approved scope.

### Test Agent

Attempts to break the implementation.

### Security Agent

Checks trust, authorization, path safety, resource exhaustion, replay, malicious input and scanner policy.

### Review Agent

Checks the implementation against the specification and ADRs.

These roles can be implemented as separate Antigravity conversations/subagents.

## 6. Permission discipline

Normal workspace commands can be automated.

Human approval is expected for:

- production deployment
- destructive database commands
- bulk filesystem deletion
- credential/key changes
- firewall changes
- certificate/signing operations
- release signing

## 7. Git workflow

Before feature:

```text
clean baseline commit
```

After verified feature:

```text
implementation commit
verification evidence
```

Avoid huge mixed commits.

## 8. Verification artifact

For significant features create:

```text
verification/<feature-id>/
├── test-results.md
├── logs/
├── screenshots/
└── known-limitations.md
```

## 9. AI-specific safety rules

- AI never writes directly to production secrets.
- AI never invents APIs when a repository contract exists.
- AI must inspect current code before changing it.
- AI must not silently redesign architecture.
- AI must not treat passing unit tests as proof of cross-platform correctness.
- AI-generated security code requires tests and review against the security contract.

## 10. Developer loop

```text
Open task
  ↓
Read relevant docs
  ↓
Ask Antigravity to plan
  ↓
Review plan
  ↓
Implement
  ↓
Run checks
  ↓
Run application
  ↓
Test failure cases
  ↓
Inspect evidence
  ↓
Commit
```
