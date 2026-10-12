# PeerLink Phase 13 Verification Report: Access, Remote Browsing, and Sharing

**Date:** October 12, 2026  
**Status:** PASS (20 of 20 Tests Passed, 100% Assertion Success)  
**Execution Environment:** OpenJDK 25 (Java SE Pure Runtime) on Windows 11  
**Test Suite:** `Phase13StandaloneTestRunner` (`target/run-phase13-tests.ps1`)

---

## 1. Executive Summary

Phase 13 establishes the authorized remote browsing, search, preview, on-demand retrieval, bounded reads, safe destination staging, and cryptographic capability sharing boundary for PeerLink.

Key architectural rules enforced:
1. **Local Node Authority**: The Local Node is the sole authoritative decision-maker on every operation. Being a previously paired/trusted peer does **not** grant automatic access to any local file or folder.
2. **Untrusted Remote Input**: All remote paths are treated as untrusted input. Strict path validation rejects parent traversal (`..`), drive letter injection, UNC network paths, NTFS alternate data streams, and null-byte injection.
3. **Safe Previews & Executable Ban**: Previews are strictly bounded in size (max 64 KB) and completely forbidden for executable or script formats (`.exe`, `.sh`, `.bat`, etc.).
4. **Isolated Destination Handling**: Retrieved files are staged into temporary `.part` files, verified bit-for-bit against expected SHA-256 digests, promoted atomically, and stripped of execute permissions (`setExecutable(false)`). Received files are **never** auto-executed.
5. **Authoritative Revocation & One-Time Consumption**: Shares expire or revoke authoritatively at the host node. One-time shares allow idempotent resumes for network-interrupted transfers using the same `operationId`, while blocking any second operation.

---

## 2. Test Execution Results (20/20 PASS)

| Test ID | Test Scenario | Verified Behavior | Result |
|:---|:---|:---|:---:|
| **Test 01** | Share Creation & Registration | Local Node registers and retrieves share definitions with permissions and root boundaries. | **PASS** |
| **Test 02** | Unauthorized Paired Peer Rejection | Paired peer lacking registration in allowed peer set is rejected with `PEER_NOT_ALLOWED`. | **PASS** |
| **Test 03** | Expired Share Rejection | Requests initiated after expiration timestamp are rejected immediately with `SHARE_EXPIRED`. | **PASS** |
| **Test 04** | In-Flight Grace Period Window | Operations initiated prior to expiration are permitted to complete within the 30s grace window. | **PASS** |
| **Test 05** | Owner Revocation Enforcement | Revocation by share owner immediately blocks all subsequent operation attempts. | **PASS** |
| **Test 06** | One-Time Share Consumption & Retry | Consumed one-time share permits idempotent retry of identical `op_id` but blocks new `op_id`. | **PASS** |
| **Test 07** | Cryptographic Token Enforcement | Share configured with `requireToken=true` rejects requests lacking a valid token. | **PASS** |
| **Test 08** | Tampered Token Signature Rejection | Token with altered payload bytes or signature mismatch fails HMAC-SHA256 validation. | **PASS** |
| **Test 09** | Guest Isolation & Identity Claim | Guest token allows isolated access but cannot claim or escalate to trusted peer identity. | **PASS** |
| **Test 10** | Path Traversal Rejection | Rejects `..`, `C:\`, `\\UNC\admin$`, `file:$DATA`, and `file\0.jpg` deterministically. | **PASS** |
| **Test 11** | Safe Preview Rejects Executables | Attempts to preview `.exe` or `.sh` throw `UnsafePreviewException` immediately. | **PASS** |
| **Test 12** | Safe Preview Bounded Read | Previews are bounded to requested size, flagging `isTruncated=true` on large text files. | **PASS** |
| **Test 13** | Bounded File Reader On-Demand | `BoundedFileReader` streams up to 16 MB maximum, returning SHA-256 digest and truncation status. | **PASS** |
| **Test 14** | Safe Destination Non-Executable | `SafeDestinationHandler` writes to `.part` file, verifies hash, and commits non-executable. | **PASS** |
| **Test 15** | Destination Hash Mismatch Rejection | Staged file with mismatched SHA-256 throws `SecurityException` and purges corrupted temp file. | **PASS** |
| **Test 16** | Destination Path Traversal Escape | Rejects relative paths attempting to escape destination directory via `../../malicious`. | **PASS** |
| **Test 17** | Remote Folder Browser Pagination | Deterministic directory-first alphabetic sorting, cursor offset tracking, and page bounding. | **PASS** |
| **Test 18** | Remote Search Depth & Limits | Traversal bounded strictly by `maxDepth`, `maxResults`, deadline timeout, and cancellation. | **PASS** |
| **Test 19** | Archive Inspector Zip-Slip Alert | Inspects ZIP entry metadata in-memory, detecting Zip-Slip traversal (`../../evil.exe`). | **PASS** |
| **Test 20** | Live Two-Node Network Wire Exchange | Real TCP socket client/server exchange between Node A and Node B demonstrating wire browse, download, hash verification, and destination quarantine. | **PASS** |

---

## 3. Real Two-Node Network Request Demonstration (Test 20)

To fulfill the strict requirement that mock UI data alone does not pass, Test 20 demonstrates a live client-server exchange across TCP loopback sockets:

1. **Node B (Server)**:
   - Registers a shared directory containing `contract.pdf` and `notes.txt`.
   - Binds a real TCP `ServerSocket` on an ephemeral port.
   - Issues an authenticated capability token to `peer_node_a` with HMAC-SHA256 signature.
   - Reads request framing: `[command (UTF)] [shareId (UTF)] [relPath (UTF)] [token (UTF)]`.
   - Validates capability token, scope, and path containment authoritatively.
2. **Node A (Client)**:
   - Connects via TCP `Socket` to Node B.
   - Executes `BROWSE` request -> receives verified list of 2 files.
   - Executes `DOWNLOAD` request for `contract.pdf` -> receives SHA-256 digest and byte payload.
   - Passes received bytes to `SafeDestinationHandler` in quarantined downloads directory.
   - Staging verifies SHA-256 digest, atomically promotes to destination file, and strips executable bits.
   - File content matches bit-for-bit: `"Official PeerLink Node B Contract 2026"`.

---

## 4. Cross-Platform Parity Verification

The invariant synchronization suite was executed across all four OS directories (`windows/`, `linux/`, `macos/`, `android/`):
```text
==========================================================
 PeerLink Cross-Platform Parity Verification Tool
 Manifest:          shared-source/PARITY-MANIFEST.json
 Target Platforms:  windows, linux, macos, android
==========================================================
Total Invariant Files Checked: 561
Total Accidental Drift:        0
Status: PASS (Zero Accidental Drift; Perfect Invariant Parity)
==========================================================
```

All 561 invariant files, including the new `BoundedFileReader.java` and `SafeDestinationHandler.java`, are physically identical across the four OS project directories.