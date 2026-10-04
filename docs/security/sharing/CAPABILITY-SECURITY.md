# Sharing Capability Security Model

## Threat Model

| Threat | Mitigation |
|---|---|
| Forged capability token | HMAC-SHA256 signed with share authSecret; constant-time equality check |
| Token replay by wrong peer | boundPeerId field enforced; mismatch → PEER_MISMATCH |
| Guest claiming trusted identity | isGuestToken checked; requesterPeerId must be blank/GUEST |
| Expired token reuse | expiresAtUtcMs validated at every use; time is checked at runtime |
| One-time reuse with different op | operationId bound at issuance; different op → ONE_TIME_CONSUMED |
| Revocation bypass | Revocation checked before any permission evaluation |
| Grace period abuse | Grace measured from operationStartedAtUtcMs, not from now; bounded |
| Permission escalation | Token permissions validated exactly; no implicit inheritance |
| Share not available when owner offline | SHARE_NOT_FOUND returned; no cloud fallback |
| Audit log tampering | In-memory append-only; bounded LRU; cleared only by owner |

## Token Signing

All capability tokens are signed with HMAC-SHA256 using the share's `authSecret`.
The signing payload includes: tokenId, shareId, shareType, sorted permissions,
expiresAt, boundPeerId, isGuestToken, and operationId.

Changing any field after issuance will fail signature verification.

## authSecret Lifecycle

- Generated per share at creation time (UUID-strength minimum).
- Never serialized into the token itself.
- Never transmitted to the remote peer.
- Held only on the owner's device; used to issue and verify tokens locally.
- Revocation invalidates all outstanding tokens implicitly (registry rejects them).

## Guest Isolation

Guest tokens must NOT:
- Carry a trusted peer ID in boundPeerId.
- Be used by a requester claiming a non-GUEST peer identity.
- Grant permissions beyond those explicitly listed in the token.
- Elevate to any trusted-peer privilege path.

PeerLink MUST NOT be converted into a general-purpose cloud drive by guest sharing.
File data is always served from the owner's device, not a central server.