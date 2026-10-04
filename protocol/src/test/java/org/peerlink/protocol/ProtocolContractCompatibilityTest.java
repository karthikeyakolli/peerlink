package org.peerlink.protocol;

import com.google.protobuf.ByteString;
import com.google.protobuf.UnknownFieldSet;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.peerlink.protocol.v1.*;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

public class ProtocolContractCompatibilityTest {

    private static final Path FIXTURE_DIR = Paths.get("target", "test-fixtures");

    @BeforeAll
    static void initFixtureDir() throws IOException {
        Files.createDirectories(FIXTURE_DIR);
    }

    @Test
    void testProtocolVersionAndHeader() throws Exception {
        ProtocolVersion version = ProtocolVersion.newBuilder()
                .setMajor(1)
                .setMinor(0)
                .setPatch(0)
                .setPreRelease("rc1")
                .build();

        ProtocolHeader header = ProtocolHeader.newBuilder()
                .setVersion(version)
                .setMinSupportedVersion(version)
                .setTraceId("trace_987654321")
                .setTimestampUtcMs(1760000000000L)
                .putFeatureFlags("transport.quic", "enabled")
                .putFeatureFlags("storage.wal", "active")
                .build();

        byte[] bytes = header.toByteArray();
        ProtocolHeader parsed = ProtocolHeader.parseFrom(bytes);

        assertEquals(1, parsed.getVersion().getMajor());
        assertEquals(0, parsed.getVersion().getMinor());
        assertEquals("rc1", parsed.getVersion().getPreRelease());
        assertEquals("trace_987654321", parsed.getTraceId());
        assertEquals("enabled", parsed.getFeatureFlagsMap().get("transport.quic"));
    }

    @Test
    void testPeerAndDeviceIdentity() throws Exception {
        CryptographicKey key = CryptographicKey.newBuilder()
                .setKeyType(KeyType.KEY_TYPE_ED25519)
                .setPublicKeyBytes(ByteString.copyFrom("public-key-ed25519-bytes", StandardCharsets.UTF_8))
                .setKeyId("key_ed25519_001")
                .setCreatedAtUtcMs(1760000000000L)
                .build();

        DeviceIdentity device = DeviceIdentity.newBuilder()
                .setDeviceId(DeviceId.newBuilder().setValue("dev_desktop_win_01").build())
                .setDeviceName("Lead-Workstation")
                .setDeviceType(DeviceType.DEVICE_TYPE_DESKTOP_WINDOWS)
                .setOsVersion("Windows 10 Pro 64-bit")
                .setAppVersion("0.1.0")
                .setIdentityKey(key)
                .build();

        PeerIdentity peer = PeerIdentity.newBuilder()
                .setPeerId(PeerId.newBuilder().setValue("peer_alice_99").build())
                .setDeviceId(device.getDeviceId())
                .setDisplayName("Alice Desktop")
                .setIdentityKey(key)
                .setFingerprintHex("SHA256:4a8b1c9d2e3f")
                .setTrustLevel(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED)
                .setPairedAtUtcMs(1760000010000L)
                .build();

        byte[] peerBytes = peer.toByteArray();
        Files.write(FIXTURE_DIR.resolve("peer_identity.bin"), peerBytes);

        PeerIdentity parsed = PeerIdentity.parseFrom(peerBytes);
        assertEquals("peer_alice_99", parsed.getPeerId().getValue());
        assertEquals("dev_desktop_win_01", parsed.getDeviceId().getValue());
        assertEquals(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED, parsed.getTrustLevel());
        assertEquals(KeyType.KEY_TYPE_ED25519, parsed.getIdentityKey().getKeyType());
    }

    @Test
    void testObjectReferenceInvariants() throws Exception {
        // Invariant 1: Object ID is separate from physical OS path (logical_name is relative display label, ObjectId is logical UUID)
        // Invariant 2: Object ID is separate from ContentHash (hash is cryptographic digest, not identity)
        // Invariant 3: CausalClock vector clock is authoritative; timestamp is hint only
        ObjectId objectId = ObjectId.newBuilder().setValue("obj_8820c741-2a1e-4c7b-91d8-04b123456789").build();
        ContentHash contentHash = ContentHash.newBuilder()
                .setAlgorithm(HashAlgorithm.HASH_ALGORITHM_SHA256)
                .setHexDigest("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
                .setHashBytes(ByteString.copyFrom(new byte[32]))
                .build();

        CausalClock causalClock = CausalClock.newBuilder()
                .setLogicalCounter(42)
                .setActorPeerId("peer_alice_99")
                .putPeerVectors("peer_alice_99", 42)
                .putPeerVectors("peer_bob_12", 15)
                .build();

        ObjectReference objRef = ObjectReference.newBuilder()
                .setObjectId(objectId)
                .setContentHash(contentHash)
                .setVersionId(VersionId.newBuilder().setValue("v_causal_42").build())
                .setObjectType(ObjectType.OBJECT_TYPE_FILE)
                .setByteSize(1048576)
                .setMimeType("application/pdf")
                .setLogicalName("Financial_Report_2026.pdf") // User display name, NOT C:\Users\... or /home/...
                .setCausalClock(causalClock)
                .setClientModifiedHintUtcMs(1760000000000L) // Advisory hint only
                .setIsTombstone(false)
                .putMetadata("author", "Alice")
                .build();

        byte[] objBytes = objRef.toByteArray();
        Files.write(FIXTURE_DIR.resolve("object_reference.bin"), objBytes);

        ObjectReference parsed = ObjectReference.parseFrom(objBytes);

        // Assert path is NOT identity
        assertNotEquals(parsed.getLogicalName(), parsed.getObjectId().getValue());
        assertFalse(parsed.getLogicalName().contains(":\\"));
        assertFalse(parsed.getLogicalName().startsWith("/"));

        // Assert hash is NOT identity
        assertNotEquals(parsed.getContentHash().getHexDigest(), parsed.getObjectId().getValue());

        // Assert causal clock precedence
        assertEquals(42, parsed.getCausalClock().getLogicalCounter());
        assertEquals(15, parsed.getCausalClock().getPeerVectorsMap().get("peer_bob_12"));
    }

    @Test
    void testOperationContractDurableIdAndIdempotency() throws Exception {
        OperationId opId = OperationId.newBuilder().setValue("op_durable_uuid_777").build();
        ObjectReference targetObj = ObjectReference.newBuilder()
                .setObjectId(ObjectId.newBuilder().setValue("obj_8820c741").build())
                .setLogicalName("Shared_Document.txt")
                .build();

        OperationRecord operation = OperationRecord.newBuilder()
                .setOperationId(opId)
                .setIntent(OperationIntent.OPERATION_INTENT_SYNC)
                .setActorPeerId(PeerId.newBuilder().setValue("peer_alice_99").build())
                .addTargetObjects(targetObj)
                .setState(OperationState.OPERATION_STATE_COMMITTED)
                .setIdempotencyKey("idemp_seq_998124")
                .setCausalClock(CausalClock.newBuilder().setLogicalCounter(10).setActorPeerId("peer_alice_99").build())
                .setCreatedAtUtcMs(1760000000000L)
                .setUpdatedAtUtcMs(1760000002000L)
                .putParameters("sync_mode", "convergent_replica")
                .build();

        byte[] opBytes = operation.toByteArray();
        Files.write(FIXTURE_DIR.resolve("operation_record.bin"), opBytes);

        OperationRecord parsed = OperationRecord.parseFrom(opBytes);
        assertEquals("op_durable_uuid_777", parsed.getOperationId().getValue());
        assertEquals(OperationIntent.OPERATION_INTENT_SYNC, parsed.getIntent());
        assertEquals(OperationState.OPERATION_STATE_COMMITTED, parsed.getState());
        assertEquals("idemp_seq_998124", parsed.getIdempotencyKey());
    }

    @Test
    void testDeterministicErrorModel() throws Exception {
        ErrorDetail error = ErrorDetail.newBuilder()
                .setCode(ErrorCode.ERROR_CODE_UNSUPPORTED_CAPABILITY)
                .setErrorName("ERR_UNSUPPORTED_CAPABILITY")
                .setHumanSummary("Requested capability is not supported by target peer")
                .setHumanExplanation("The target peer is running mobile constraints without background QUIC transport")
                .setSuggestedRecoveryAction("Switch transport candidate to TCP/TLS or TURN relay")
                .setIsRetryable(true)
                .setTraceId("trace_err_4048")
                .setTimestampUtcMs(1760000003000L)
                .putErrorContext("peer_id", "peer_bob_mobile")
                .putErrorContext("requested_feature", "FEATURE_QUIC")
                .build();

        byte[] errBytes = error.toByteArray();
        Files.write(FIXTURE_DIR.resolve("error_detail.bin"), errBytes);

        ErrorDetail parsed = ErrorDetail.parseFrom(errBytes);
        assertEquals(ErrorCode.ERROR_CODE_UNSUPPORTED_CAPABILITY, parsed.getCode());
        assertEquals("ERR_UNSUPPORTED_CAPABILITY", parsed.getErrorName());
        assertTrue(parsed.getIsRetryable());
        assertEquals("Switch transport candidate to TCP/TLS or TURN relay", parsed.getSuggestedRecoveryAction());
    }

    @Test
    void testCapabilityNegotiationWithGracefulUnsupportedResponse() throws Exception {
        CapabilityDescriptor acceptedCap = CapabilityDescriptor.newBuilder()
                .setCapabilityName("peerlink.transport.quic")
                .setVersion(ProtocolVersion.newBuilder().setMajor(1).setMinor(0).setPatch(0).build())
                .setValidUntilUtcMs(1760003600000L) // Descriptive with TTL
                .setIsEnabled(true)
                .build();

        CapabilityNegotiationResponse response = CapabilityNegotiationResponse.newBuilder()
                .setHeader(ProtocolHeader.newBuilder()
                        .setVersion(ProtocolVersion.newBuilder().setMajor(1).setMinor(0).setPatch(0).build())
                        .setTraceId("neg_trace_01")
                        .build())
                .setIsCompatible(true)
                .setAgreedProtocolVersion(ProtocolVersion.newBuilder().setMajor(1).setMinor(0).setPatch(0).build())
                .addAcceptedCapabilities(acceptedCap)
                .addUnsupportedFeatures("FEATURE_BACKGROUND_SYNC") // Graceful unsupported response!
                .addUnsupportedFeatures("FEATURE_QUANTUM_COMPRESS")
                .build();

        byte[] capBytes = response.toByteArray();
        Files.write(FIXTURE_DIR.resolve("capability_response.bin"), capBytes);

        CapabilityNegotiationResponse parsed = CapabilityNegotiationResponse.parseFrom(capBytes);
        assertTrue(parsed.getIsCompatible());
        assertEquals(1, parsed.getAcceptedCapabilitiesCount());
        assertEquals("peerlink.transport.quic", parsed.getAcceptedCapabilities(0).getCapabilityName());
        assertEquals(2, parsed.getUnsupportedFeaturesCount());
        assertTrue(parsed.getUnsupportedFeaturesList().contains("FEATURE_BACKGROUND_SYNC"));
        assertTrue(parsed.getUnsupportedFeaturesList().contains("FEATURE_QUANTUM_COMPRESS"));
    }

    @Test
    void testUniversalEventEnvelope() throws Exception {
        SessionDescriptor session = SessionDescriptor.newBuilder()
                .setSessionId(SessionId.newBuilder().setValue("sess_live_123").build())
                .setInitiatorPeerId(PeerId.newBuilder().setValue("peer_alice").build())
                .setResponderPeerId(PeerId.newBuilder().setValue("peer_bob").build())
                .setState(SessionState.SESSION_STATE_ESTABLISHED)
                .setTransportType(TransportType.TRANSPORT_TYPE_DIRECT_QUIC)
                .setEstablishedAtUtcMs(1760000000000L)
                .setExpiresAtUtcMs(1760003600000L)
                .setProtocolVersion(ProtocolVersion.newBuilder().setMajor(1).setMinor(0).setPatch(0).build())
                .build();

        PeerLinkEvent event = PeerLinkEvent.newBuilder()
                .setEventId("evt_session_001")
                .setHeader(ProtocolHeader.newBuilder()
                        .setVersion(ProtocolVersion.newBuilder().setMajor(1).setMinor(0).setPatch(0).build())
                        .setTraceId("trace_evt_99")
                        .build())
                .setSessionEvent(session)
                .build();

        byte[] eventBytes = event.toByteArray();
        Files.write(FIXTURE_DIR.resolve("peerlink_event.bin"), eventBytes);

        PeerLinkEvent parsed = PeerLinkEvent.parseFrom(eventBytes);
        assertEquals("evt_session_001", parsed.getEventId());
        assertTrue(parsed.hasSessionEvent());
        assertEquals("sess_live_123", parsed.getSessionEvent().getSessionId().getValue());
        assertEquals(TransportType.TRANSPORT_TYPE_DIRECT_QUIC, parsed.getSessionEvent().getTransportType());
    }

    @Test
    void testUnknownFieldPreservationForwardCompatibility() throws Exception {
        // Build a message and inject unknown field tag 999
        ObjectReference.Builder builder = ObjectReference.newBuilder()
                .setObjectId(ObjectId.newBuilder().setValue("obj_unknown_test").build())
                .setLogicalName("forward_compat.dat");

        UnknownFieldSet unknownFields = UnknownFieldSet.newBuilder()
                .addField(999, UnknownFieldSet.Field.newBuilder()
                        .addVarint(123456L)
                        .build())
                .build();

        builder.setUnknownFields(unknownFields);
        ObjectReference original = builder.build();

        byte[] bytesWithUnknown = original.toByteArray();

        // Parse into ObjectReference
        ObjectReference parsed = ObjectReference.parseFrom(bytesWithUnknown);
        assertEquals("obj_unknown_test", parsed.getObjectId().getValue());

        // Verify the unknown field was preserved
        assertTrue(parsed.getUnknownFields().hasField(999));
        assertEquals(123456L, parsed.getUnknownFields().getField(999).getVarintList().get(0));

        // Re-serialize and verify byte identity
        byte[] roundtrip = parsed.toByteArray();
        assertArrayEquals(bytesWithUnknown, roundtrip);
    }

    @Test
    void testJavaDeserializesDartGeneratedArtifacts() throws Exception {
        Path dartOutDir = FIXTURE_DIR.resolve("dart-out");
        Path sessionFile = dartOutDir.resolve("dart_session.bin");
        Path opFile = dartOutDir.resolve("dart_operation.bin");
        Path errFile = dartOutDir.resolve("dart_error.bin");

        // Verify Dart generated artifacts exist (generated by flutter test)
        org.junit.jupiter.api.Assumptions.assumeTrue(Files.exists(sessionFile) && Files.exists(opFile) && Files.exists(errFile),
                "Dart generated artifacts not yet produced; skipping until flutter test runs");

        // 1. Parse and verify SessionDescriptor produced by Dart
        SessionDescriptor session = SessionDescriptor.parseFrom(Files.readAllBytes(sessionFile));
        assertEquals("sess_dart_to_java_999", session.getSessionId().getValue());
        assertEquals("peer_dart_mobile", session.getInitiatorPeerId().getValue());
        assertEquals("peer_java_desktop", session.getResponderPeerId().getValue());
        assertEquals(SessionState.SESSION_STATE_ESTABLISHED, session.getState());
        assertEquals(TransportType.TRANSPORT_TYPE_DIRECT_TCP_TLS, session.getTransportType());
        assertEquals(1760001000000L, session.getEstablishedAtUtcMs());
        assertEquals(1760004600000L, session.getExpiresAtUtcMs());
        assertEquals(1, session.getProtocolVersion().getMajor());

        // 2. Parse and verify OperationRecord produced by Dart
        OperationRecord op = OperationRecord.parseFrom(Files.readAllBytes(opFile));
        assertEquals("op_dart_durable_888", op.getOperationId().getValue());
        assertEquals(OperationIntent.OPERATION_INTENT_SEND, op.getIntent());
        assertEquals(OperationState.OPERATION_STATE_COMMITTED, op.getState());
        assertEquals("idemp_dart_seq_001", op.getIdempotencyKey());
        assertEquals("peer_dart_mobile", op.getActorPeerId().getValue());
        assertEquals(77L, op.getCausalClock().getLogicalCounter());
        assertEquals("peer_dart_mobile", op.getCausalClock().getActorPeerId());
        assertEquals(77L, op.getCausalClock().getPeerVectorsMap().get("peer_dart_mobile"));
        assertEquals(42L, op.getCausalClock().getPeerVectorsMap().get("peer_java_desktop"));
        assertEquals("crdt_delta", op.getParametersMap().get("sync_strategy"));

        // 3. Parse and verify ErrorDetail produced by Dart
        ErrorDetail err = ErrorDetail.parseFrom(Files.readAllBytes(errFile));
        assertEquals(ErrorCode.ERROR_CODE_TRANSPORT_DISCONNECTED, err.getCode());
        assertEquals("ERR_TRANSPORT_DISCONNECTED", err.getErrorName());
        assertEquals("Peer transport connection dropped", err.getHumanSummary());
        assertEquals("TCP/TLS connection to remote peer was interrupted unexpectedly", err.getHumanExplanation());
        assertEquals("Retry connection with exponential backoff or use relay", err.getSuggestedRecoveryAction());
        assertTrue(err.getIsRetryable());
        assertEquals("trace_dart_err_111", err.getTraceId());
    }
}

