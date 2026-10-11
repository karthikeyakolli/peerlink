package org.peerlink.core.access;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.protocol.v1.*;

import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.FileSystemException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import static org.junit.jupiter.api.Assertions.*;

public class RemoteAccessTest {

    @TempDir
    Path tempDir;

    private Path shareRootDir;
    private ShareManager shareManager;
    private AccessAuditJournal auditJournal;
    private RemoteAccessCoordinator coordinator;

    private static final String PEER_ALICE = "peer_alice";
    private static final String PEER_BOB = "peer_bob";
    private static final String PEER_EVE = "peer_eve_unauthorized";
    private static final String SHARE_ID = "share_docs";
    private static final String SECRET = "super_secret_share_key_12345";

    @BeforeEach
    void setUp() throws IOException {
        shareRootDir = tempDir.resolve("shared_docs");
        Files.createDirectories(shareRootDir);

        shareManager = new ShareManager();
        auditJournal = new AccessAuditJournal();
        coordinator = new RemoteAccessCoordinator(shareManager, auditJournal);

        // Register default share allowing Alice and Bob
        ShareDefinition share = new ShareDefinition(
                SHARE_ID,
                "Shared Documents",
                shareRootDir,
                Set.of(PEER_ALICE, PEER_BOB),
                Set.of(AccessScope.ACCESS_SCOPE_FULL),
                System.currentTimeMillis(),
                0L, // no expiration
                SECRET
        );
        shareManager.registerShare(share);
    }

    @AfterEach
    void tearDown() {
        auditJournal.clear();
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 1. Folder Browse & Metadata
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testFolderBrowseAndMetadata() throws IOException {
        // Create files and subfolders
        Files.writeString(shareRootDir.resolve("readme.txt"), "Welcome to PeerLink Remote Access!");
        Files.writeString(shareRootDir.resolve("data.json"), "{\"status\": \"ok\"}");
        Path subDir = shareRootDir.resolve("subfolder");
        Files.createDirectories(subDir);
        Files.writeString(subDir.resolve("nested.md"), "# Nested Document");

        AccessRequest browseReq = AccessRequest.newBuilder()
                .setRequestId("req_browse_1")
                .setRequesterPeerId(PeerId.newBuilder().setValue(PEER_ALICE).build())
                .setTargetPeerId(PeerId.newBuilder().setValue(PEER_BOB).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_BROWSE)
                .setShareId(SHARE_ID)
                .setRelativePath("")
                .setMaxResults(10)
                .build();

        AccessResponse response = coordinator.handleAccessRequest(browseReq);
        assertTrue(response.getSuccess(), "Browse should succeed: " + response.getError().getHumanSummary());
        assertEquals(3, response.getItemsCount(), "Should list 3 entries (subfolder, data.json, readme.txt)");

        // Verify directory entry is sorted first
        RemoteObjectReference first = response.getItems(0);
        assertEquals(ObjectType.OBJECT_TYPE_DIRECTORY, first.getObjectType());
        assertEquals("subfolder", first.getDisplayName());

        // Test metadata query on a single file
        AccessRequest metaReq = AccessRequest.newBuilder()
                .setRequestId("req_meta_1")
                .setRequesterPeerId(PeerId.newBuilder().setValue(PEER_ALICE).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_METADATA)
                .setShareId(SHARE_ID)
                .setRelativePath("readme.txt")
                .build();

        AccessResponse metaResp = coordinator.handleAccessRequest(metaReq);
        assertTrue(metaResp.getSuccess());
        assertEquals(1, metaResp.getItemsCount());
        RemoteObjectReference fileRef = metaResp.getItems(0);
        assertEquals("readme.txt", fileRef.getDisplayName());
        assertEquals("text/plain", fileRef.getMimeType());
        assertTrue(fileRef.getByteSize() > 0);
        assertTrue(fileRef.getIsPreviewable());
        assertFalse(fileRef.getIsExecutable());
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 2. Deep Tree Traversal
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testDeepTreeNavigation() throws IOException {
        Path current = shareRootDir;
        for (int i = 1; i <= 6; i++) {
            current = current.resolve("level_" + i);
            Files.createDirectories(current);
            Files.writeString(current.resolve("file_" + i + ".txt"), "Content at level " + i);
        }

        AccessRequest browseDeep = AccessRequest.newBuilder()
                .setRequestId("req_deep_1")
                .setRequesterPeerId(PeerId.newBuilder().setValue(PEER_ALICE).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_BROWSE)
                .setShareId(SHARE_ID)
                .setRelativePath("level_1/level_2/level_3/level_4/level_5/level_6")
                .build();

        AccessResponse response = coordinator.handleAccessRequest(browseDeep);
        assertTrue(response.getSuccess());
        assertEquals(1, response.getItemsCount());
        assertEquals("file_6.txt", response.getItems(0).getDisplayName());
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 3. Large Folder & Pagination Cursors
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testLargeFolderPagination() throws IOException {
        Path largeDir = shareRootDir.resolve("bulk_files");
        Files.createDirectories(largeDir);

        int totalFiles = 65;
        for (int i = 0; i < totalFiles; i++) {
            String name = String.format("doc_%03d.txt", i);
            Files.writeString(largeDir.resolve(name), "Doc #" + i);
        }

        // Page 1: pageSize = 20
        AccessRequest page1Req = AccessRequest.newBuilder()
                .setRequestId("req_page_1")
                .setRequesterPeerId(PeerId.newBuilder().setValue(PEER_ALICE).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_BROWSE)
                .setShareId(SHARE_ID)
                .setRelativePath("bulk_files")
                .setMaxResults(20)
                .build();

        AccessResponse page1 = coordinator.handleAccessRequest(page1Req);
        assertTrue(page1.getSuccess());
        assertEquals(20, page1.getItemsCount());
        assertTrue(page1.getHasMore());
        assertFalse(page1.getNextPaginationCursor().isBlank());

        // Page 2: with cursor from page 1
        AccessRequest page2Req = AccessRequest.newBuilder()
                .setRequestId("req_page_2")
                .setRequesterPeerId(PeerId.newBuilder().setValue(PEER_ALICE).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_BROWSE)
                .setShareId(SHARE_ID)
                .setRelativePath("bulk_files")
                .setMaxResults(20)
                .setPaginationCursor(page1.getNextPaginationCursor())
                .build();

        AccessResponse page2 = coordinator.handleAccessRequest(page2Req);
        assertTrue(page2.getSuccess());
        assertEquals(20, page2.getItemsCount());
        assertTrue(page2.getHasMore());

        // Page 4 (last page: 20*3 = 60, so remaining is 5)
        String cursorForLast = "60";
        AccessRequest lastPageReq = AccessRequest.newBuilder()
                .setRequestId("req_page_last")
                .setRequesterPeerId(PeerId.newBuilder().setValue(PEER_ALICE).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_BROWSE)
                .setShareId(SHARE_ID)
                .setRelativePath("bulk_files")
                .setMaxResults(20)
                .setPaginationCursor(cursorForLast)
                .build();

        AccessResponse pageLast = coordinator.handleAccessRequest(lastPageReq);
        assertTrue(pageLast.getSuccess());
        assertEquals(5, pageLast.getItemsCount());
        assertFalse(pageLast.getHasMore(), "Last page should not have more");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 4. Unauthorized Request
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testUnauthorizedRequestRejected() {
        AccessRequest req = AccessRequest.newBuilder()
                .setRequestId("req_unauth_1")
                .setRequesterPeerId(PeerId.newBuilder().setValue(PEER_EVE).build()) // Not in allowed peers
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_BROWSE)
                .setShareId(SHARE_ID)
                .setRelativePath("")
                .build();

        AccessResponse response = coordinator.handleAccessRequest(req);
        assertFalse(response.getSuccess());
        assertEquals(ErrorCode.ERROR_CODE_UNAUTHORIZED, response.getError().getCode());
        assertTrue(response.getError().getHumanSummary().contains("Peer is not authorized"));

        // Verify audit log recorded the unauthorized rejection
        List<AccessAuditRecord> rejections = auditJournal.findByOutcome(AccessAuditRecord.AuditOutcome.REJECTED_UNAUTHORIZED);
        assertEquals(1, rejections.size());
        assertEquals(PEER_EVE, rejections.get(0).requesterPeerId());
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 5. Expired Authorization
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testExpiredAuthorizationRejected() {
        // Issue grant that already expired 10 seconds ago
        AccessGrant expiredGrant = AccessGrant.issue(
                "grant_exp",
                SHARE_ID,
                PEER_ALICE,
                Set.of(AccessScope.ACCESS_SCOPE_BROWSE),
                System.currentTimeMillis() - 60_000,
                System.currentTimeMillis() - 10_000,
                SECRET
        );

        AccessRequest req = AccessRequest.newBuilder()
                .setRequestId("req_exp_1")
                .setRequesterPeerId(PeerId.newBuilder().setValue(PEER_ALICE).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_BROWSE)
                .setShareId(SHARE_ID)
                .setAuthorizationToken(expiredGrant.toToken())
                .build();

        AccessResponse response = coordinator.handleAccessRequest(req);
        assertFalse(response.getSuccess());
        assertEquals(ErrorCode.ERROR_CODE_UNAUTHORIZED, response.getError().getCode());
        assertTrue(response.getError().getHumanSummary().contains("expired"));

        List<AccessAuditRecord> expiredLogs = auditJournal.findByOutcome(AccessAuditRecord.AuditOutcome.REJECTED_EXPIRED);
        assertEquals(1, expiredLogs.size());
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 6. Path Traversal Protection
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testPathTraversalRejected() {
        List<String> maliciousPaths = List.of(
                "../outside.txt",
                "..\\outside.txt",
                "subfolder/../../root.txt",
                "C:\\Windows\\System32\\cmd.exe",
                "D:/secret.dat",
                "\\\\192.168.1.1\\share\\test",
                "file.txt\0evil.exe",
                "normal.txt:stream:$DATA"
        );

        for (String maliciousPath : maliciousPaths) {
            AccessRequest req = AccessRequest.newBuilder()
                    .setRequestId("req_trav_" + maliciousPath.hashCode())
                    .setRequesterPeerId(PeerId.newBuilder().setValue(PEER_ALICE).build())
                    .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_METADATA)
                    .setShareId(SHARE_ID)
                    .setRelativePath(maliciousPath)
                    .build();

            AccessResponse response = coordinator.handleAccessRequest(req);
            assertFalse(response.getSuccess(), "Path traversal must be rejected: " + maliciousPath);
            assertEquals(ErrorCode.ERROR_CODE_UNAUTHORIZED, response.getError().getCode());
        }

        List<AccessAuditRecord> traversals = auditJournal.findByOutcome(AccessAuditRecord.AuditOutcome.REJECTED_PATH_TRAVERSAL);
        assertEquals(maliciousPaths.size(), traversals.size());
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 7. Symlink & Junction Safety
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testSymlinkSafety() throws IOException {
        // Create an external secret file outside the share root
        Path outsideDir = tempDir.resolve("outside_secrets");
        Files.createDirectories(outsideDir);
        Path secretFile = outsideDir.resolve("confidential.txt");
        Files.writeString(secretFile, "Top Secret Content");

        // Try creating a symlink inside the share root that points outside
        Path linkOutside = shareRootDir.resolve("link_to_secrets");
        try {
            Files.createSymbolicLink(linkOutside, secretFile);

            AccessRequest req = AccessRequest.newBuilder()
                    .setRequestId("req_symlink_escape")
                    .setRequesterPeerId(PeerId.newBuilder().setValue(PEER_ALICE).build())
                    .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_PREVIEW)
                    .setShareId(SHARE_ID)
                    .setRelativePath("link_to_secrets")
                    .build();

            AccessResponse response = coordinator.handleAccessRequest(req);
            assertFalse(response.getSuccess(), "Symlink pointing outside share must be blocked");
            assertTrue(response.getError().getHumanSummary().toLowerCase().contains("symlink") ||
                    response.getError().getHumanSummary().toLowerCase().contains("escaped"));
        } catch (UnsupportedOperationException | FileSystemException e) {
            // Some Windows environments without Developer Mode may disallow creating symlinks without admin
            // In that case, verify PathSandboxValidator explicitly with a simulated escape check
            PathSandboxValidator validator = new PathSandboxValidator(true);
            assertThrows(PathSandboxValidator.PathTraversalException.class, () -> {
                validator.resolveAndValidate(shareRootDir, "../outside_secrets/confidential.txt");
            });
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 8. Request Cancellation
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testRequestCancellation() {
        CancellationToken token = new CancellationToken();
        assertFalse(token.isCancelled());

        token.cancel("User aborted download");
        assertTrue(token.isCancelled());
        assertEquals("User aborted download", token.getReason());
        assertThrows(CancellationToken.OperationCancelledException.class, token::throwIfCancelled);

        // Test cancel request dispatch through coordinator
        AccessCancelRequest cancelReq = AccessCancelRequest.newBuilder()
                .setRequestId("req_to_cancel_1")
                .setReason("Network congestion")
                .build();

        AccessCancelResponse cancelResp = coordinator.handleCancelRequest(cancelReq);
        // Not found is acknowledged cleanly
        assertFalse(cancelResp.getCancelled());
        assertTrue(cancelResp.getMessage().contains("completed") || cancelResp.getMessage().contains("not found"));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 9. Peer Disconnect Cleanup
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testPeerDisconnectCleanup() {
        // Coordinator cleans up peer tracking when onPeerDisconnected is called
        coordinator.onPeerDisconnected(PEER_ALICE);
        // Should execute cleanly without error even if no active ops
        coordinator.onPeerDisconnected(null);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 10. Safe Preview & Executable Policy
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testSafePreviewAndExecutablePolicy() throws IOException {
        // 1. Text file: preview succeeds
        Path safeFile = shareRootDir.resolve("notes.txt");
        Files.writeString(safeFile, "Sample text content for preview testing.");

        AccessRequest safePreviewReq = AccessRequest.newBuilder()
                .setRequestId("req_prev_safe")
                .setRequesterPeerId(PeerId.newBuilder().setValue(PEER_ALICE).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_PREVIEW)
                .setShareId(SHARE_ID)
                .setRelativePath("notes.txt")
                .setPreviewMaxBytes(1024)
                .build();

        AccessResponse safeResp = coordinator.handleAccessRequest(safePreviewReq);
        assertTrue(safeResp.getSuccess());
        assertEquals("text/plain", safeResp.getPreviewMimeType());
        assertTrue(safeResp.getPreviewData().toStringUtf8().contains("Sample text content"));

        // 2. Executable file: preview MUST BE REJECTED
        Path exeFile = shareRootDir.resolve("malicious.exe");
        Files.write(exeFile, new byte[]{(byte) 0x4D, (byte) 0x5A, 0x00, 0x01}); // "MZ" PE header

        AccessRequest exePreviewReq = AccessRequest.newBuilder()
                .setRequestId("req_prev_exe")
                .setRequesterPeerId(PeerId.newBuilder().setValue(PEER_ALICE).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_PREVIEW)
                .setShareId(SHARE_ID)
                .setRelativePath("malicious.exe")
                .setPreviewMaxBytes(1024)
                .build();

        AccessResponse exeResp = coordinator.handleAccessRequest(exePreviewReq);
        assertFalse(exeResp.getSuccess(), "Executable preview must be rejected");
        assertEquals(ErrorCode.ERROR_CODE_UNAUTHORIZED, exeResp.getError().getCode());
        assertTrue(exeResp.getError().getHumanSummary().contains("Executable files are metadata-only"));

        List<AccessAuditRecord> unsafeLogs = auditJournal.findByOutcome(AccessAuditRecord.AuditOutcome.REJECTED_UNSAFE_PREVIEW);
        assertEquals(1, unsafeLogs.size());

        // 3. Batch script: preview MUST BE REJECTED
        Path batFile = shareRootDir.resolve("script.bat");
        Files.writeString(batFile, "@echo off\r\ndir\r\n");

        AccessRequest batReq = AccessRequest.newBuilder()
                .setRequestId("req_prev_bat")
                .setRequesterPeerId(PeerId.newBuilder().setValue(PEER_ALICE).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_PREVIEW)
                .setShareId(SHARE_ID)
                .setRelativePath("script.bat")
                .build();

        AccessResponse batResp = coordinator.handleAccessRequest(batReq);
        assertFalse(batResp.getSuccess());
        assertTrue(batResp.getError().getHumanSummary().contains("Executable files are metadata-only"));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 11. Remote Search & Privacy
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testRemoteSearchAndPrivacy() throws IOException {
        Path docsDir = shareRootDir.resolve("projects");
        Files.createDirectories(docsDir);
        Files.writeString(docsDir.resolve("annual_report_2026.pdf"), "PDF data");
        Files.writeString(docsDir.resolve("financial_summary.xlsx"), "Excel data");
        Files.writeString(docsDir.resolve("report_draft.md"), "Markdown data");
        Files.writeString(docsDir.resolve("unrelated_notes.txt"), "Other notes");

        AccessRequest searchReq = AccessRequest.newBuilder()
                .setRequestId("req_search_1")
                .setRequesterPeerId(PeerId.newBuilder().setValue(PEER_ALICE).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_SEARCH)
                .setShareId(SHARE_ID)
                .setSearchQuery("report")
                .setMaxResults(10)
                .setMaxDepth(3)
                .setTimeoutMs(2000)
                .build();

        AccessResponse response = coordinator.handleAccessRequest(searchReq);
        assertTrue(response.getSuccess());
        assertEquals(2, response.getItemsCount(), "Should match annual_report_2026.pdf and report_draft.md");

        // Test wildcard search
        AccessRequest searchExtReq = AccessRequest.newBuilder()
                .setRequestId("req_search_2")
                .setRequesterPeerId(PeerId.newBuilder().setValue(PEER_ALICE).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_SEARCH)
                .setShareId(SHARE_ID)
                .setSearchQuery("*.xlsx")
                .build();

        AccessResponse extResp = coordinator.handleAccessRequest(searchExtReq);
        assertTrue(extResp.getSuccess());
        assertEquals(1, extResp.getItemsCount());
        assertEquals("financial_summary.xlsx", extResp.getItems(0).getDisplayName());
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 12. Archive Inspection Safety (Zip-Slip & Decompression Safety)
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testArchiveInspectionSafety() throws IOException {
        Path zipFile = shareRootDir.resolve("bundle.zip");

        try (ZipOutputStream zos = new ZipOutputStream(new FileOutputStream(zipFile.toFile()))) {
            // Normal safe file
            ZipEntry normal = new ZipEntry("content/article.txt");
            zos.putNextEntry(normal);
            zos.write("Some article content".getBytes(StandardCharsets.UTF_8));
            zos.closeEntry();

            // Malicious Zip-Slip entry
            ZipEntry slip = new ZipEntry("../../evil.exe");
            zos.putNextEntry(slip);
            zos.write("Malicious bytes".getBytes(StandardCharsets.UTF_8));
            zos.closeEntry();
        }

        AccessRequest inspectReq = AccessRequest.newBuilder()
                .setRequestId("req_archive_1")
                .setRequesterPeerId(PeerId.newBuilder().setValue(PEER_ALICE).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_ARCHIVE_INSPECT)
                .setShareId(SHARE_ID)
                .setRelativePath("bundle.zip")
                .build();

        AccessResponse response = coordinator.handleAccessRequest(inspectReq);
        assertTrue(response.getSuccess());
        assertEquals(2, response.getArchiveEntriesCount());

        ArchiveEntryDescriptor safeEntry = response.getArchiveEntries(0);
        assertTrue(safeEntry.getIsSafe());

        ArchiveEntryDescriptor slipEntry = response.getArchiveEntries(1);
        assertFalse(slipEntry.getIsSafe(), "Zip-slip entry must be flagged as unsafe");
        assertTrue(slipEntry.getWarning().contains("Zip-Slip"));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 13. Remote Access Client Integration
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testRemoteAccessClientDispatch() throws Exception {
        RemoteAccessClient client = new RemoteAccessClient(PEER_ALICE, PEER_BOB, null);

        CompletableFuture<AccessResponse> future = client.browseAsync(
                SHARE_ID,
                "",
                20,
                null,
                null,
                3000
        );

        assertFalse(future.isDone());

        // Simulate remote coordinator answering
        AccessResponse mockResp = AccessResponse.newBuilder()
                .setRequestId("req_mock_resp")
                .setSuccess(true)
                .build();

        client.dispatchIncomingResponse(mockResp);
        // Clean disconnect handling
        client.onSessionClosed("Test peer disconnect");
    }
}
