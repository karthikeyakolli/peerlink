# PeerLink Production Incident Response Manual

**Document**: `docs/operations/INCIDENT-RESPONSE.md`  
**Version**: 1.0.0  
**Target Release**: PeerLink 1.0.0-GA  
**Audience**: Security Operations Center (SOC), SRE, Incident Commanders  

---

## 1. Severity Classification Framework

| Severity Level | Definition | Impact Scope | SLA Target (Response / Mitigate) |
|---|---|---|---|
| **SEV-0 (Critical Emergency)** | Security exploit, active cryptographic key compromise, unauthorized remote execution, or widespread unrecoverable data loss. | All active network nodes | **Immediate (< 15 min / < 1 hour)** |
| **SEV-1 (Major Outage)** | Cloud control plane complete outage, coturn relay network failure preventing all NAT traversal, or high crash rate (> 1%) on release build. | Global connectivity / large cohort | **< 30 min / < 4 hours** |
| **SEV-2 (Degraded Operation)** | Partial regional relay latency, localized sync stalling, false-positive safety hold triggers, or non-fatal platform bug. | Subset of users / specific OS | **< 2 hours / < 24 hours** |
| **SEV-3 (Minor Disruption)** | Cosmetic UI flaw, telemetry anomaly, non-blocking edge case documentation error. | Isolated / edge-case | **< 1 business day / next patch** |

---

## 2. Incident Response Workflow

```
[1. DETECT] ──► [2. TRIAGE] ──► [3. CONTAIN] ──► [4. ERADICATE] ──► [5. RECOVER] ──► [6. POST-MORTEM]
      │              │               │                 │                 │                  │
 Prometheus /   Classify SEV    Isolate Node /     Root Cause       Replay Logs /      Blameless
  User Report   Assign Lead    Degraded P2P Mode   Patch Code       Verify Hashes      Report in 48h
```

### Phase 1: Detection & Alerting
* Automated alerts triggered via Prometheus Alertmanager, Supabase Health Metrics, or GitHub Security Advisories.
* Escalation alerts dispatched to PagerDuty rotation.

### Phase 2: Triage & Incident Command
* Establish Incident Bridge.
* Assign **Incident Commander (IC)**, **Communications Lead**, and **Technical Investigation Lead**.
* Determine impacted subsystems: P2P Transport, Local Storage, Cloud Signaling, or Key Management.

### Phase 3: Immediate Containment
* If cloud signaling is degraded: Force client nodes into **Degraded Local-First Mode** (mDNS / Direct IP LAN).
* If a compromised node is detected: Revoke peer ID in `device_registry` and broadcast revocation tombstone.
* If a critical flaw is present in a release: Trigger immediate rollback or halt distribution channels.

### Phase 4: Eradication & Root Cause Analysis
* Reproduce in isolated testbed.
* Perform root cause diagnosis; review diffs and telemetry.
* Prepare minimal deterministic patch; execute full regression test suite.

### Phase 5: Safe Recovery & Verification
* Deploy hotfix release or apply database migration.
* Execute clean smoke test and data-safety hash verification.
* Re-enable full cross-network connectivity and monitor error rates for 2 hours.

### Phase 6: Post-Mortem & Blameless Review
* Publish comprehensive Post-Mortem within 48 hours.
* Track preventive action items in engineering issue tracker.

---

## 3. Dedicated Failure Runbooks

### Runbook A: Cloud Control Plane (Supabase) Outage
* **Symptoms**: Clients log `SupabaseOutageException`, Realtime WebSocket disconnected, signaling fails across WAN.
* **Inherent Safeguard**: PeerLink is designed with local-first offline survivability. Local LAN transfers, direct IP connections, and cached trusted peers continue operating without interruption.
* **Procedure**:
  1. Verify external Supabase status dashboard.
  2. Verify client nodes trip internal `CircuitBreaker` (transitions to `OPEN` state after 3 consecutive failures).
  3. Confirm clients continue local discovery via UDP mDNS (224.0.0.251:5353) without crashing.
  4. Once cloud recovers, client circuit breaker automatically half-opens after 15s and restores cloud presence.

### Runbook B: coturn Relay Cluster Failure
* **Symptoms**: Symmetric NAT peers experience transfer timeouts; direct LAN peers unaffected.
* **Procedure**:
  1. Inspect coturn process metrics: `systemctl status coturn`.
  2. If overloaded or hung:
     ```bash
     systemctl restart coturn
     tail -n 100 /var/log/coturn/turnserver.log
     ```
  3. Check TLS certificate expiration on port 5349:
     ```bash
     openssl s_client -connect turns.peerlink.io:5349 -showcerts
     ```
  4. If primary cluster is degraded, DNS failover to secondary relay cluster (e.g. `turn-eu.peerlink.io`).

### Runbook C: Compromised Peer / Key Revocation Incident
* **Symptoms**: A user reports a stolen laptop or compromised private key.
* **Procedure**:
  1. Immediate Revocation via Local Node:
     * User invokes Revoke Device in UI or CLI:
       ```bash
       peerlink-node --revoke-peer <PEER_ID>
       ```
  2. Active sessions with the compromised peer are cut immediately.
  3. Public key is added to local cryptographic blacklist in `device_identity`.
  4. Supabase control plane flags `is_revoked = TRUE` in `public.device_registry`.
  5. The compromised peer's tokens are invalidated in GoTrue auth.

### Runbook D: Mass Deletion / Ransomware Protective Halt
* **Symptoms**: SyncEngine halts with `SafetyHold: Deletion threshold exceeded`.
* **Procedure**:
  1. Do NOT bypass safety hold automatically.
  2. Review pending deletions displayed in client UI or logs:
     ```
     SELECT * FROM operations WHERE operation_type = 'OP_DELETE' AND status = 'STATUS_PENDING';
     ```
  3. If legitimate (user intended bulk cleanup): User explicitly clicks "Approve Bulk Deletion".
  4. If malicious/accidental: User clicks "Revert / Restore from Local Snapshot".

---

## 4. Security Disclosure & Escalation Contacts

* **Security Email**: `security@peerlink.io`
* **PGP Key ID**: `0x9B2C4E7F1A83204D`
* **Fingerprint**: `4A8E 2F1C 890B C47A E912 3456 9B2C 4E7F 1A83 204D`
* **Bug Bounty / Vulnerability Policy**: RFC 9116 compliant security.txt hosted at `https://peerlink.io/.well-known/security.txt`.
* **Emergency Response On-Call**: +1 (555) 019-7337 (Tier-1 SRE Incident Commander)
