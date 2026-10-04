# Connection Diagnostics & Path Selection Rationale

## 1. Purpose
Every peer-to-peer connection attempt produces a structured `ConnectionDiagnostics` record. This allows users, administrators, and developers to immediately understand:
1. Whether a direct path succeeded.
2. If direct failed, exactly why it failed.
3. Whether a relay was used.
4. Concrete rationale for why relay was selected.

---

## 2. Diagnostics Report Format
```
=== PeerLink Connection Diagnostics ===
Timestamp: 2026-10-02T22:50:00Z
Outcome: RELAY_USED
Selected Path: Pair[RELAY:198.51.100.1:3478 <-> HOST:172.16.0.9:54321, state=SUCCEEDED, rtt=45ms, prio=1879048191]
Local Type: RELAY (198.51.100.1:3478)
Remote Type: HOST (172.16.0.9:54321)
Transport: UDP
Status: Relayed path via TURN coturn server.
Direct Failure Rationale: All direct host and STUN reflexive candidate pairs failed connectivity checks or timed out
Why Relay Selected: Direct path unavailable due to symmetric NAT or firewall packet drop
Connection Quality: Quality[rtt=45ms, loss=2.0%, jitter=15ms, score=85/100]
Probe Event History:
  - Probing HOST pair 10.200.0.5:54321 -> 172.16.0.9:54321: TIMEOUT
  - Probing SRFLX pair 203.0.113.10:61234 -> 198.51.100.25:58765: DROPPED
  - Falling back to relayed path: Pair[RELAY <-> HOST]
========================================
```

---

## 3. Diagnostics Metrics Explained

| Metric | Meaning | Evaluation |
| :--- | :--- | :--- |
| `RoundTripTimeMs` (RTT) | Round-trip latency of probes | <10ms: Local LAN; 20-80ms: Regional WAN; >150ms: Long-distance |
| `PacketLossRate` | Ratio of lost probe packets | 0.0: Perfect; >0.05: Degraded network; 1.0: Complete failure |
| `JitterMs` | Variance in arrival latency | <5ms: Stable; >30ms: Network bufferbloat/congestion |
| `QualityScore` | Composite health metric (0-100) | Calculated from weighted combination of RTT (50%), Loss (30%), and Jitter (20%) |
