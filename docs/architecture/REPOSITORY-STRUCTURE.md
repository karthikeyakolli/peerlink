# PeerLink — Repository Structure

```text
PeerLink/
├── apps/
│   └── peerlink-app/                 # Flutter cross-platform application
│       ├── lib/
│       │   ├── core/
│       │   ├── application/
│       │   ├── features/
│       │   ├── platform/
│       │   └── main.dart
│       ├── android/
│       ├── windows/
│       ├── macos/
│       ├── linux/
│       └── test/
│
├── core/
│   ├── peerlink-core/                # portable JVM domain/application library
│   └── peerlink-desktop-node/        # Java 25 desktop Local Node
│
├── protocol/
│   ├── proto/
│   ├── generated-java/
│   └── generated-dart/
│
├── supabase/
│   ├── migrations/
│   ├── functions/
│   ├── seed/
│   └── config/
│
├── relay/
│   ├── coturn/
│   └── deployment/
│
├── tools/
│   ├── peerlink-test-peer/
│   ├── protocol-tester/
│   ├── network-fault-injector/
│   ├── file-generator/
│   └── diagnostics/
│
├── tests/
│   ├── unit/
│   ├── integration/
│   ├── network/
│   ├── filesystem/
│   ├── security/
│   ├── sync/
│   ├── transfer/
│   ├── android/
│   ├── cross-platform/
│   ├── chaos/
│   └── e2e/
│
├── docs/
│   ├── architecture/
│   ├── platforms/
│   ├── protocol/
│   ├── development/
│   ├── security/
│   └── testing/
│
├── scripts/
├── .github/
│   └── workflows/
├── pom.xml
├── README.md
└── AGENTS.md
```

## Dependency direction

```text
Flutter
  -> Local Node API
  -> platform APIs

Desktop Local Node
  -> portable core
  -> infrastructure
  -> platform adapters

Portable core
  -> protocol/domain contracts

Protocol
  -> no UI dependency
  -> no Supabase dependency
  -> no filesystem implementation dependency
```

This prevents architectural cycles.
