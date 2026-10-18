package org.peerlink.app

import com.google.protobuf.ByteString
import com.google.protobuf.UnknownFieldSet
import org.junit.Assert.*
import org.junit.Test
import org.peerlink.core.capability.CapabilityRegistry
import org.peerlink.core.compatibility.*
import org.peerlink.protocol.v1.*
import java.nio.charset.StandardCharsets

/**
 * Phase 8 Verification Suite: Cross-Device Interoperability & Backward Compatibility.
 *
 * Verifies:
 * 1. Protocol version negotiation across matching, overlapping, and disjoint versions.
 * 2. Schema compatibility and transport security invariants.
 * 3. Graceful capability degradation and missing required capability rejection.
 * 4. Forward compatibility: Unknown protobuf field preservation across serialization cycles.
 * 5. OS filesystem invariants (Windows reserved names, illegal chars, trailing dots, MAX_PATH).
 * 6. Storage volume boundaries (FAT32 4GB limit).
 * 7. Metadata preservation (POSIX modes, symlinks, xattrs, EXIF GPS) without silent stripping.
 * 8. Binary execution safety (Rule 10): No silent execution of inbound executables.
 * 9. IPC contract equivalence across desktop and mobile node models.
 */
class AndroidCrossPlatformInteroperabilityTest {

    // ── 1. Protocol Version Negotiation ──────────────────────────────────────

    @Test
    fun testProtocolVersionAgreementMatching() {
        val localCaps = CapabilityRegistry(setOf("transport_tcp", "resume_v1", "manifest_v1"))
        val negotiator = ProtocolCompatibilityNegotiator(localCaps)

        val result = negotiator.negotiate(
            1, 1, "peerlink.v1",
            setOf("transport_tcp", "resume_v1"),
            true
        )

        assertTrue("Matching versions must be compatible", result.isCompatible)
        assertEquals(1, result.negotiatedVersion())
        assertEquals("peerlink.v1", result.schemaIdentifier())
        assertTrue(result.negotiatedCapabilities().contains("transport_tcp"))
        assertTrue(result.negotiatedCapabilities().contains("resume_v1"))
        assertTrue(result.incompatibilityReasons().isEmpty())
    }

    @Test
    fun testProtocolVersionAgreementRangeOverlap() {
        val localCaps = CapabilityRegistry(setOf("cap_a", "cap_b"))
        val negotiator = ProtocolCompatibilityNegotiator(
            1, 3, "peerlink.v1", localCaps, emptySet()
        )

        // Remote supports versions 1..2
        val result = negotiator.negotiate(
            1, 2, "peerlink.v1",
            setOf("cap_a"),
            true
        )

        assertTrue(result.isCompatible)
        assertEquals("Negotiates highest common version", 2, result.negotiatedVersion())
        assertTrue(result.negotiatedCapabilities().contains("cap_a"))
    }

    @Test
    fun testProtocolVersionMismatchRejection() {
        val localCaps = CapabilityRegistry(setOf("cap_a"))
        val negotiator = ProtocolCompatibilityNegotiator(
            1, 1, "peerlink.v1", localCaps, emptySet()
        )

        // Remote is an incompatible future major version (2..3)
        val result = negotiator.negotiate(
            2, 3, "peerlink.v1",
            setOf("cap_a"),
            true
        )

        assertFalse("Disjoint versions must be incompatible", result.isCompatible)
        assertEquals(-1, result.negotiatedVersion())
        assertTrue(
            "Must report version mismatch reason",
            result.incompatibilityReasons().any { it.contains("Protocol version mismatch") }
        )
    }

    @Test
    fun testSchemaMismatchRejection() {
        val localCaps = CapabilityRegistry()
        val negotiator = ProtocolCompatibilityNegotiator(localCaps)

        val result = negotiator.negotiate(
            1, 1, "peerlink.v2_incompatible",
            emptySet(),
            true
        )

        assertFalse(result.isCompatible)
        assertTrue(result.incompatibilityReasons().any { it.contains("Message schema mismatch") })
    }

    @Test
    fun testUnencryptedTransportRejected() {
        val localCaps = CapabilityRegistry()
        val negotiator = ProtocolCompatibilityNegotiator(localCaps)

        // transportEncrypted = false
        val result = negotiator.negotiate(
            1, 1, "peerlink.v1",
            emptySet(),
            false
        )

        assertFalse("Unencrypted transport must be rejected per Zero-Trust policy", result.isCompatible)
        assertTrue(result.incompatibilityReasons().any { it.contains("unencrypted transport rejected") })
    }

    // ── 2. Capability Negotiation & Graceful Degradation ─────────────────────

    @Test
    fun testRequiredCapabilityMissingRejection() {
        val localCaps = CapabilityRegistry(setOf("cap_basic"))
        val required = setOf("mandatory_e2e_encryption")
        val negotiator = ProtocolCompatibilityNegotiator(
            1, 1, "peerlink.v1", localCaps, required
        )

        // Remote does not offer mandatory_e2e_encryption
        val result = negotiator.negotiate(
            1, 1, "peerlink.v1",
            setOf("cap_basic"),
            true
        )

        assertFalse("Missing required capability must cause rejection", result.isCompatible)
        assertTrue(result.incompatibilityReasons().any { it.contains("mandatory_e2e_encryption") })
    }

    @Test
    fun testOptionalCapabilityGracefulDegradation() {
        val localCaps = CapabilityRegistry(setOf("cap_core", "cap_feature_x"))
        val negotiator = ProtocolCompatibilityNegotiator(localCaps)

        // Remote offers cap_core and unknown cap_future_z
        val result = negotiator.negotiate(
            1, 1, "peerlink.v1",
            setOf("cap_core", "cap_future_z"),
            true
        )

        assertTrue("Optional unknown capability does not prevent connection", result.isCompatible)
        assertTrue(result.negotiatedCapabilities().contains("cap_core"))
        assertFalse("Unknown capability is not negotiated", result.negotiatedCapabilities().contains("cap_future_z"))
        assertFalse("Feature X not offered by remote is not negotiated", result.negotiatedCapabilities().contains("cap_feature_x"))
    }

    // ── 3. Protobuf Forward Compatibility (UnknownFieldSet Preservation) ─────

    @Test
    fun testProtobufForwardCompatibilityUnknownFieldPreservation() {
        // Build an ObjectReference message
        val baseObj = ObjectReference.newBuilder()
            .setObjectId(ObjectId.newBuilder().setValue("obj-1234-uuid").build())
            .setLogicalName("presentation.pdf")
            .setByteSize(1048576)
            .build()

        // Inject unknown field tag 999 with raw bytes (simulating a future schema extension from newer peer)
        val unknownPayload = ByteString.copyFromUtf8("future_field_payload_v2")
        val unknownFields = UnknownFieldSet.newBuilder()
            .addField(
                999,
                UnknownFieldSet.Field.newBuilder()
                    .addLengthDelimited(unknownPayload)
                    .build()
            )
            .build()

        // Merge unknown fields into base message
        val extendedObj = ObjectReference.newBuilder(baseObj)
            .setUnknownFields(unknownFields)
            .build()

        // Wire serialization
        val wireBytes = extendedObj.toByteArray()
        assertNotNull(wireBytes)
        assertTrue(wireBytes.isNotEmpty())

        // Node parses wireBytes using existing v1 schema
        val parsedObj = ObjectReference.parseFrom(wireBytes)

        // 1. Existing known fields parsed normally
        assertEquals("obj-1234-uuid", parsedObj.objectId.value)
        assertEquals("presentation.pdf", parsedObj.logicalName)
        assertEquals(1048576L, parsedObj.byteSize)

        // 2. Unknown field 999 is retained in UnknownFieldSet
        assertTrue("Unknown field 999 must be preserved", parsedObj.unknownFields.hasField(999))
        val extractedField = parsedObj.unknownFields.getField(999)
        assertEquals(1, extractedField.lengthDelimitedList.size)
        assertEquals("future_field_payload_v2", extractedField.lengthDelimitedList[0].toStringUtf8())

        // 3. Re-serializing parsed message retains unknown fields byte-for-byte
        val reserializedBytes = parsedObj.toByteArray()
        assertArrayEquals("Forwarded wire bytes must match original extended wire bytes", wireBytes, reserializedBytes)
    }

    // ── 4. OS Filesystem Invariants & Filename Rules ──────────────────────────

    @Test
    fun testWindowsReservedNamesRequireUserDecision() {
        val reservedNames = listOf("CON.txt", "prn.dat", "AUX", "NUL.log", "com1.bin", "lpt9.pdf", "aux.tar.gz")

        for (name in reservedNames) {
            val report = CompatibilityAnalyzer.analyze(
                "documents/$name",
                1024,
                emptyMap(),
                CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS
            )

            assertEquals("Reserved name '$name' must require user decision", CompatibilityResult.REQUIRES_USER_DECISION, report.overallResult())
            assertTrue("Must flag requiresUserDecision", report.requiresUserDecision())
            assertTrue(
                "Must report WINDOWS_RESERVED_NAME issue",
                report.issues().any { it.code() == "WINDOWS_RESERVED_NAME" }
            )
        }
    }

    @Test
    fun testWindowsReservedNamesAllowedOnLinuxAndAndroid() {
        val reportAndroid = CompatibilityAnalyzer.analyze(
            "documents/CON.txt",
            1024,
            emptyMap(),
            CompatibilityAnalyzer.TargetOperatingSystem.ANDROID
        )
        assertEquals(CompatibilityResult.COMPATIBLE, reportAndroid.overallResult())
        assertFalse(reportAndroid.requiresUserDecision())

        val reportLinux = CompatibilityAnalyzer.analyze(
            "documents/aux.dat",
            1024,
            emptyMap(),
            CompatibilityAnalyzer.TargetOperatingSystem.LINUX
        )
        assertEquals(CompatibilityResult.COMPATIBLE, reportLinux.overallResult())
    }

    @Test
    fun testWindowsIllegalCharactersFlaggedIncompatible() {
        val illegalFilenames = listOf("file<1>.txt", "file>2<.dat", "bad:name.txt", "quote\"test.pdf", "pipe|file.doc", "what?.png", "star*file.zip")

        for (name in illegalFilenames) {
            val report = CompatibilityAnalyzer.analyze(
                name,
                512,
                emptyMap(),
                CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS
            )

            assertEquals("Illegal char in '$name' must be INCOMPATIBLE", CompatibilityResult.INCOMPATIBLE, report.overallResult())
            assertTrue(
                "Must report WINDOWS_ILLEGAL_CHARACTERS issue",
                report.issues().any { it.code() == "WINDOWS_ILLEGAL_CHARACTERS" }
            )
        }
    }

    @Test
    fun testTrailingDotOrSpaceRequiresUserDecision() {
        val trailingFiles = listOf("document.txt.", "archive.zip ", "folder/report. ")

        for (name in trailingFiles) {
            val report = CompatibilityAnalyzer.analyze(
                name,
                256,
                emptyMap(),
                CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS
            )

            assertEquals("Trailing dot/space in '$name' must require user decision", CompatibilityResult.REQUIRES_USER_DECISION, report.overallResult())
            assertTrue(report.requiresUserDecision())
            assertTrue(report.issues().any { it.code() == "TRAILING_DOT_OR_SPACE" })
        }
    }

    @Test
    fun testWindowsMaxPathConstraint() {
        val deepPath = "a/".repeat(135) + "target_file.txt" // > 270 chars
        assertTrue(deepPath.length > 260)

        val report = CompatibilityAnalyzer.analyze(
            deepPath,
            1024,
            emptyMap(),
            CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS
        )

        assertEquals(CompatibilityResult.PARTIALLY_COMPATIBLE, report.overallResult())
        assertTrue(report.issues().any { it.code() == "PATH_EXCEEDS_MAX_PATH" })
    }

    @Test
    fun testPathTraversalAndNullByteIncompatible() {
        val traversalReport = CompatibilityAnalyzer.analyze(
            "../../etc/passwd",
            100,
            emptyMap(),
            CompatibilityAnalyzer.TargetOperatingSystem.ANDROID
        )
        assertEquals(CompatibilityResult.INCOMPATIBLE, traversalReport.overallResult())
        assertTrue(traversalReport.issues().any { it.code() == "PATH_TRAVERSAL" })

        val nullByteReport = CompatibilityAnalyzer.analyze(
            "safe_file\u0000.txt",
            100,
            emptyMap(),
            CompatibilityAnalyzer.TargetOperatingSystem.ANDROID
        )
        assertEquals(CompatibilityResult.INCOMPATIBLE, nullByteReport.overallResult())
        assertTrue(nullByteReport.issues().any { it.code() == "NULL_BYTE_IN_FILENAME" })
    }

    // ── 5. Storage Volume Boundaries (FAT32 4GB limit) ────────────────────────

    @Test
    fun testFat32FourGigabyteVolumeLimit() {
        val underLimit = 4294967295L // 4GB - 1
        val reportUnder = CompatibilityAnalyzer.analyze(
            "media/movie.mkv",
            underLimit,
            emptyMap(),
            CompatibilityAnalyzer.TargetOperatingSystem.ANDROID
        )
        assertEquals(CompatibilityResult.COMPATIBLE, reportUnder.overallResult())

        val overLimit = 4294967296L // 4GB exact (exceeds single file FAT32 limit)
        val reportOver = CompatibilityAnalyzer.analyze(
            "media/4k_video.mkv",
            overLimit,
            emptyMap(),
            CompatibilityAnalyzer.TargetOperatingSystem.ANDROID
        )
        assertEquals(CompatibilityResult.PARTIALLY_COMPATIBLE, reportOver.overallResult())
        assertTrue(reportOver.issues().any { it.code() == "EXCEEDS_FAT32_LIMIT" })
    }

    // ── 6. Metadata Preservation Without Silent Stripping ────────────────────

    @Test
    fun testMetadataPreservationWithoutSilentStripping() {
        val meta = mapOf(
            "posix_permissions" to "0755",
            "is_symlink" to "true",
            "extended_attributes" to "user.custom_attr=val",
            "has_gps" to "true"
        )

        val report = CompatibilityAnalyzer.analyze(
            "scripts/build.sh",
            2048,
            meta,
            CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS
        )

        assertTrue("Symlinks require user decision", report.requiresUserDecision())
        assertTrue("Preserves POSIX permissions", report.issues().any { it.code() == "POSIX_PERMISSIONS_ON_WINDOWS" })
        assertTrue("Preserves symlinks", report.issues().any { it.code() == "SYMLINK_REPRESENTATION" })
        assertTrue("Preserves xattrs", report.issues().any { it.code() == "EXTENDED_ATTRIBUTES_LIMITATION" })
        assertTrue("Flags sensitive GPS", report.issues().any { it.code() == "SENSITIVE_GPS_METADATA" })
    }

    // ── 7. Binary Execution Safety (Rule 10) ──────────────────────────────────

    @Test
    fun testExecutableBinarySafetyRule10() {
        // 1. Windows executable received on Windows requires user decision; never auto-executes
        val winReport = CompatibilityAnalyzer.analyze(
            "tools/updater.exe",
            10240,
            emptyMap(),
            CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS
        )
        assertEquals(CompatibilityResult.REQUIRES_USER_DECISION, winReport.overallResult())
        assertTrue(winReport.requiresUserDecision())
        assertTrue(winReport.issues().any { it.code() == "EXECUTABLE_RECEIVED" })

        // 2. Windows executable received on Android/Linux is flagged INCOMPATIBLE for execution
        val androidReport = CompatibilityAnalyzer.analyze(
            "tools/updater.exe",
            10240,
            emptyMap(),
            CompatibilityAnalyzer.TargetOperatingSystem.ANDROID
        )
        assertEquals(CompatibilityResult.INCOMPATIBLE, androidReport.overallResult())
        assertTrue(androidReport.issues().any { it.code() == "WINDOWS_EXECUTABLE_ON_NON_WINDOWS" })

        // 3. Linux ELF binary on Windows is flagged INCOMPATIBLE for execution
        val winElfReport = CompatibilityAnalyzer.analyze(
            "bin/daemon.so",
            10240,
            emptyMap(),
            CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS
        )
        assertEquals(CompatibilityResult.INCOMPATIBLE, winElfReport.overallResult())
        assertTrue(winElfReport.issues().any { it.code() == "LINUX_ELF_ON_NON_LINUX" })
    }

    // ── 8. Cross-Platform Desktop IPC Protobuf Equivalence ───────────────────

    @Test
    fun testCrossPlatformIpcProtobufEquivalence() {
        val initiateReq = InitiateSendRequest.newBuilder()
            .setTargetPeerId(PeerId.newBuilder().setValue("peer_remote_android_99").build())
            .addSourcePaths("/storage/emulated/0/DCIM/photo.jpg")
            .build()

        val reqBytes = initiateReq.toByteArray()
        val parsedReq = InitiateSendRequest.parseFrom(reqBytes)

        assertEquals("peer_remote_android_99", parsedReq.getTargetPeerId().value)
        assertEquals(1, parsedReq.sourcePathsCount)
        assertEquals("/storage/emulated/0/DCIM/photo.jpg", parsedReq.getSourcePaths(0))


        val pauseReq = PauseTransferRequest.newBuilder()
            .setTransferId("xfer-persistent-101")
            .setReason("Network handoff")
            .build()
        val parsedPause = PauseTransferRequest.parseFrom(pauseReq.toByteArray())
        assertEquals("xfer-persistent-101", parsedPause.transferId)
        assertEquals("Network handoff", parsedPause.reason)

        val resumeReq = ResumeTransferRequest.newBuilder()
            .setTransferId("xfer-persistent-101")
            .build()
        val parsedResume = ResumeTransferRequest.parseFrom(resumeReq.toByteArray())
        assertEquals("xfer-persistent-101", parsedResume.transferId)
    }
}
