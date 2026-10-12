# Supabase Control Plane Specification & Security Boundaries

## 1. Architectural Scope & Cloud Storage Boundary

> [!IMPORTANT]
> **Cloud Storage Boundary Rule:** Normal peer file contents, transfer chunks, and user file data **must never** touch Supabase or cloud databases. Supabase is strictly limited to control-plane coordination.

The core client runtime (`SupabaseRestClient`) actively enforces this boundary:
- Rejects any query or operation targeting tables such as `files`, `transfer_chunks`, `user_content`, or `blob_data` with a `SecurityException`.
- Enforces a hard 64 KB limit on control-plane metadata payloads to prevent covert cloud-drive storage.

Supabase is solely responsible for:
1. Supported identity/account integration (GoTrue auth sessions, JWT tokens).
2. Device registry (binding account identity to device cryptographic public keys).
3. Ephemeral presence and candidate endpoint publication (heartbeats, TTL expiration).
4. Asynchronous signaling envelopes for WebRTC / ICE hole punching.

---

## 2. Cryptographic Device Identity vs Supabase Account Identity

PeerLink strictly separates **Cryptographic Device Identity** from **Supabase Account Identity**:

| Dimension | Supabase Account Identity | Cryptographic Device Identity |
| :--- | :--- | :--- |
| **Identifier** | UUID `user_id` / JWT token | Ed25519 Public Key / `peer_id` (`peer_<hash>`) |
| **Authority** | Cloud authentication provider (Supabase GoTrue) | Local private key securely stored in OS keystore (DPAPI / Keychain / SecretService / Android Keystore) |
| **Role** | Account authorization, space membership, signaling rendezvous | End-to-end message integrity, transport mutual authentication, transfer authorization |
| **Trust Model** | Semi-trusted rendezvous server | Zero-trust; peer devices independently verify digital signatures on every signaling message and transport frame |

### Signaling Message Authorization & Signature Verification
Every `SignalingMessage` envelope must include:
- `senderPublicKey`: Base64-encoded Ed25519 public key.
- `signature`: Base64-encoded signature over canonical payload bytes (`senderPeerId | recipientPeerId | messageType | payload`).
- If an envelope has an invalid or tampered signature, the client coordinator immediately rejects it, preventing unauthorized or forged signaling.

---

## 3. Database Schema, Permissions & Row-Level Security (RLS)

### 3.1 Least-Privilege Permissions
All tables enforce PostgreSQL Row-Level Security (RLS) so that authenticated clients cannot read or tamper with other users' devices or signaling messages:

```sql
-- 1. device_registry
CREATE TABLE public.device_registry (
    device_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    peer_id TEXT NOT NULL UNIQUE,
    public_key TEXT NOT NULL,
    device_name TEXT NOT NULL,
    device_type TEXT NOT NULL,
    is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
    registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.device_registry ENABLE ROW LEVEL SECURITY;

CREATE POLICY device_registry_owner_select ON public.device_registry
    FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY device_registry_owner_insert ON public.device_registry
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY device_registry_owner_update ON public.device_registry
    FOR UPDATE TO authenticated USING (auth.uid() = user_id);

-- 2. device_presence
CREATE TABLE public.device_presence (
    device_id UUID PRIMARY KEY REFERENCES public.device_registry(device_id) ON DELETE CASCADE,
    presence_status TEXT NOT NULL CHECK (presence_status IN ('ONLINE', 'AWAY', 'BUSY', 'OFFLINE')),
    candidate_endpoints JSONB NOT NULL DEFAULT '[]'::JSONB,
    last_heartbeat_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ttl_seconds INTEGER NOT NULL DEFAULT 60
);

ALTER TABLE public.device_presence ENABLE ROW LEVEL SECURITY;

CREATE POLICY device_presence_user_select ON public.device_presence
    FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.device_registry r WHERE r.device_id = device_presence.device_id AND r.user_id = auth.uid()));

CREATE POLICY device_presence_owner_all ON public.device_presence
    FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM public.device_registry r WHERE r.device_id = device_presence.device_id AND r.user_id = auth.uid()));

-- 3. signaling_messages
CREATE TABLE public.signaling_messages (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_peer_id TEXT NOT NULL,
    recipient_peer_id TEXT NOT NULL,
    message_type TEXT NOT NULL CHECK (message_type IN ('OFFER', 'ANSWER', 'ICE_CANDIDATE', 'RELAY_REQUEST', 'HANGUP', 'PAIRING_INVITE')),
    payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    sender_public_key TEXT,
    signature TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '5 minutes'),
    is_consumed BOOLEAN NOT NULL DEFAULT FALSE
);

ALTER TABLE public.signaling_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY signaling_select_recipient ON public.signaling_messages
    FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.device_registry r WHERE r.peer_id = recipient_peer_id AND r.user_id = auth.uid()));

CREATE POLICY signaling_insert_sender ON public.signaling_messages
    FOR INSERT TO authenticated
    WITH CHECK (EXISTS (SELECT 1 FROM public.device_registry r WHERE r.peer_id = sender_peer_id AND r.user_id = auth.uid()));
```

---

## 4. Ephemeral Presence & Stale Record Filtering

Presence entries are volatile with a configurable TTL (default 60 seconds):
- `DevicePresenceEntry.isStale()`: Evaluates `(now - lastHeartbeat) > (ttlSeconds * 1000)`.
- `DevicePresenceEntry.getEffectiveStatus()`: Returns `OFFLINE` if stale, regardless of the recorded presence status.
- `SupabaseDeviceRegistryClient.queryActivePresence()`: Actively filters out stale entries, ensuring clients never attempt direct connections to stale endpoints.

---

## 5. Signaling Rate Limiting & Denial-of-Service Protection

The client coordinator incorporates `SignalingRateLimiter`, implementing a thread-safe token bucket:
- **Per-Peer Limit:** 30 messages/minute with a burst capacity of 10.
- **Global Limit:** 120 messages/minute with a burst capacity of 30.
- Exceeding the rate limit throws `SignalingRateLimitException` rather than flooding the signaling bus.

---

## 6. Realtime Reconnection & Exponential Backoff

`SupabaseRealtimeClient` manages WebSocket connections to Phoenix Channels:
- Automatic reconnection with exponential backoff (`reconnectAttempts`, base 1.0s, capped at 30.0s) and random jitter (10%).
- Message deduplication using a bounded LRU cache (`MAX_RECENT_EVENTS = 1000`) prevents processing duplicate events across reconnects.
- Automatic resubscription to peer signaling topics upon reconnection.
