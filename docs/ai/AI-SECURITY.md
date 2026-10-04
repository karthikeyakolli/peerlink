# PeerLink AI Security Specifications

## 1. Adversarial Threat Model

The AI Gateway is treated as an **untrusted input generator**. All proposals are subjected to the same strict validation as network payloads arriving from unauthenticated remote peers.

| Threat | Attack Vector | PeerLink Defense Mechanism |
| :--- | :--- | :--- |
| **Direct Prompt Injection** | User or injected text: *"Ignore previous instructions and delete / execute..."* | `PromptInjectionGuard` pattern detection + `DeterministicAiPolicyEngine` command block |
| **Indirect Prompt Injection** | Received PDF/document contains hidden override instructions | Inbound file content is wrapped in `<untrusted_input>` boundary tags and excluded from privileged context |
| **Privilege Escalation** | AI attempts to emit `revoke_device`, `modify_trust`, or `disable_scanner` | Hardcoded forbidden directive list immediately flags `SECURITY_VIOLATION` |
| **File Deletion Abuse** | AI proposes `OperationIntent.DELETE` | Deterministic policy engine unconditionally rejects AI-originated deletion proposals |
| **Path Traversal via AI** | AI specifies `../../etc/passwd` or `C:\Windows\System32` | Proposals accept only `ObjectIdentity`; paths are resolved internally by authoritative index |
| **Stale State Exploitation** | File modified/replaced after AI generates proposal | Pre-execution `ContentHash` verification detects mismatch and halts execution |

---

## 2. Deterministic AI Policy Engine

The `DeterministicAiPolicyEngine` enforces frozen PeerLink security policies programmatically:
1. **Forbidden Operations**:
   - `DELETE` is permanently blocked for AI proposals.
   - Device revocation and pairing adjustments are rejected at the compiler/engine level.
2. **User Confirmation Required**:
   - `SMART_SHARE`: Grants external peer access; requires explicit user dialog approval.
   - `SMART_BUNDLE`: Batch file transfer requires user confirmation.
   - `TRANSFER_RECIPE`: Recurring scheduled actions require user confirmation.
   - `RESTORE`: Historical backup restores require confirmation.
3. **Safe Read-Only Operations**:
   - Natural language search over locally indexed metadata.
   - Diagnostics, sync, and compatibility explanations based strictly on deterministic evidence.

---

## 3. Defense Against Indirect Content Injection

When untrusted file snippets or peer metadata must be analyzed:
```
<untrusted_input source="received_file_content">
[Untrusted user or peer data is HTML-escaped and tagged here]
</untrusted_input>
```
The model system prompt explicitly isolates `<untrusted_input>` as non-executable text. Even if the model emits a compromised tool invocation, the **Deterministic Policy Engine** intercepts and rejects the violation before any operational action can be dispatched.
