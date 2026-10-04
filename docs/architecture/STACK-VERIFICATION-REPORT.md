# PeerLink — Technology Selection Verification Report

**Audit date:** 2026-10-02
**Purpose:** Check the chosen stack for current-platform support and architectural contradictions before implementation.

## Result

The stack is approved for implementation **with explicit boundaries**. The main earlier contradictions have been resolved by making protocol, transport, runtime and platform integration separate concerns.

## Verified decisions

### Flutter

Flutter currently supports Android, Windows, macOS and Linux deployment, with platform-specific integration options. Development for iOS requires macOS. The supported-platform matrix should be rechecked at release time because supported OS versions evolve.

Source: https://docs.flutter.dev/reference/supported-platforms

### Java

Java 25 is the desktop Local Node/runtime baseline. Portable shared JVM code must not assume Java 25-only APIs when that code is intended for Android reuse.

Android build tooling currently uses JDK 17 as its required JDK baseline for AGP 9.4.0.

Source: https://developer.android.com/build/releases/agp-9-4-0-release-notes

### Protobuf

Protobuf provides generated Java and Dart code from the same `.proto` contract. This is the formal portability mechanism across implementations.

Sources:
- https://protobuf.dev/reference/java/java-generated/
- https://protobuf.dev/reference/dart/dart-generated/

### Supabase

Supabase officially supports Dart/Flutter, JavaScript/TypeScript, Swift and Python clients. Kotlin is listed as community-supported; Java is not an official client. Therefore the Java Local Node should use an explicit HTTP/WebSocket adapter instead of depending on an unofficial Java SDK.

Source: https://supabase.com/docs/guides/api/rest/client-libs

### Supabase Realtime

Realtime is appropriate for presence, ephemeral signaling and wakeup/coordination. It has plan-level connection, message-rate and payload limits and must not be treated as the durable source of truth for operations.

Sources:
- https://supabase.com/docs/guides/realtime/limits
- https://supabase.com/docs/guides/realtime/presence

### gRPC

gRPC-Java supports Android clients, but the Netty transport is not supported on Android; Android uses the OkHttp transport. PeerLink therefore uses gRPC primarily for desktop Flutter ↔ Java Local Node IPC, while Android uses a native Flutter platform bridge such as Pigeon.

Source: https://github.com/grpc/grpc-java

### Netty

Netty 4.2 is the current stable/recommended line and 4.2.18.Final is a 2026 bug-fix/security release. QUIC support has native/platform requirements, so Netty/QUIC is a desktop transport implementation rather than a mandatory cross-platform transport.

Source: https://netty.io/news/2026/09/09/4-2-18-Final.html

### Android background work

Android provides WorkManager, user-initiated data-transfer jobs and foreground services for different transfer scenarios, with OS constraints. PeerLink Android must select the mechanism based on the operation rather than emulate a desktop daemon.

Sources:
- https://developer.android.com/develop/background-work/background-tasks/data-transfer-options
- https://developer.android.com/develop/background-work/background-tasks/uidt

### Flutter native integration

Flutter supports platform channels/plugins for native APIs and currently recommends `dart:ffi` for appropriate native library integration. This enables platform-specific filesystem, security, background and OS features without moving PeerLink business semantics into Dart.

Source: https://docs.flutter.dev/platform-integration/bind-native-code

## Rejected stack alternatives

- Spring Boot as an additional application backend: unnecessary duplication because Supabase is already the control plane.
- Redis for V1: unnecessary until measured scale requires it.
- JavaFX: rejected in favor of Flutter for a common cross-platform UI.
- Netty/QUIC on Android as a universal requirement: rejected because transport support and native constraints differ by platform.
- gRPC server inside Android: rejected; Android uses a native bridge to the node/core.
- Supabase Storage for normal P2P files: rejected because it conflicts with the product's distributed-data design.
- Full WebRTC dependency as the core transport: not selected; may be evaluated later as a transport adapter.

## Final confidence

The architecture is internally coherent enough to begin implementation. Future technology changes must be evidence-driven and recorded as ADRs.
