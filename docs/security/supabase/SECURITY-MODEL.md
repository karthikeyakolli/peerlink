# Supabase Control Plane Security Model

## 1. Separation of Concerns & Keys

### Invariant: Strict Client Key Prohibition
- **Never embed service-role secrets in client applications.**
- Both the Desktop Node and Mobile (Android/iOS) client nodes strictly receive:
  1. `supabaseUrl`
  2. Public `anonKey`
- The `SupabaseConfig` constructor in `peerlink-core` performs programmatic enforcement:
  ```java
  if (lowerKey.contains("service_role") || lowerKey.contains("secret")) {
      throw new SecurityException("CRITICAL SECURITY ERROR: service-role secrets must NEVER be configured on client nodes!");
  }
  ```

---

## 2. Multi-Environment Segregation

PeerLink strictly separates configurations across deployment tiers via `SupabaseEnvironment`:

| Environment | Purpose | TLS Enforcement | URL Scheme |
| :--- | :--- | :--- | :--- |
| `DEVELOPMENT` | Local testing / Docker Supabase | Optional (supports `http://localhost`) | `http://` or `https://` |
| `STAGING` | Pre-production testing | Mandatory | `https://` |
| `PRODUCTION` | Live production control plane | Mandatory (`SecurityException` on `http://`) | `https://` |

---

## 3. Account Identity vs Cryptographic Device Identity

```
  Supabase Account Identity (GoTrue User UUID, Email, OAuth)
                              !=
  PeerLink Device Identity (Ed25519 Key Pair, Stable Peer ID)
```

- A compromised Supabase user account does **not** grant the ability to forge cryptographic signatures on file transfers.
- Transfer verification and session encryption use Ed25519 identity keys generated and stored locally in the OS secure keystore (Windows DPAPI, macOS Keychain, Android Keystore).
- The Supabase `device_registry` serves merely as a directory service mapping accounts to devices. Even if an attacker mutates this directory, untrusted peers cannot pass local node pairing or cryptographic handshake without the private key.

---

## 4. Threat Matrix & Mitigations

| Threat | Impact | Mitigation |
| :--- | :--- | :--- |
| Supabase Outage | Loss of cloud presence & signaling | Node trips `CircuitBreaker` and operates in local-first P2P mode (mDNS LAN discovery, direct IP) |
| Eavesdropping on Signaling | Interception of candidate endpoints | TLS/WSS transport encryption + end-to-end cryptographic handshake |
| Replay of Signaling Events | Stale connection attempts | 5-minute TTL on signaling records + client deduplication cache |
| Stale Presence Spoofing | Node appears online indefinitely | TTL-based expiration (`active_device_presence` view marks offline if heartbeat elapsed) |
| Service Role Key Leak | Full DB bypass | Service role keys never compiled or bundled into client binaries |
