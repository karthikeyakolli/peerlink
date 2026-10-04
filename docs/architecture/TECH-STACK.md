# PeerLink — Final Technology Stack

## Stack principles

1. Java-first, not Java-everywhere.
2. Cross-platform through Flutter and protocol contracts.
3. Native OS APIs only where they provide required capabilities.
4. Avoid redundant backend frameworks.
5. Pin exact versions in repository toolchain files when implementation starts; the choices below define the technology families and validated baseline.

## Core

| Area | Decision | Notes |
|---|---|---|
| UI | Flutter / Dart | Native Windows, macOS, Linux and Android targets |
| Desktop runtime | Java 25 LTS | Local Node/engine runtime |
| Portable JVM core | Java 17-compatible API baseline | Runs on desktop Java 25 and is consumable by Android JVM/ART |
| Android platform layer | Kotlin + Java | Native lifecycle/storage/security integration |
| Desktop build | Maven + Maven Wrapper | Java modules |
| Android build | Gradle/Android toolchain | Flutter Android project |
| Protocol | Protobuf | Shared schema across implementations |
| Desktop IPC | gRPC + Protobuf | Local UI ↔ Local Node only |
| Local DB | SQLite | Desktop node state |
| Android DB | Room/SQLite | Android physical implementation |
| Filesystem | Java NIO on desktop | Wrapped by platform abstraction |
| Cloud | Supabase | Control plane |
| Cloud DB | Supabase Postgres | Durable control state |
| Cloud identity | Supabase Auth | Account identity |
| Cloud realtime | Supabase Realtime | Presence/signaling/ephemeral coordination |
| Server-side functions | Supabase Edge Functions | Only for trusted cloud-side workflows |
| Relay | coturn | STUN/TURN infrastructure |
| Desktop P2P framework | Netty 4.2.x | Transport implementation; not protocol contract |
| Preferred desktop transport | QUIC | Where supported/validated |
| Compatibility transport | TCP/TLS | Broad fallback |
| NAT traversal | ICE/STUN/TURN abstraction | ice4j is a desktop candidate, not a mandatory Android dependency |
| Crypto | JCA/JCE + mature platform APIs | No custom cryptography |
| Secret storage | OS-native stores | Keychain/Windows security facilities/Linux secret store/Android Keystore |
| Malware scanning | Provider adapters | Defender/ClamAV/etc. |
| Logging | SLF4J + Logback | Structured logs |
| Observability | OpenTelemetry | Trace/metric/log correlation |
| Testing | JUnit 5, Mockito, Testcontainers, Flutter tests | Plus PeerLink test peer/harness |
| Containers | Docker/Compose | Local infra/test environments only |
| AI | PeerLink AI Gateway | Gemini first; providers abstracted |
| Packaging | Flutter desktop packaging + bundled Java runtime | Native signing/notarization per OS |

## Current verified ecosystem notes

- Flutter 3.47 supports Android and major desktop platforms; iOS requires macOS for development. See Flutter supported platforms.
- Flutter recommends `dart:ffi` for native libraries where FFI is appropriate; standard plugins/platform APIs remain appropriate for OS services.
- Supabase officially supports Dart/Flutter, JavaScript/TypeScript, Swift and Python clients. Kotlin is community-supported; Java is not an official Supabase client.
- gRPC-Java supports Android clients using the OkHttp transport; its Netty transport is not supported on Android.
- Netty 4.2 is the active stable/recommended line; QUIC support involves native platform components.
- Android data-transfer execution has OS-specific restrictions and supported user-initiated data-transfer/job mechanisms.

## Versioning policy

Do not put arbitrary latest versions into application source. Record exact versions in:

- `.java-version`
- Flutter version management file (`.fvmrc` or equivalent)
- Maven dependency management/BOMs
- Gradle version catalog
- protobuf/gRPC plugin versions
- Docker image digests/tags for test infrastructure

When upgrading a foundational dependency, run the full verification matrix and record the upgrade in an ADR.

## Primary verification sources

- Flutter supported platforms: https://docs.flutter.dev/reference/supported-platforms
- Flutter multi-platform/platform integration: https://docs.flutter.dev/platform-integration
- Android AGP 9.4/JDK 17: https://developer.android.com/build/releases/agp-9-4-0-release-notes
- Supabase client libraries: https://supabase.com/docs/guides/api/rest/client-libs
- Supabase Realtime limits: https://supabase.com/docs/guides/realtime/limits
- gRPC-Java platform notes: https://github.com/grpc/grpc-java
- Netty 4.2.18.Final release: https://netty.io/news/2026/09/09/4-2-18-Final.html
- Protobuf Java generation: https://protobuf.dev/reference/java/java-generated/
- Protobuf Dart generation: https://protobuf.dev/reference/dart/dart-generated/
- Android background data transfer: https://developer.android.com/develop/background-work/background-tasks/data-transfer-options

## Dependency-boundary clarifications

- Desktop gRPC IPC should prefer `grpc-netty-shaded` on the Java side so gRPC's Netty dependency is isolated from PeerLink's own Netty networking stack.
- The Java control-plane adapter may use the JDK `java.net.http.HttpClient` and WebSocket APIs rather than introducing another HTTP client framework.
- The Java AI Gateway may initially call Gemini through standard HTTPS APIs behind a provider interface; provider SDKs are optional and must not leak into the domain layer.
- Netty is a desktop transport implementation, not a domain dependency.
- Flutter platform plugins are integration adapters, not the source of PeerLink business truth.
