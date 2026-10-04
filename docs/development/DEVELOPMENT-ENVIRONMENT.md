# PeerLink — Development Environment

## 1. Primary development machine

Windows is the initial development host.

Recommended local tooling:

- Antigravity + Gemini
- Flutter SDK
- JDK 25
- Java IDE/tooling as needed
- Android Studio + Android SDK/emulator
- Maven Wrapper
- Gradle/Flutter tooling for Android
- Docker Desktop
- Git

Flutter's current setup supports Windows desktop development on Windows and Android development through an emulator or physical device.

## 2. Local laboratory

Create two independent PeerLink nodes on one computer:

```text
PC
├── PeerLink Node A
│   ├── identity-A
│   ├── sqlite-A
│   └── files-A
├── PeerLink Node B
│   ├── identity-B
│   ├── sqlite-B
│   └── files-B
└── test harness
```

This is the first P2P development environment.

## 3. Real-device laboratory

Minimum useful test set:

```text
Windows desktop A
    <->
Windows desktop B or Android phone
```

Then expand to:

- Windows ↔ Linux
- Windows ↔ macOS
- Android ↔ Linux/macOS/Windows

## 4. Cloud development environment

Use a dedicated Supabase development project.

Never give local experiments a production service-role credential.

Test infrastructure may include local Docker services for:

- PostgreSQL-compatible test dependencies where needed
- coturn
- telemetry collector

## 5. Run modes

### Desktop UI + local node

```text
flutter run -d windows
```

The development launcher should start/connect the Java Local Node automatically.

### Java Node

```text
./mvnw test
./mvnw verify
```

### Android

```text
flutter devices
flutter run -d <android-device>
```

Use an Android emulator for rapid UI work and a physical Android device for network/storage/background validation.

## 6. Local environment rules

- Development data lives outside source control.
- Secrets are injected through local environment/configuration, never committed.
- Each test node receives an independent identity.
- Production Supabase project is never used for destructive tests.
- Test files are generated deterministically where possible.

## 7. One-command goal

Create repository scripts so the normal developer flow is eventually:

```text
setup
build
run
check
integration-test
```

The exact commands may differ by operating system, but the workflow should be standardized.
