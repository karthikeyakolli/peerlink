# Smart Operations & Deterministic Scheduling

## Feature Set

- **Smart Bundles:** Grouping related files with dependency metadata and atomic commit.
- **Transfer Recipes:** Reusable templates defining compression, exclusions, malware policies, and network rules.
- **Smart Drop Zones:** Watched filesystem folders that trigger automated recipes upon file arrival.
- **Send Later / Send Again:** Deterministic scheduled operations.

## The Cardinal Scheduling Rule

> **CRITICAL INVARIANT:**  
> Scheduled actions must use **Object References (`ObjectIdentity`)**, not brittle filesystem paths.  
> **Never replay stale filesystem paths blindly.**

### Current-State Revalidation
Before any scheduled operation is executed:
1. `ObjectIdentity` is resolved against the live object registry to obtain the current path (even if the file has been moved or renamed across folders).
2. The current file content hash is recomputed and verified against `expectedContentHash`.
3. Pre-conditions are verified:
   - Target peer connectivity.
   - Dependency completion (`dependsOnOperationId`).
   - Network policy (e.g., `REQUIRE_UNMETERED`).
   - Power policy (e.g., `REQUIRE_CHARGING`).
4. Duplicate execution is strictly blocked using operation idempotency keys.