# PeerLink AI Privacy & Context Minimization Policy

## 1. Principles of AI Privacy

1. **Context Minimization**: Only the minimal necessary metadata is sent to an AI provider.
2. **Local Metadata First**: File indexing, full-text parsing, and token matching occur locally on the Local Node whenever possible.
3. **No Unsolicited File Uploads**: Raw file contents are never transmitted to external cloud LLMs unless explicitly opted into by the user for a specific document analysis.
4. **Zero Diagnostic Contamination**: Normal diagnostic dumps, logs, and system metrics never contain raw prompts, private keys, session tokens, or clipboard contents.

---

## 2. Privacy Classification Levels

Every message or context fragment passed into the AI Gateway is tagged with a `PrivacyLevel`:

### Level 1: `NORMAL`
- Non-identifying operational parameters.
- Example: File extension (`.pdf`), byte size (`14.2 MB`), connection transport type (`DIRECT_QUIC`), transfer speed (`45 MB/s`).
- Permitted to be included in cloud provider prompts.

### Level 2: `SENSITIVE`
- User-identifiable metadata.
- Example: Full file names, directory names, local usernames, peer device names.
- Redacted or stripped using `SanitizedContextFilter` (e.g. `/home/alice/...` → `[REDACTED_USER_PATH]`).

### Level 3: `HIGHLY_SENSITIVE`
- Cryptographic keys, bearer tokens, passwords, session secrets, private document bytes, and clipboard contents.
- **Strictly Dropped**: `SanitizedContextFilter` automatically purges all `HIGHLY_SENSITIVE` messages before an external network call is made.

---

## 3. Immutable Audit Trail

Every transaction through the AI Gateway produces an immutable `AiAuditRecord`:
- `auditId`: Unique UUID.
- `requestId` & `proposalId`: Traceability links to user operations.
- `providerName` & `modelName`: Full provenance of the AI engine invoked.
- `userPromptSanitized`: Sanitized prompt with all tokens and private keys redacted.
- `outcome`: `PROPOSED`, `CONFIRMED_AND_QUEUED`, `USER_REJECTED`, `POLICY_BLOCKED`, `RATE_LIMITED`.
- `tokenUsage` & `latencyMs`: Precise resource consumption metrics.
