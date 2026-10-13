package org.peerlink.core.platform.android;

import org.peerlink.core.android.AndroidStorageAbstraction.ContentResolverBridge;
import org.peerlink.core.model.ContentHash;
import org.peerlink.core.safety.InboundSafetyPipeline;
import org.peerlink.core.safety.InboundSafetyPipeline.PipelineResult;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Path;
import java.util.*;

/**
 * Handles Android ACTION_SEND and ACTION_SEND_MULTIPLE share intents.
 *
 * Invariants:
 * - Content URIs (content://...) are resolved safely via ContentResolverBridge.
 * - Share ingestion NEVER bypasses safety checks, identity, or resource limits.
 * - Ingested streams are routed strictly through the authoritative InboundSafetyPipeline:
 *   quarantine staging, hash verification, bomb inspection, malware scanning,
 *   and non-executable commit.
 */
public final class AndroidShareIntentIngestor {

    public static final String ACTION_SEND = "android.intent.action.SEND";
    public static final String ACTION_SEND_MULTIPLE = "android.intent.action.SEND_MULTIPLE";
    public static final long DEFAULT_MAX_SHARE_BYTES = 50 * 1024 * 1024L; // 50 MB per shared item

    public record ShareItemResult(
            String uri,
            String displayName,
            boolean success,
            String reason,
            Path committedPath
    ) {}

    public record ShareIngestResult(
            boolean allSucceeded,
            int totalItems,
            int succeededItems,
            int failedItems,
            List<ShareItemResult> itemResults
    ) {}

    private final ContentResolverBridge contentResolver;
    private final InboundSafetyPipeline safetyPipeline;
    private final long maxShareItemBytes;

    public AndroidShareIntentIngestor(ContentResolverBridge contentResolver, InboundSafetyPipeline safetyPipeline) {
        this(contentResolver, safetyPipeline, DEFAULT_MAX_SHARE_BYTES);
    }

    public AndroidShareIntentIngestor(ContentResolverBridge contentResolver,
                                      InboundSafetyPipeline safetyPipeline,
                                      long maxShareItemBytes) {
        this.contentResolver = Objects.requireNonNull(contentResolver, "contentResolver must not be null");
        this.safetyPipeline = Objects.requireNonNull(safetyPipeline, "safetyPipeline must not be null");
        this.maxShareItemBytes = maxShareItemBytes;
    }

    /**
     * Ingests a share intent safely into destination directory.
     */
    public ShareIngestResult ingestIntent(String action,
                                          String mimeType,
                                          List<String> contentUris,
                                          String senderPeerId,
                                          Path destinationDir) {
        if (!ACTION_SEND.equals(action) && !ACTION_SEND_MULTIPLE.equals(action)) {
            ShareItemResult err = new ShareItemResult(null, null, false, "Unsupported share intent action: " + action, null);
            return new ShareIngestResult(false, 0, 0, 1, List.of(err));
        }

        if (contentUris == null || contentUris.isEmpty()) {
            ShareItemResult err = new ShareItemResult(null, null, false, "No content URIs provided in share intent", null);
            return new ShareIngestResult(false, 0, 0, 1, List.of(err));
        }

        List<String> targetUris = ACTION_SEND.equals(action)
                ? List.of(contentUris.get(0))
                : contentUris;

        List<ShareItemResult> results = new ArrayList<>();
        int successCount = 0;
        int failureCount = 0;

        for (int i = 0; i < targetUris.size(); i++) {
            String uri = targetUris.get(i);
            ShareItemResult itemRes = processSingleUri(uri, i, senderPeerId, destinationDir);
            results.add(itemRes);
            if (itemRes.success()) {
                successCount++;
            } else {
                failureCount++;
            }
        }

        boolean allSucceeded = failureCount == 0 && successCount > 0;
        return new ShareIngestResult(allSucceeded, targetUris.size(), successCount, failureCount, Collections.unmodifiableList(results));
    }

    private ShareItemResult processSingleUri(String uri, int index, String senderPeerId, Path destinationDir) {
        if (uri == null || uri.isBlank()) {
            return new ShareItemResult(uri, "unknown", false, "Content URI cannot be blank", null);
        }

        // 1. Permission check
        if (!contentResolver.checkReadPermission(uri)) {
            return new ShareItemResult(uri, "unknown", false, "PERMISSION_DENIED: Read permission not granted for URI", null);
        }

        // 2. Resolve display name and sanitize
        String rawDisplayName = contentResolver.getDisplayName(uri);
        String displayName = (rawDisplayName != null && !rawDisplayName.isBlank())
                ? rawDisplayName
                : "shared_item_" + index + ".dat";

        // Sanitize path traversal / null bytes
        if (displayName.contains("\0") || displayName.contains("..") || displayName.startsWith("/") || displayName.startsWith("\\")) {
            return new ShareItemResult(uri, displayName, false, "MALICIOUS_FILENAME: Filename contains path traversal or null byte", null);
        }

        // 3. Read stream with bounded size limit
        byte[] payloadBytes;
        try (InputStream in = contentResolver.openInputStream(uri)) {
            if (in == null) {
                return new ShareItemResult(uri, displayName, false, "InputStream returned null for URI", null);
            }
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            byte[] buf = new byte[8192];
            long totalRead = 0;
            int r;
            while ((r = in.read(buf)) != -1) {
                totalRead += r;
                if (totalRead > maxShareItemBytes) {
                    return new ShareItemResult(uri, displayName, false,
                            "RESOURCE_LIMIT_EXCEEDED: Shared content size (" + totalRead + " bytes) exceeds maximum " + maxShareItemBytes + " bytes",
                            null);
                }
                baos.write(buf, 0, r);
            }
            payloadBytes = baos.toByteArray();
        } catch (IOException e) {
            return new ShareItemResult(uri, displayName, false, "I/O error reading content URI: " + e.getMessage(), null);
        }

        // 4. Compute cryptographic content hash
        ContentHash expectedHash = ContentHash.computeSha256(payloadBytes);

        // 5. Route through InboundSafetyPipeline
        try {
            PipelineResult pipelineRes = safetyPipeline.processInboundFile(
                    payloadBytes,
                    displayName,
                    expectedHash,
                    senderPeerId != null ? senderPeerId : "android_share_intent",
                    destinationDir
            );

            if (pipelineRes.committed()) {
                return new ShareItemResult(uri, displayName, true, "Committed cleanly to destination", pipelineRes.finalPath());
            } else {
                String detail = String.join("; ", pipelineRes.details());
                return new ShareItemResult(uri, displayName, false, "Safety rejection (" + pipelineRes.decision() + "): " + detail, null);
            }
        } catch (Exception e) {
            return new ShareItemResult(uri, displayName, false, "Safety pipeline processing exception: " + e.getMessage(), null);
        }
    }
}
