package org.peerlink.core.sharing;

import org.peerlink.protocol.v1.ShareAuditEvent;

public record ShareAuditRecord(
        long timestampUtcMs,
        String shareId,
        String actorPeerId,
        ShareAuditEvent event,
        String operationId,
        String detail
) {}