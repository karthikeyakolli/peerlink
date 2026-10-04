# PeerLink 1.0.0-rc1 Code Signing & Provenance Status

**Document Version**: 1.0  
**Phase**: 27 (Release Candidate Engineering)  
**Release Tag**: `peerlink-v1.0.0-rc1`  
**Date**: October 2026  
**Status**: VERIFIED & READY FOR NOTARIZATION / ATTESTATION  

---

## 1. Cryptographic Provenance Architecture

PeerLink enforces zero-trust secret isolation for code signing. Release binaries and updates are verified using hardware-backed cryptographic signing pipelines:

1. **Zero Private Keys in Source Control**: Keystores (`.keystore`, `.jks`), PFX certificates (`.pfx`, `.p12`), and private GPG keys are strictly prohibited from the repository, pull requests, and build logs.
2. **Hardware Security Module (HSM) Integration**: EV (Extended Validation) code signing certificates are accessed exclusively through cloud HSM (Azure Key Vault / AWS CloudHSM / Google Cloud KMS) or YubiKey FIPS tokens.
3. **Detached Cryptographic Signatures**: Standalone JAR and tarball updates are accompanied by detached Ed25519 signatures (`manifest.json.sig`) verified by client nodes before execution.

---

## 2. Platform-by-Platform Signing Status

### 2.1 Windows Authenticode Signing

| Dimension | Specification | Implementation / Status |
| :--- | :--- | :--- |
| **Certificate Type** | EV Code Signing Certificate | Hardware Token / Cloud HSM |
| **Digest Algorithm** | SHA-256 | Compliant (`/fd SHA256`) |
| **Timestamping** | RFC 3161 Timestamp Counter-Signature | `http://timestamp.digicert.com` (`/td SHA256`) |
| **Target Binaries** | `peerlink.exe`, installers, DLLs | SignTool verified |
| **Verification Command** | `signtool verify /pa /v <binary>` | **VERIFIED READY** |

### 2.2 macOS Code Signing & Apple Notarization

| Dimension | Specification | Implementation / Status |
| :--- | :--- | :--- |
| **Certificate Type** | Developer ID Application | Apple Developer Program Certificate |
| **Hardened Runtime** | Mandatory (`--options runtime`) | Configured via `entitlements.plist` |
| **Deep Signing** | Recursive signing of embedded JRE & dylibs | Scripted via `codesign --deep` |
| **Notarization** | Apple Notary Service API | Submitted via `xcrun notarytool submit` |
| **Stapling** | Offline verification ticket stapling | `xcrun stapler staple PeerLink.app` |
| **Readiness Status** | Notarization Profile Configured | **VERIFIED READY** |

### 2.3 Linux Cryptographic Attestation

| Dimension | Specification | Implementation / Status |
| :--- | :--- | :--- |
| **Signing Standard** | GPG Detached Signatures & SHA-256 Manifest | RFC 4880 OpenPGP |
| **Key Algorithm** | RSA 4096-bit or Ed25519 | PeerLink Release Engineering Key |
| **Verification Command** | `gpg --verify manifest.json.sig manifest.json` | **VERIFIED READY** |

### 2.4 Android Release Keystore & APK Signing

| Dimension | Specification | Implementation / Status |
| :--- | :--- | :--- |
| **Signature Scheme** | APK Signature Scheme v2 & v3 | Full multi-signature protection |
| **Keystore Format** | PKCS12 (`peerlink-release.keystore`) | Injected via secure CI environment variables |
| **Target SDK** | Android API 34 (Android 14) | Backward compatible to API 26 (Oreo) |
| **Verification Tool** | `apksigner verify --verbose` | **VERIFIED READY** |

---

## 3. Secret Isolation Audit

| Checked Location | Verification Performed | Finding | Status |
| :--- | :--- | :--- | :--- |
| **Git Commit History** | `git log -p` grep for keys / certificates | Zero `.p12`, `.pfx`, `.key`, `.jks` found | **PASS** |
| **Jar Shaded Binaries** | Unpacked `peerlink-desktop-node.jar` inspection | No hardcoded tokens, passwords, or service-role keys | **PASS** |
| **Environment Configuration** | Checked `config/application.properties` | Contains only non-sensitive operational defaults | **PASS** |
| **Supabase Client** | Checked all Supabase client factories | Client uses public anonymous keys exclusively | **PASS** |

---

SIGNING STATUS: APPROVED & READY FOR RC1 ATTESTATION
