# Online Supabase Control Plane Configuration

## Project Overview
The PeerLink control plane has been deployed and migrated to the live online Supabase cloud infrastructure.

- **Project ID**: `kfoeqywychjzudmrlxui`
- **Project Name**: `PeerLink`
- **Region**: `ap-south-1` (Asia South)
- **Status**: `ACTIVE_HEALTHY`
- **API URL**: `https://kfoeqywychjzudmrlxui.supabase.co`
- **Database Host**: `db.kfoeqywychjzudmrlxui.supabase.co`
- **PostgreSQL Version**: `17`

---

## Client API Credentials

```ini
SUPABASE_URL=https://kfoeqywychjzudmrlxui.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_NPeFPDaTxRtvSZ2QxX--kA_oRVICopY
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtmb2VxeXd5Y2hqenVkbXJseHVpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEwMzU4OTUsImV4cCI6MjEwNjYxMTg5NX0.FPBXlNO-nhY6AyS2D8on0wg1Wl8BMpLVzl53rLMFsI8
```

> [!IMPORTANT]
> Client nodes (Desktop and Android) must **ONLY** possess the public publishable/anon key.
> Service-role secret keys are never distributed to client nodes.

---

## Deployed Online Schema & Security Architecture

### Tables
1. **`public.device_registry`**: Device public identity keys, fingerprints, OS, and client versions with RLS.
2. **`public.device_presence`**: Ephemeral device online/offline states and candidate ICE endpoints.
3. **`public.pairing_requests`**: Temporary out-of-band pairing coordination requests.
4. **`public.share_metadata`**: High-level share display titles, permissions, and expiration timestamps (**zero file contents**).
5. **`public.control_audit_log`**: User device audit trail.
6. **`public.signaling_messages`**: WebRTC/ICE offer, answer, and candidate signaling messages with auto-expiry.

### Views & Functions
- **`public.active_device_presence`**: Realtime view calculating effective device status considering heartbeat TTL.
- **`public.cleanup_expired_signaling()`**: Automated cleanup of consumed and expired signaling messages.

### Row-Level Security (RLS)
- RLS is enabled on all tables.
- Authenticated users can query active public identity keys for peer discovery and verification.
- Device presence and signaling messages are restricted to authorized device owners and intended message recipients.
