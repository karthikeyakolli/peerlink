# PeerLink for Windows — Self-Contained Platform Project

This directory contains the self-contained implementation of the PeerLink Windows application, including its authoritative Local Node daemon, native Win32 platform integrations, and Flutter desktop presentation layer.

---

## 1. Architecture & Security Boundary

```
+-------------------------------------------------------------------------+
|                        PeerLink Windows Desktop                         |
+-------------------------------------------------------------------------+
|  Flutter Desktop Client (Dart)                                          |
|  - UI Presentation & State Management                                   |
|  - Windows Window Frame & Shell Integration                             |
|  - Communicates EXCLUSIVELY via Authenticated Loopback gRPC             |
+-------------------------------------------------------------------------+
                                    |
            Local Loopback IPC      | 127.0.0.1:50051 (Token Authenticated)
            (No Direct DB Access)   v
+-------------------------------------------------------------------------+
|  Authoritative Windows Local Node Daemon (Java 21 LTS / 25)             |
|  - DPAPI Credential Store (Local User Profile Encryption)               |
|  - NTFS Filesystem Provider & Reserved Device Name Sanitizer            |
|  - SQLite Transfer Journal & SQLite WAL Identity/Session Storage        |
|  - Netty TCP Transport with Mutual Peer Identity Verification           |
|  - Windows Power Manager (Thread Execution State Standby Prevention)    |
|  - Windows Defender Firewall Rule Coordinator                           |
+-------------------------------------------------------------------------+
```

### Authoritative Invariants:
1. **Authoritative Boundary**: The presentation layer (Flutter) never directly accesses the SQLite transfer journal, database files, or private keys. All actions must be authorized over loopback gRPC (`127.0.0.1:50051`) using a cryptographically random session token.
2. **Local Credential Storage**: Private keys and session secrets are encrypted using Windows DPAPI (`DataProtectionScope.CurrentUser`) or user-bound AES-256-GCM. Plaintext secrets are never written to disk or logs.
3. **NTFS Safety**: The NTFS File Provider validates all paths, rejecting Win32 reserved device names (`CON`, `PRN`, `AUX`, `NUL`, `COM1-9`, `LPT1-9`), Alternate Data Streams (`:`), and paths with trailing dots or spaces.
4. **Relocatable Scripts**: All scripts compute paths relative to `$PSScriptRoot`. No absolute paths from a developer's machine are used.

---

## 2. Supported Compilation & Runtime Baselines

- **Java Runtime Baseline**:
  - Minimum Runtime: **Java 21 LTS**
  - Supported: **Java 21 LTS**, **Java 25 LTS**
  - Compiler Baseline: `maven.compiler.release = 21` (Portable core compatibility = Java 17+)
- **Flutter & Native Toolchain**:
  - Flutter SDK: **3.24.0+** (Channel stable)
  - CMake: **3.20+**
  - Visual Studio: **Visual Studio 2022** (v143 toolset) with **Desktop development with C++** workload.

---

## 3. Native Windows Integrations

The Windows platform integration classes are located under `org.peerlink.windows.*`:

| Component | Class | Description |
|-----------|-------|-------------|
| **Credential Storage** | `WindowsCredentialStore` | DPAPI-backed encryption bound to Windows user profile. |
| **Filesystem Safety** | `WindowsNtfsFileProvider` | Enforces NTFS filename rules, ADS prevention, and sharing semantics. |
| **Explorer Integration** | `WindowsExplorerIntegration` | Shell item selection (`explorer.exe /select,"<path>"`), directory reveal, and context menu registration. |
| **Power Management** | `WindowsPowerManager` | Manages Win32 `SetThreadExecutionState` (`0x80000001`) during active transfers to prevent sleep/standby. |
| **Firewall Coordination** | `WindowsFirewallCoordinator` | Inspects and requests inbound Windows Defender Firewall rules for port 53317. |
| **Share Contract** | `WindowsShareContract` | Triggers Windows 10/11 Shell Share UI for file transfers. |
| **Action Center Notifications**| `WindowsNotificationManager` | WinRT Toast notification integration. |

---

## 4. IDE Workflow & Scripts Reference

All entry points are located in `windows\scripts\`. Each script uses paths relative to its own location, returns nonzero exit codes on error, and never deletes user data.

### Workflow Entry Points:

| Script | Purpose |
|--------|---------|
| `scripts\open-project.ps1` | Launches the Windows project in the user's IDE (VS Code, Antigravity IDE, or File Explorer). |
| `scripts\check-prerequisites.ps1` | Inspects the host machine for Java JRE/JDK, Maven, Flutter, Visual Studio C++, Git, and CMake. |
| `scripts\resolve-dependencies.ps1` | Resolves Maven dependencies (`pom.xml`) and Flutter dependencies (`pubspec.yaml`). |
| `scripts\build-windows.ps1` | Compiles the Windows Local Node daemon (`pom.xml`) and Flutter Windows desktop application. |
| `scripts\run-windows.ps1` | Starts the Local Node daemon on port 50051 and boots the Windows desktop UI. |
| `scripts\run-tests.ps1` | Executes JUnit 5 unit/integration tests and Flutter widget/IPC tests. |
| `scripts\open-visual-studio.ps1` | Opens the generated CMake Visual Studio solution for native C++ runner debugging. |
| `scripts\collect-diagnostics.ps1` | Gathers OS version, Java runtime, network port availability, firewall status, DPAPI status, and logs. |
| `scripts\package-windows.ps1` | Packages the application into a relocatable release directory with SHA-256 manifest. |

---

## 5. Development & Debugging Separation

> [!IMPORTANT]
> **Visual Studio is NOT a Flutter Dart IDE replacement.**
>
> - **Dart / Flutter UI Development**: Use **VS Code**, **Android Studio**, or **Antigravity IDE** with the Flutter & Dart extensions. Open the `windows\app\flutter\` directory.
> - **Native Win32 Runner Debugging**: Use **Visual Studio 2022** exclusively for debugging C++ native host code (`windows\app\flutter\windows\runner\main.cpp`, `flutter_window.cpp`, `win32_window.cpp`, and native platform channel plugins). Open via `scripts\open-visual-studio.ps1`.
