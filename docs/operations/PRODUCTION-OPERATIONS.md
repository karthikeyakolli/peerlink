# PeerLink Production Operations & Infrastructure Manual

**Document**: `docs/operations/PRODUCTION-OPERATIONS.md`  
**Version**: 1.0.0  
**Target Release**: PeerLink 1.0.0-GA  
**Audience**: DevOps, Site Reliability Engineering (SRE), Platform Operations  

---

## 1. Production Architecture Overview

PeerLink V1.0 operates on a **hybrid local-first architecture**:
1. **Core Data Plane (Peer-to-Peer)**: End-to-end encrypted direct QUIC / TLS transport connections between paired devices (Windows, macOS, Linux, Android). Content data never touches centralized storage.
2. **Cloud Control Plane (Supabase)**: Provides account-to-device mapping, ephemeral network presence, and WebRTC/ICE signaling mediation when peers are not on the same local subnet.
3. **Turn/Relay Infrastructure (coturn)**: Standardized RFC 5766 TURN and RFC 8489 STUN clusters for symmetric NAT traversal where direct UDP hole punching fails.

```
+─────────────────────────────────────────────────────────────────────────────+
│                       SUPABASE CONTROL PLANE                                │
│   +────────────────────────+  +───────────────────+  +──────────────────+   │
│   │ device_registry (RLS)  │  │ device_presence   │  │signaling_messages│   │
│   +────────────────────────+  +───────────────────+  +──────────────────+   │
+──────────────────────────────────────┬──────────────────────────────────────+
                                       │ (WSS / HTTPS - TLS 1.3)
                  ┌────────────────────┴────────────────────┐
                  ▼                                         ▼
         +─────────────────+                       +─────────────────+
         │  Peer Node A    │◄═════════════════════►│   Peer Node B   │
         │  (Windows/Mac)  │  Direct TLS / QUIC    │ (Linux/Android) │
         +────────┬────────+  (Zero Central Data)  +────────┬────────+
                  │                                         │
                  └─────────────►[ coturn Relay ]◄──────────┘
                                (Encrypted TURN Fallback)
```

---

## 2. Production Supabase Control Plane Configuration

### 2.1 Project Profile & Endpoints
* **Production Project Ref**: `peerlink-prod-control-plane`
* **REST API Endpoint**: `https://api.peerlink.io/rest/v1`
* **Auth / GoTrue Endpoint**: `https://api.peerlink.io/auth/v1`
* **Realtime WebSocket Endpoint**: `wss://api.peerlink.io/realtime/v1/websocket`
* **TLS Requirement**: TLS 1.3 Mandatory (TLS 1.2 minimum). Insecure HTTP is programmatically rejected by `SupabaseConfig.java`.

### 2.2 Strict Key Management & Zero-Trust Invariants
* **Public Anon Key**: Distributed in client binaries. Grants strictly scoped read/write access defined by Row Level Security (RLS) policies.
* **Service Role Key**: **STRICTLY PROHIBITED in client distributions.**
  * Programmatically enforced in `SupabaseConfig`:
    ```java
    if (lowerKey.contains("service_role") || lowerKey.contains("secret")) {
        throw new SecurityException("CRITICAL SECURITY ERROR: service-role secrets must NEVER be configured on client nodes!");
    }
    ```
  * Verified in Release Candidate build: zero service keys detected across client strings, bytecode, and manifests.

### 2.3 Row Level Security (RLS) Policies

All production tables have RLS enabled with deterministic ownership checks:

#### `public.device_registry`
```sql
ALTER TABLE public.device_registry ENABLE ROW LEVEL SECURITY;

-- Users may only view and register devices linked to their authenticated UUID
CREATE POLICY "Users view own registered devices"
ON public.device_registry FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users register own devices"
ON public.device_registry FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own devices"
ON public.device_registry FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users revoke own devices"
ON public.device_registry FOR DELETE
USING (auth.uid() = user_id);
```

#### `public.device_presence`
```sql
ALTER TABLE public.device_presence ENABLE ROW LEVEL SECURITY;

-- Any authenticated user in the same trust mesh or self may read presence
CREATE POLICY "Trusted peers can read presence"
ON public.device_presence FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.device_registry r
        WHERE r.device_id = public.device_presence.device_id
        AND r.user_id = auth.uid()
    )
);

CREATE POLICY "Devices update own presence"
ON public.device_presence FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM public.device_registry r
        WHERE r.device_id = public.device_presence.device_id
        AND r.user_id = auth.uid()
        AND r.is_revoked = FALSE
    )
);
```

#### `public.signaling_messages`
```sql
ALTER TABLE public.signaling_messages ENABLE ROW LEVEL SECURITY;

-- Senders insert messages targeted to paired peer IDs
CREATE POLICY "Send signaling messages"
ON public.signaling_messages FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.device_registry r
        WHERE r.peer_id = sender_peer_id
        AND r.user_id = auth.uid()
        AND r.is_revoked = FALSE
    )
);

-- Recipients consume messages addressed to their own peer ID
CREATE POLICY "Receive own signaling messages"
ON public.signaling_messages FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.device_registry r
        WHERE r.peer_id = recipient_peer_id
        AND r.user_id = auth.uid()
    )
);

-- Delete after consumption
CREATE POLICY "Delete consumed signaling messages"
ON public.signaling_messages FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM public.device_registry r
        WHERE r.peer_id = recipient_peer_id
        AND r.user_id = auth.uid()
    )
);
```

### 2.4 Production Realtime Engine
* Phoenix Channel subscriptions configured for `public:signaling_messages:recipient_peer_id=eq.{PEER_ID}`.
* Heartbeat interval: **20 seconds**.
* Ephemeral message TTL: **5 minutes** (automated database reaper cron deletes expired unconsumed signaling entries).

---

## 3. Production coturn Relay Configuration

### 3.1 Relay Server Clusters
* **Cluster Alpha (US East)**: `turn-us.peerlink.io:3478` (UDP/TCP), `turns-us.peerlink.io:5349` (TLS)
* **Cluster Beta (EU Central)**: `turn-eu.peerlink.io:3478` (UDP/TCP), `turns-eu.peerlink.io:5349` (TLS)
* **Cluster Gamma (AP East)**: `turn-ap.peerlink.io:3478` (UDP/TCP), `turns-ap.peerlink.io:5349` (TLS)

### 3.2 Canonical `turnserver.conf`
```ini
# PeerLink Production coturn Configuration
listening-port=3478
tls-listening-port=5349
fingerprint
lt-cred-mech
use-auth-secret
static-auth-secret="<REDACTED_PROD_HMAC_SECRET>"
realm=peerlink.io
total-quota=200000
bps-capacity=0
stale-nonce=600
cert=/etc/letsencrypt/live/turns.peerlink.io/fullchain.pem
pkey=/etc/letsencrypt/live/turns.peerlink.io/privkey.pem
cipher-list="ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384"
no-loopback-peers
no-multicast-peers
no-tlsv1
no-tlsv1_1
no-tlsv1_2
min-port=49152
max-port=65535
verbose=0
```

### 3.3 Ephemeral TURN Credentials (HMAC-SHA1)
Client nodes never receive static coturn passwords. Instead, when relay is required, the control plane generates time-limited HMAC-SHA1 credentials valid for **15 minutes**:
```
Username: {expiry_unix_timestamp}:{peer_id}
Password: HMAC-SHA1(static-auth-secret, username)
```

---

## 4. Node Daemon Management & Systemd Service

### 4.1 Systemd Service Unit (`/etc/systemd/system/peerlink-node.service`)
```ini
[Unit]
Description=PeerLink Local Node Daemon
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=peerlink
Group=peerlink
WorkingDirectory=/opt/peerlink
ExecStart=/usr/bin/java -Dfile.encoding=UTF-8 -jar /opt/peerlink/lib/peerlink-desktop-node.jar --port 50051 --config /etc/peerlink/application.properties
Restart=on-failure
RestartSec=5s
LimitNOFILE=65536
LimitNPROC=4096
StandardOutput=journal
StandardError=journal
SyslogIdentifier=peerlink-node

[Install]
WantedBy=multi-user.target
```

### 4.2 Health Check & Probes
* **Local gRPC Liveness Probe**:
  ```bash
  grpcurl -plaintext 127.0.0.1:50051 org.peerlink.protocol.v1.DesktopLocalNodeService/GetStatus
  ```
* **Success Output**:
  ```json
  {
    "status": "NODE_STATUS_ACTIVE",
    "version": "1.0.0",
    "storageHealthy": true
  }
  ```

---

## 5. Backup, Maintenance, & Database Integrity

1. **Local SQLite Backup (Desktop Nodes)**:
   * Perform safe, online, zero-lock backups using SQLite Online Backup API:
     ```bash
     sqlite3 ~/.peerlink/peerlink_local.db "VACUUM INTO '~/.peerlink/backups/peerlink_backup_$(date +%Y%m%d_%H%M%S).db'"
     ```
2. **Database Compaction (WAL Pruning)**:
   * Automatic WAL checkpointing occurs every 1,000 pages or on clean daemon shutdown.
   * Manual checkpoint:
     ```bash
     sqlite3 ~/.peerlink/peerlink_local.db "PRAGMA wal_checkpoint(TRUNCATE);"
     ```
3. **Database Integrity Audit**:
   * Verify zero corruption before applying upgrades:
     ```bash
     sqlite3 ~/.peerlink/peerlink_local.db "PRAGMA integrity_check;"
     # Expected output: ok
     ```
