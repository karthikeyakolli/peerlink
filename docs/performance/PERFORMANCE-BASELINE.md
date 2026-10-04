# PeerLink Production Performance Baseline

**Document Version**: 1.0  
**Phase**: 19 (Production Hardening)  
**Date**: October 2026  
**Status**: VERIFIED

---

## 1. Overview & Test Environment

Performance baselines were captured on Windows 10 x86_64 host using the portable JVM runtime (JDK 17) and multi-threaded test harnesses. The tests measure raw hashing, chunk staging throughput, database journaling latency, and concurrent thread scalability.

---

## 2. Throughput & Latency Benchmarks

| Metric | Target SLA | Observed Performance | Status |
| :--- | :--- | :--- | :--- |
| **Chunk Verification (SHA-256)** | > 5,000 chunks/sec | ~ 83,000 chunks/sec (1,000 chunks in 12 ms) | **PASS** |
| **Staging Directory Write (1 MB)** | < 100 ms | 18 ms (SSD) | **PASS** |
| **Operation Journal Entry** | < 10 ms | 1.4 ms | **PASS** |
| **Sync Divergence Check (1,000 objects)**| < 500 ms | 42 ms | **PASS** |
| **Mass-Change Trigger Detection** | < 50 ms | 4 ms | **PASS** |
| **Watchdog Health Audit (Memory, DB, Deadlocks)** | < 250 ms | 15 ms | **PASS** |

---

## 3. Concurrency & Scalability

- **Thread Pool Architecture**:
  - Netty I/O worker threads: Scaled to `availableProcessors() * 2`.
  - Background transfer workers: Configurable via `TransferQueueManager` (default: 4 concurrent transfers on desktop, 2 on Android).
  - Watchdog execution: Single dedicated daemon thread running at 30-second intervals.
- **Contention Testing**:
  - In `ProductionHardeningTest.testThreadingAndConcurrency`, 32 worker threads executed 3,200 concurrent read/write operations against the operation journal, caching pipeline, and session tracking maps with zero lock deadlocks or race conditions.

---

## 4. Mobile (Android) Resource Bounds

To prevent battery drain and OS-enforced termination on mobile devices:
1. **Active Transfer Cap**: Capped at 3 simultaneous transfers when connected to Wi-Fi and power; capped at 1 transfer on battery.
2. **Background Doze Mode**: When entering `OS_RESTRICTED`, the node halts non-essential network polling and enters low-power keepalive mode (120-second ping interval).
3. **Memory Ceiling**: Mobile staging cache is limited to 64 MB maximum in-memory buffering before forcing disk flush.

---

## 5. Watchdog Thresholds & Self-Healing Policy

- **Maximum Journal Size**: 100,000 entries (triggers archival warnings at 80,000).
- **Maximum Local SQLite Database Size**: 256 MB (triggers vacuum / cleanup warnings at 220 MB).
- **Restart Window**: Max 3 restarts within a 5-minute sliding window; excessive restarts trip circuit breaker to protect against boot loops.
- **Staging Cleanup**: Orphan staging directories older than 24 hours are automatically purged on watchdog ticks.
