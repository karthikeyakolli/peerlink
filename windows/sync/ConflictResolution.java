package org.peerlink.core.sync;

/**
 * Available conflict resolution strategies surfaced to the user.
 *
 * <p>All options:
 * <ul>
 *   <li>KEEP_LOCAL — discard remote; local wins.</li>
 *   <li>KEEP_REMOTE — discard local; remote wins.</li>
 *   <li>KEEP_BOTH — preserve both as separate objects (both renamed with disambiguation suffix).</li>
 *   <li>MERGE — attempt content-level merge (only for supported text formats).</li>
 *   <li>DEFERRED — no decision yet; sync is paused for this object until resolved.</li>
 * </ul>
 */
public enum ConflictResolution {
    KEEP_LOCAL,
    KEEP_REMOTE,
    KEEP_BOTH,
    MERGE,
    DEFERRED
}