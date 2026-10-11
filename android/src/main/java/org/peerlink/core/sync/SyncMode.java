package org.peerlink.core.sync;

/**
 * Sync mode controlling directionality and destructiveness.
 *
 * <ul>
 *   <li>BIDIRECTIONAL - changes flow both ways; conflicts detected and surfaced.</li>
 *   <li>ONE_WAY_REPLICATION - source changes are pushed to destination; destination-only
 *       changes are ignored (not deleted).</li>
 *   <li>RECEIVE_ONLY_IMPORT - local device only receives; never pushes local changes.</li>
 *   <li>EXACT_MIRROR - destructive; destination is made to exactly match source,
 *       including deletions. Requires explicit opt-in confirmation.</li>
 * </ul>
 */
public enum SyncMode {
    BIDIRECTIONAL,
    ONE_WAY_REPLICATION,
    RECEIVE_ONLY_IMPORT,
    EXACT_MIRROR    // explicit destructive mode — requires confirmation
}