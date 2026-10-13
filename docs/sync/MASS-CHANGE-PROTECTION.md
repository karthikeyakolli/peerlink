# Mass-Change Protection

Detects suspicious burst changes and pauses sync pending user/policy decision.

## Default Thresholds

| Pattern | Threshold |
|---|---|
| Mass deletion | >= 50 deletions per scan |
| Burst changes | >= 200 total changes per scan |
| Extension mass-change | >= 50% of objects with suspicious extensions |

## On Trigger

1. Session enters PAUSED state.
2. Reason(s) recorded.
3. Versions preserved — nothing written or deleted.
4. User or policy must approve before sync resumes.

## What Does NOT Trigger Protection

- Large remote catch-ups (remote new files not counted as local burst).
- Explicitly pre-approved bulk operations.

---

## Explicit Confirmation Modes (`MassChangePolicy`)

1. **`REQUIRE_EXPLICIT_CONFIRMATION` (Default)**:
   - Sync session enters `PAUSED` phase.
   - Requires explicit `session.approveMassChange()` to resume reconciliation.
   - If rejected via `session.rejectMassChange(reason)`, the session transitions to `FAILED` with no destructive changes applied.
2. **`FAIL_CLOSED`**:
   - Immediately aborts the sync session upon threshold breach, refusing to process changes.
3. **`AUTO_APPROVE`**:
   - Permits burst operations without pause (used for automated migrations or verified batch jobs).