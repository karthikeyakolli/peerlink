# Supabase Control Plane Specification

## 1. Schema & Table Definitions

### 1.1 `device_registry`
Stores the binding between a Supabase account user and a physical device's cryptographic identity:
```sql
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
```

### 1.2 `device_presence`
Stores volatile network connectivity information and heartbeat status:
```sql
CREATE TABLE public.device_presence (
    device_id UUID PRIMARY KEY REFERENCES public.device_registry(device_id) ON DELETE CASCADE,
    presence_status TEXT NOT NULL CHECK (presence_status IN ('ONLINE', 'AWAY', 'BUSY', 'OFFLINE')),
    candidate_endpoints JSONB NOT NULL DEFAULT '[]'::JSONB,
    last_heartbeat_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ttl_seconds INTEGER NOT NULL DEFAULT 60
);
```

### 1.3 `signaling_messages`
Stores short-lived messages for WebRTC signaling and P2P hole-punching:
```sql
CREATE TABLE public.signaling_messages (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_peer_id TEXT NOT NULL,
    recipient_peer_id TEXT NOT NULL,
    message_type TEXT NOT NULL CHECK (message_type IN ('OFFER', 'ANSWER', 'ICE_CANDIDATE', 'RELAY_REQUEST', 'HANGUP', 'PAIRING_INVITE')),
    payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '5 minutes'),
    is_consumed BOOLEAN NOT NULL DEFAULT FALSE
);
```

---

## 2. Java Native Adapter
Rather than relying on unofficial or heavy third-party Java SDKs, PeerLink ships a lightweight, zero-dependency Java adapter in `org.peerlink.core.cloud.supabase`:

| Class | Responsibility |
| :--- | :--- |
| `SupabaseConfig` | Endpoint URLs, public `anonKey`, environment, timeouts, and security validator |
| `SimpleJson` | Zero-dependency high-performance JSON serializer and parser |
| `SupabaseAuthClient` | GoTrue HTTPS client for signup, password login, token refresh, and logout |
| `SupabaseRestClient` | PostgREST HTTP client with automated retries and circuit breaker protection |
| `SupabaseRealtimeClient`| Phoenix Channel WebSocket client with heartbeat, subscribe, and deduplication |
| `CircuitBreaker` | Outage detection, failure tracking, and degraded mode isolation |
| `RetryPolicy` | Exponential backoff with jitter for transient network failures |
| `SupabaseControlPlaneCoordinator` | High-level orchestrator linking auth, presence, signaling, and recovery |

---

## 3. Ephemeral Candidate Endpoint Model
When a node comes online, it publishes its candidates to `device_presence.candidate_endpoints`:
- Local LAN IP:Port (e.g., `192.168.1.105:54321`)
- STUN-reflected Public IP:Port (e.g., `203.0.113.10:54321`)
- Relay endpoints if direct connection is blocked by symmetric NAT

Peers query `active_device_presence` to initiate connection attempts. If direct connection fails, they fall back to signaling negotiation via `signaling_messages`.
