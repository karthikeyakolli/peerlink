# Collaborative Clipboard Synchronization

## Modes Supported
- `OFF`: Disabled.
- `TEXT`: Plaintext only.
- `TEXT_AND_URL`: Plaintext and URLs.
- `TEXT_AND_SUPPORTED_IMAGE`: Text, URLs, and PNG/JPEG raster images.

## Security & Privacy Invariants

1. **Strict Ephemeral In-Memory Storage:**
   - Clipboard payloads are held strictly in memory with a short TTL (5 minutes).
   - **Rule:** Clipboard content must **NOT appear in normal diagnostics, operation journals, or persistent history**.
2. **Loop Prevention (`ClipboardLoopGuard`):**
   - Automatically drops incoming items whose `originPeerId == localPeerId`.
   - Caches recently observed content hashes to prevent echo ping-pong loops across connected peers.
3. **Sensitivity Inspection (`ClipboardSensitivityInspector`):**
   - Inspects clipboard text prior to broadcast.
   - Detects private keys, JWT tokens, cloud API keys, passwords, and credit card numbers.
   - Blocks automated synchronization of sensitive content to prevent credential leakage.