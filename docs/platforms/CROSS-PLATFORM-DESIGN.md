# PeerLink — Cross-Platform Design

## 1. Target model

```text
                   PeerLink Protocol
                         |
       +-----------------+-----------------+
       |                 |                 |
    Desktop            Android          Future iOS
       |                 |                 |
    Flutter           Flutter           Flutter/native
       |                 |                 |
    Java Node      Kotlin/Java layer     native core
       |                 |                 |
 Platform APIs      Android APIs        Apple APIs
```

## 2. What is shared

- Protobuf contracts
- object semantics
- operation lifecycle
- transfer state machine
- sync/version semantics
- backup semantics
- authorization semantics
- capability negotiation
- security verdict vocabulary
- error codes
- user-intent vocabulary

## 3. What is platform-specific

- filesystem access and URI/path representation
- background execution
- OS key storage
- notifications
- sharing UI and system share targets
- discovery mechanisms
- native network APIs
- antivirus integration
- file manager/shell integration
- power/sleep handling
- application startup
- native virtual filesystem/provider integrations

## 4. Desktop composition

```text
Flutter UI
   |
   | authenticated gRPC
   v
Java Local Node
   |
   +-- domain
   +-- application
   +-- networking
   +-- filesystem
   +-- security
   +-- transfer
   +-- sync
   +-- recovery
   +-- Supabase adapter
```

The Java Node is designed to continue safe background operations when the Flutter UI is closed.

## 5. Android composition

```text
Flutter UI
   |
   | Pigeon/platform API
   v
Android bridge/service layer
   |
   +-- lifecycle
   +-- storage permissions
   +-- notifications
   +-- user-initiated transfers
   +-- background scheduling
   +-- Keystore
   |
   v
Portable PeerLink Java logic where compatible
```

The Android implementation must expose capability states so the UI can distinguish `AVAILABLE`, `BACKGROUND_LIMITED`, `USER_ACTION_REQUIRED`, `UNAVAILABLE`, etc.

## 6. Filesystem contract

All core operations use a platform-neutral file abstraction.

```text
PeerFileHandle
- logical object_id
- display_name
- parent identity
- access capabilities
- metadata
- read/write handles
```

Physical representation:

- Windows/Linux/macOS: filesystem path/file descriptor equivalents.
- Android: content/document URI and persisted permissions where available.
- Future iOS: security-scoped/file-provider abstractions.

## 7. Discovery contract

```text
DiscoveryProvider
 -> candidates
 -> capabilities
 -> address/path information
```

Discovery never grants trust. Identity verification and authorization happen later.

Possible providers:

- mDNS/DNS-SD
- Android NSD
- Wi-Fi Direct/Wi-Fi Aware adapters
- platform-native nearby APIs
- QR/manual pairing

## 8. Transport contract

```text
PeerLinkTransport
 - connect
 - listen
 - openStream
 - close
 - pathInfo
 - capabilities
```

Implementations may differ by platform.

## 9. Background contract

```text
BackgroundExecutionProvider
 - schedule
 - runNowIfAllowed
 - cancel
 - constraints
 - capabilityState
```

This prevents desktop assumptions from leaking into Android.

## 10. Future iOS rule

iOS/iPadOS must reuse the protocol and product semantics but may use a native core implementation. Do not design iOS around the assumption that Java bytecode can be embedded as the production engine.
