# PeerLink — Definition of Done

A feature is done only when all applicable items are true.

## Engineering

- [ ] Specification/contract reference exists.
- [ ] Scope is limited to the approved feature.
- [ ] No architecture drift without ADR.
- [ ] Code compiles.
- [ ] Static/build checks pass.
- [ ] Unit tests pass.
- [ ] Integration tests pass where applicable.

## Runtime

- [ ] Real application starts.
- [ ] Acceptance scenario executed.
- [ ] Logs inspected.
- [ ] Failure path tested.
- [ ] Restart/recovery tested if stateful.

## P2P features

- [ ] Two-node test passes.
- [ ] Disconnect/reconnect tested.
- [ ] Integrity verified.
- [ ] Authorization tested.
- [ ] Resource limits tested.

## Filesystem features

- [ ] Empty file.
- [ ] Large file.
- [ ] Unicode filename.
- [ ] Duplicate destination.
- [ ] Permission failure.
- [ ] Source mutation/disappearance.
- [ ] Disk full where relevant.

## Security

- [ ] Trust boundary reviewed.
- [ ] Input validation reviewed.
- [ ] Path traversal tested.
- [ ] Resource exhaustion tested.
- [ ] Secrets are not logged.
- [ ] Malware-scan policy tested where relevant.

## Cross-platform

- [ ] Platform-specific behavior documented.
- [ ] Capability state is correctly exposed.
- [ ] At least one real device/OS test performed for new platform code.

## AI

- [ ] AI only proposes/assists where intended.
- [ ] Deterministic validation remains authoritative.
- [ ] Prompt injection/context-minimization boundary reviewed.

## Delivery

- [ ] No unrelated files changed.
- [ ] Documentation updated.
- [ ] Verification evidence stored.
- [ ] Git diff reviewed.
- [ ] Commit created with a focused message.
