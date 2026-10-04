# PeerLink Production Rollback Procedure

**Document**: `docs/operations/ROLLBACK.md`  
**Version**: 1.0.0  
**Target Release**: PeerLink 1.0.0-GA  
**Audience**: Release Engineering, Platform SRE, System Administrators  

---

## 1. Rollback Policy & Invariants

PeerLink adheres to strict engineering invariants to ensure rollbacks are safe, predictable, and non-destructive:

1. **Additive Database Schema Guarantee**:
   * All database migrations across Schema v1, v2, and v3 are strictly additive (`CREATE TABLE IF NOT EXISTS`, nullable column additions).
   * Schema v3 database files can be safely read and operated by previous release candidates without corruption.
2. **Zero User Data Loss Invariant**:
   * Rolling back the application binaries or services must **never** delete user files, synchronization directories, or local key pairs.
3. **Deterministic Artifact Preservation**:
   * All release binaries, packages, and Docker containers are immutably tagged in the release registry. A rollback simply switches the active pointer to the prior verified tag (`peerlink-v1.0.0-rc1` / commit `5c9a8c1`).

---

## 2. Decision Matrix: When to Trigger Rollback

| Scenario | Trigger Condition | Action |
|---|---|---|
| **Critical Startup Crash** | Daemon fails to start on > 2% of nodes within 1 hour of upgrade | **Immediate Full Rollback** |
| **Data Corruption / Sync Loss** | Any unhandled bug causing file truncation or metadata loss | **Immediate Emergency Rollback** |
| **P2/P3 Non-Fatal Defect** | Usability flaw, slow relay negotiation, UI cosmetic bug | **Hotfix Forward (No Rollback)** |
| **Control Plane Incompatibility** | Client cannot authenticate to Supabase after cloud deploy | **Cloud Configuration Rollback** |

---

## 3. Step-by-Step Rollback Procedures

### 3.1 Linux Daemon Rollback (Systemd)

1. **Stop the Active Daemon**:
   ```bash
   sudo systemctl stop peerlink-node
   ```
2. **Backup Current Working State**:
   ```bash
   sudo cp -r /opt/peerlink /opt/peerlink.backup-1.0.0
   sqlite3 ~/.peerlink/peerlink_local.db "VACUUM INTO '~/.peerlink/backups/rollback_pre_state.db'"
   ```
3. **Restore Prior Verified Binary (`1.0.0-rc1`)**:
   ```bash
   sudo cp /opt/peerlink.releases/1.0.0-rc1/peerlink-desktop-node.jar /opt/peerlink/lib/
   ```
4. **Verify File Permissions & Ownership**:
   ```bash
   sudo chown -R peerlink:peerlink /opt/peerlink
   ```
5. **Restart Daemon & Check Status**:
   ```bash
   sudo systemctl start peerlink-node
   sudo systemctl status peerlink-node
   journalctl -u peerlink-node -n 50 --no-pager
   ```
6. **Verify Health**:
   ```bash
   grpcurl -plaintext 127.0.0.1:50051 org.peerlink.protocol.v1.DesktopLocalNodeService/GetStatus
   ```

---

### 3.2 Windows Desktop Rollback

1. **Stop the Running Process**:
   * In PowerShell:
     ```powershell
     Stop-Process -Name "java" -ErrorAction SilentlyContinue
     ```
2. **Preserve Configuration & SQLite Database**:
   * The local database resides at `%USERPROFILE%\.peerlink\peerlink_local.db`. It is untouched by binary replacement.
3. **Swap Application Bundle**:
   * Replace `C:\Program Files\PeerLink\lib\peerlink-desktop-node.jar` with the archived `1.0.0-rc1` JAR.
4. **Launch Prior Version**:
   * Run `bin\peerlink-node.bat` or launch the desktop UI.
5. **Validate Startup Log**:
   * Confirm log line: `LocalSqliteStorage ready at ... (schema v3)`.

---

### 3.3 macOS Application Rollback

1. **Quit PeerLink**:
   * `killall PeerLink` or Cmd+Q.
2. **Replace Application**:
   * Move `/Applications/PeerLink.app` to `/Applications/PeerLink-1.0.0-defective.app`.
   * Copy `dist/macos/peerlink-1.0.0-rc1/PeerLink.app` to `/Applications/PeerLink.app`.
3. **Clear Quarantine Attribute**:
   ```bash
   xattr -cr /Applications/PeerLink.app
   ```
4. **Launch and Verify**:
   ```bash
   open /Applications/PeerLink.app
   ```

---

### 3.4 Android APK Rollback

1. **Side-by-Side Installation / Release Channel**:
   * If distributed via internal pilot MDM or Direct APK:
     * Due to Android package manager downgrade protection, standard package installation will block lower `versionCode`.
     * Execute rollback APK with `-d` (allow version downgrade) via ADB:
       ```bash
       adb install -d -r peerlink-1.0.0-rc1.apk
       ```
2. **Managed App Store (Google Play / F-Droid)**:
   * Revert the release track to the prior build artifact or upload a fast-forward patch build with incremented `versionCode` containing the reverted codebase.

---

### 3.5 Cloud Control Plane (Supabase) Rollback

1. **Revert Edge Functions & Realtime Settings**:
   * Checkout prior stable commit:
     ```bash
     git checkout 5c9a8c1 -- supabase/
     ```
2. **Reapply Stable RLS Policies**:
   * If an RLS policy mutation caused access issues, re-run the canonical production RLS migration defined in [`PRODUCTION-OPERATIONS.md`](file:///c:/Users/WIN_10/.gemini/antigravity/scratch/New%20folder/PeerLink/docs/operations/PRODUCTION-OPERATIONS.md#L45).
3. **Database Schema Rollback Policy**:
   * Never drop columns or tables in production during a rollback. Since all schema additions are backward-compatible, tables remain valid for both V1.0.0 and V1.0.0-rc1.

---

## 4. Post-Rollback Verification Checklist

- [ ] Node daemon process is running cleanly without restart loops.
- [ ] Local gRPC IPC server is accepting client commands on port 50051.
- [ ] Database integrity check returns `ok` (`PRAGMA integrity_check;`).
- [ ] Cryptographic Ed25519 identity key and Peer ID are intact.
- [ ] Existing paired devices remain listed and trusted.
- [ ] Active and paused transfers resume normally.
- [ ] No residual lock files or temp files remaining in staging directory.
- [ ] Incident commander confirms notification to stakeholders.
