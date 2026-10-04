# PeerLink — Final Architecture

## 1. System shape

PeerLink is a distributed application composed of independent nodes plus a small cloud control plane.

```text
                           INTERNET
                              |
              +---------------+---------------+
              |                               |
        SUPABASE CONTROL                  RELAY PLANE
              |                               |
        Auth / Postgres                 STUN / TURN
        Presence / Signaling                coturn
              |
       connection coordination
              |
      +-------+-----------------------+
      |                               |
  Desktop Node                    Android Node
      |                               |
  Flutter UI                     Flutter UI
      |                               |
  Java Local Node              Kotlin/Java layer
      |                               |
  SQLite / filesystem             Room/SQLite
      |                               |
      +------------- P2P -------------+
                 Direct or Relay
```

## 2. Four layers

### 2.1 Flutter application layer

Owns:

- presentation
- navigation
- user input
- UI state
- accessibility
- notifications shown through the application
- local-node client calls

Does **not** own:

- transfer truth
- sync truth
- trust authority
- encryption keys
- direct filesystem mutation
- destructive-operation authority

### 2.2 PeerLink Core / Local Node

The authoritative local application engine owns:

- identity
- trust
- authorization
- object model
- operation manager
- transfer engine
- sync engine
- backup engine
- filesystem abstraction
- search/index
- sharing/workspaces
- clipboard
- compatibility analysis
- security scanner orchestration
- recovery/reconciliation
- diagnostics
- resource scheduling
- AI gateway boundary
- Supabase control adapter

On desktop, this runs as a persistent Java process/service separate from the Flutter UI.

### 2.3 Central Control Plane

Supabase is used for control-plane state:

- user/account identity
- device registry
- presence
- signaling/coordination
- share metadata
- workspace membership/policy metadata
- minimal audit/control state

Supabase is **not** normal PeerLink file storage.

### 2.4 Relay Plane

`coturn` provides STUN/TURN infrastructure when direct peer connectivity is not available. Relays forward encrypted payloads but do not become application security authorities.

## 3. Data authority

| Data | Authoritative source |
|---|---|
| Actual file bytes | Local filesystem/storage provider |
| Local path/location mapping | Filesystem + reconciled local index |
| Logical object identity | Local object database + continuity mapping |
| Content hash | Verified hashing subsystem |
| Version/causal history | Sync/version state |
| In-flight operation | Operation journal |
| Authorization/trust | Local trust/policy store |
| Network session | Protocol/session state |
| Search/UI/AI indexes | Derived state |
| Presence | Supabase Realtime + current peer state |
| Durable cloud control state | Supabase Postgres |

## 4. Core operation path

```text
User Intent
 -> Flutter UI
 -> Local Node API
 -> Object Resolution
 -> Trust / Policy / Authorization
 -> Resource Check
 -> Operation Created
 -> Connection
 -> Direct or Relay
 -> Protocol Operation
 -> Filesystem/Data Operation
 -> Integrity Verification
 -> Malware/Safety Policy
 -> Commit
 -> Journal Finalize
 -> History / Diagnostics
 -> Flutter Event
```

AI requests enter the same pipeline after proposal generation. AI cannot bypass policy or the operation manager.

## 5. Operation lifecycle

```text
CREATED
  -> VALIDATED
  -> AUTHORIZED
  -> EXECUTING
  -> WAITING
  -> COMMITTED

Alternative terminal states:
FAILED
CANCELLED
OUTCOME_UNKNOWN
RECOVERY_REQUIRED
```

Durable operation sequence:

```text
INTENT -> EXECUTE -> VERIFY -> COMMIT -> FINALIZE
```

## 6. Desktop IPC

When the Flutter desktop process and Java Local Node are separate processes:

```text
Flutter Desktop
   |
   | authenticated local IPC
   | gRPC + Protobuf
   v
Java Local Node
```

Loopback is not automatically trusted. The IPC endpoint must authenticate the UI client using a per-installation secret, mutual authentication, or an equivalent local trust mechanism.

## 7. Android integration

Android uses the same product/domain semantics but platform-specific execution:

```text
Flutter
  |
  | typed platform API / Pigeon
  v
Kotlin/Java Android layer
  |
  v
portable PeerLink core
```

Android is a **full PeerLink node**, but cannot promise desktop-style always-on background availability because Android controls background execution.

## 8. Cross-platform principle

The shared boundary is primarily:

- protocol
- domain semantics
- object/operation model
- error semantics
- capability semantics
- security rules
- sync/version semantics

Platform-specific:

- filesystem APIs
- background execution
- notifications
- OS credential stores
- discovery adapters
- native sharing
- shell/Finder/file-manager integration
- antivirus integration
- power-management integration
