# PeerLink AI Gateway Architecture

## 1. Architectural Mandate & Principle of Non-Authority

```
User Request
     ↓
AI Gateway (`AiGateway`)
     ↓
AI Structured Proposal (`AiProposal`)
     ↓
Deterministic Policy Engine (`DeterministicAiPolicyEngine`)
     ↓
Current-State Revalidation (`ObjectStateResolver` & `ContentHash`)
     ↓
Authorization & Resource Checks
     ↓
User Confirmation (`requiresUserConfirmation`)
     ↓
Existing Operation Manager (`OperationRecord` & `OperationJournal`)
     ↓
Deterministic Local Node Execution
```

> [!CRITICAL]
> **AI is NEVER the source of truth.**
> PeerLink enforces deterministic control boundaries. AI models are strictly advisory proposal generators.

---

## 2. Inviolable Security Invariants
AI models and gateway components must **NEVER** directly control:
1. Identity keys or cryptographic key generation
2. Trust, pairing verification, or device revocation
3. Authorization token granting or capability signing
4. Payload encryption or decryption authorities
5. File deletion or destructive filesystem operations
6. Synchronization causal truth (vector clocks, version graphs)
7. Backup historical ledger entries or retention policies
8. Antimalware scanner policies or quarantine release
9. Execution of received binaries or system commands
10. Operating system configuration or firewall rules

---

## 3. Core Gateway Components

### A. Provider Abstraction (`AiProvider`)
- Uniform contract for model invocation (`generateResponse(AiRequest)`).
- Pluggable provider ecosystem:
  - **Gemini**: Primary cloud provider (`gemini-1.5-pro` / `gemini-1.5-flash`).
  - **OpenAI-Compatible REST**: Supports **Groq** (`llama-3.3-70b-versatile`) and **NVIDIA Nemotron** (`nvidia/llama-3.1-nemotron-70b-instruct`) using secure client bearer tokens.
  - **Simulated Provider**: Fully offline, deterministic model provider for unit tests, isolated sandboxes, and safety validation.

### B. Structured Operation Proposals (`AiProposal`)
- Proposals operate exclusively on immutable identifiers:
  - **`ObjectIdentity`** (`obj_...`), never transient or manipulated file paths.
  - **`PeerId`**, never unverified hostnames or raw IP addresses.
  - Explicit mapped `OperationIntent` (`SHARE`, `SEND`, etc.).
  - Expected `ContentHash` for pre-execution integrity confirmation.

### C. Current-State Revalidation
- Before any AI proposal is dispatched to the `OperationManager`:
  1. The target `ObjectIdentity` is resolved to its current disk location.
  2. If the file has moved, been deleted, or renamed since the prompt was evaluated, the operation is immediately aborted.
  3. The current SHA-256 `ContentHash` is verified. If the file content mutated, execution halts.

### D. Rate Limiting & Token Budgeting
- **`RateLimiter`**: Token bucket preventing prompt flooding or accidental denial of service (default 60 requests/minute).
- **`TokenBudget`**: Monthly spend cap preventing unbounded cloud API costs.
