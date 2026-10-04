# Blind / Untrusted Backup Target Architecture

## Threat Model

When storing backups on third-party servers, untrusted cloud storage, or untrusted peer nodes, PeerLink enforces **Blind Encrypted Backup**.

### Core Guarantees:
- **Zero-Knowledge Target:** The target repository stores only ciphertext payloads and manifest envelopes.
- **Decryption Authority:** The backup target never possesses decryption keys or authorization tokens.
- **Transport vs. Storage Encryption Separation:**
  - Transport encryption (TLS / Noise protocol) protects data in flight between peers.
  - Storage encryption (AES-256-GCM blind cipher) encrypts payloads client-side prior to transmission and persists in ciphertext on disk.
- **Reconstructability Proving:** The client can verify and reconstruct backups using its locally held 256-bit AES master key. Without the key, the backup target cannot decipher file contents, metadata titles, or file paths.

```
 Client (Holds Secret Key)                     Untrusted Target
┌─────────────────────────┐               ┌───────────────────────┐
│ Plaintext File Payload  │               │                       │
│           │             │               │                       │
│           ▼             │               │                       │
│  AES-256-GCM Encrypt    │               │                       │
│  (IV + Ciphertext + Tag)│ ──Network──►  │ Stores Ciphertext     │
│           │             │               │ (No Decryption Key)   │
│           ▼             │               │                       │
│ Compute StorageHash     │               └───────────────────────┘
└─────────────────────────┘
```