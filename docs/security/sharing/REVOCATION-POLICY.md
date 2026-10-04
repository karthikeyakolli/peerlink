# Share Revocation Policy

## What Revocation Does

- **Immediately blocks** all new access authorizations.
- Broadcasts a `ShareRevocationNotice` to known holders (best-effort).
- Records the revocation reason and timestamp in the audit journal.

## What Revocation Cannot Do

- **Cannot erase** already-downloaded copies from the recipient's device.
- Cannot retroactively invalidate bytes already transferred.
- Cannot remove data from recipient's filesystem.

This is by design: PeerLink is a peer-to-peer transfer system, not a DRM platform.
Revocation is a capability gate, not a content control system.

## Grace Period

If an active, already-authorized operation is in progress at revocation time:

```
revoke(operationStartedAtUtcMs = T)
    → grace window = [T, T + gracePeriodMs]
    → active operation may complete if now <= T + gracePeriodMs
    → new operations always blocked immediately
```

Grace is measured from the **operation start time**, not from the revocation time.
This is intentional: the operation was authorized while the share was valid.

## Owner Offline During Revocation

If the owner device is offline, revocation cannot be communicated to holders in real time.
Outstanding tokens remain technically valid until they expire or the owner reconnects.
For time-critical revocations, use short-lived tokens with low expiresAtUtcMs.