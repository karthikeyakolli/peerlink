# Sharing Architecture

## What a Share Is

A share in PeerLink is a **scoped, time-bounded, owner-controlled capability** — not a cloud file upload.

`
Owner Device  ←─── Share Registry (authoritative)
     │
     │  issues opaque capability token
     ▼
 Holder (peer or guest)
     │
     │  presents token to owner on use
     ▼
Owner Device validates → permits or rejects
`

The owner's device is the **sole authority** for a share. If the owner is offline, the share is unavailable. There is no cloud fallback for file data.

---

## Share Types

| Type | Description |
|---|---|
| PEER_SPECIFIC | Bound to one or more trusted, cryptographically identified peers |
| TEMPORARY | Valid for a finite time window; expires automatically |
| ONE_TIME | Capability consumed after first successful complete operation; retries of same op ID permitted |
| GUEST | Isolated, untrusted; no trusted-identity privileges; no PeerLink account required |
| QR | Opaque capability encoded as a PeerLink URI for QR rendering |

---

## Expiry and Grace Period

`
─────────────────────[expiresAt]────────[operationStart + gracePeriodMs]──────▶
       new ops OK          ↑                         ↑
                    new ops BLOCKED         active op may complete
`

- **Expiry blocks all new operations** immediately at expiresAt.
- An **already-authorized, in-progress operation** may complete within gracePeriodMs measured from its own start time — not from the revocation/expiry time.
- Grace is bounded and configured per share at creation time.

---

## Revocation

- Owner may explicitly revoke at any time.
- Revocation immediately blocks all new operations.
- Active in-progress operations may complete within their remaining grace window.
- **Revocation cannot erase already-downloaded copies** — it is a capability gate only.
- Revocation reason is recorded in the audit journal.

---

## One-Time Share Semantics

`
First use (op_A)  → authorized
Completion        → share marked CONSUMED
Retry (op_A)      → authorized (idempotent — same operation ID)
New use (op_B)    → REJECTED (one-time share already consumed)
`

The operationId binding allows network-interrupted transfers to resume without requiring a new share capability.

---

## Guest Sharing

- Guest tokens are issued without binding to any trusted peer identity.
- Guests are explicitly untrusted; they receive only the permissions listed in the token.
- A guest token cannot be used to claim a trusted PeerLink peer identity.
- Guest sharing does NOT convert PeerLink into a cloud drive — file content is served from the owner's device on demand.

---

## Owner Offline

If the owner's device is offline:
- New capabilities cannot be validated (owner is the authority).
- The share is functionally unavailable.
- There is no cloud relay for file content.
- Active already-authorized operations may continue within grace if the connection persists.

---

## Local Node Enforcement & Zero Implicit Access

1. **No Implicit Filesystem Access**:
   - A previously paired or trusted peer does **not** gain automatic access to all local files.
   - Access to any file or folder requires an active `ShareDefinition` explicitly registering that peer ID or an authenticated capability token.
   - Requests without an active share or valid capability are rejected immediately with `PEER_NOT_ALLOWED` or `TOKEN_INVALID`.

2. **Bounded File Retrieval**:
   - On-demand file reads are strictly bounded by `BoundedFileReader` (default 4 MB, hard ceiling 16 MB) to prevent remote denial-of-service or memory exhaustion.
   - Read buffers compute SHA-256 digests in real time and verify integrity before returning data.

3. **Destination Isolation & Safe Non-Execution**:
   - Content downloaded from remote shares is managed via `SafeDestinationHandler`.
   - Incoming files are written to isolated staging `.part` temporary files, verified against expected SHA-256 digests, atomically moved into position, and have execution permissions explicitly stripped (`setExecutable(false)`).
   - Remote files are **never** auto-executed upon retrieval.

