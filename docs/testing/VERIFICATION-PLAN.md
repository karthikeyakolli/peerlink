# PeerLink — Verification and Quality Plan

## 1. Core rule

> **No feature is complete because the AI says it is complete. It is complete when executable evidence satisfies the phase acceptance criteria.**

## 2. Test layers

1. Static/build checks
2. Unit tests
3. Component tests
4. Two-node local integration
5. Real LAN tests
6. Internet/NAT/TURN tests
7. Filesystem fault tests
8. Security tests
9. Cross-platform tests
10. Release tests

## 3. Two-node harness

Every major P2P feature must work with two isolated nodes on one developer machine before using physical machines.

Each node has:

- independent identity
- SQLite database
- filesystem root
- network ports
- logs

## 4. Network fault matrix

Test:

- packet loss
- delay
- reordering
- duplication
- disconnect
- reconnection
- NAT changes
- firewall restrictions
- UDP unavailable
- relay unavailable
- Supabase unavailable
- network handoff

## 5. Filesystem fault matrix

Test:

- file disappears
- source changes during transfer
- target already exists
- long path
- Unicode name
- permission denied
- file locked
- disk full
- sparse file
- symlink/junction/reparse behavior
- case sensitivity difference
- timestamp precision difference

## 6. Transfer tests

For every transfer capability verify:

- hash correctness
- resume behavior
- pause/cancel
- retry
- crash recovery
- unknown outcome
- duplicate handling
- atomic commit
- quarantine-before-commit where policy requires

## 7. Sync tests

Minimum conflict matrix:

```text
A change / B unchanged
A unchanged / B change
A and B same change
A and B concurrent change
A rename / B delete
A delete / B modify
A move / B modify
offline divergence
reconnect convergence
```

## 8. Security tests

- unauthorized peer
- invalid identity
- fingerprint mismatch
- replay
- malformed frame
- oversized frame
- excessive stream creation
- path traversal
- symlink escape attempt
- archive bomb
- malicious payload handling
- scanner unavailable
- expired share
- revoked peer/share
- invalid capability
- local IPC unauthorized client

## 9. Android tests

Use both emulator and physical device.

Test:

- visible app
- background transition
- OS kill/restart
- user-initiated transfer
- scheduled work
- permission denial
- SAF URI persistence
- battery constraints
- network change
- Wi-Fi Direct/nearby adapters when enabled

## 10. Cross-platform matrix

Minimum release combinations:

| Scenario | Windows | Linux | macOS | Android |
|---|---:|---:|---:|---:|
| Build | ✓ | ✓ | ✓ | ✓ |
| Identity | ✓ | ✓ | ✓ | ✓ |
| Pairing | ✓ | ✓ | ✓ | ✓ |
| SEND | ✓ | ✓ | ✓ | ✓ |
| Resume | ✓ | ✓ | ✓ | ✓ |
| ACCESS | ✓ | ✓ | ✓ | ✓ |
| SYNC | ✓ | ✓ | ✓ | ✓ |
| BACKUP | ✓ | ✓ | ✓ | ✓ |
| Sharing | ✓ | ✓ | ✓ | ✓ |
| Clipboard | ✓ | ✓ | ✓ | platform-dependent |
| Background behavior | desktop | desktop | desktop | OS-constrained |
| OS integration | native | native | native | Android-native |

## 11. Release gates

P0 = data loss/security-critical failure.

P1 = major correctness/interoperability failure.

Do not release with open P0/P1 defects.

Every phase must produce:

- automated test output
- relevant logs
- screenshots/video where UI behavior matters
- known limitations
- reproducible test command
