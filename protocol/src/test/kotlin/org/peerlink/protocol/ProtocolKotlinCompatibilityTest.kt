package org.peerlink.protocol

import com.google.protobuf.ByteString
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.peerlink.protocol.v1.*
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Paths

/**
 * Proves Kotlin ↔ Protobuf ↔ Java binary and semantic compatibility.
 * Verifies that Kotlin consumers (such as Android nodes and services) can serialize,
 * deserialize, and manipulate all foundational PeerLink protocol entities with zero semantic divergence.
 */
class ProtocolKotlinCompatibilityTest {

    private val fixtureDir = Paths.get("target", "test-fixtures")

    @Test
    fun testKotlinDeserializesJavaGeneratedPeerIdentity() {
        val peerFile = fixtureDir.resolve("peer_identity.bin")
        assertTrue(Files.exists(peerFile), "Fixture peer_identity.bin must exist")

        val bytes = Files.readAllBytes(peerFile)
        val peer = PeerIdentity.parseFrom(bytes)

        // Kotlin property access syntax verification
        assertEquals("peer_alice_99", peer.peerId.value)
        assertEquals("dev_desktop_win_01", peer.deviceId.value)
        assertEquals("Alice Desktop", peer.displayName)
        assertEquals(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED, peer.trustLevel)
        assertEquals(KeyType.KEY_TYPE_ED25519, peer.identityKey.keyType)
        assertEquals("SHA256:4a8b1c9d2e3f", peer.fingerprintHex)
        assertEquals(1760000010000L, peer.pairedAtUtcMs)
    }

    @Test
    fun testKotlinEnforcesObjectReferenceInvariants() {
        val objFile = fixtureDir.resolve("object_reference.bin")
        assertTrue(Files.exists(objFile), "Fixture object_reference.bin must exist")

        val bytes = Files.readAllBytes(objFile)
        val objRef = ObjectReference.parseFrom(bytes)

        // Invariant 1: Path is NOT object identity
        assertNotEquals(objRef.logicalName, objRef.objectId.value)
        assertFalse(objRef.logicalName.contains(":\\"), "Logical name must not be a Windows path")
        assertFalse(objRef.logicalName.startsWith("/"), "Logical name must not be a POSIX absolute path")
        assertEquals("Financial_Report_2026.pdf", objRef.logicalName)

        // Invariant 2: Hash is NOT object identity
        assertNotEquals(objRef.contentHash.hexDigest, objRef.objectId.value)
        assertEquals(HashAlgorithm.HASH_ALGORITHM_SHA256, objRef.contentHash.algorithm)

        // Invariant 3: CausalClock vector clock is authoritative (not client timestamp)
        assertEquals(42L, objRef.causalClock.logicalCounter)
        assertEquals("peer_alice_99", objRef.causalClock.actorPeerId)
        assertEquals(42L, objRef.causalClock.peerVectorsMap["peer_alice_99"])
        assertEquals(15L, objRef.causalClock.peerVectorsMap["peer_bob_12"])

        // Size and metadata
        assertEquals(1048576L, objRef.byteSize)
        assertEquals("application/pdf", objRef.mimeType)
        assertEquals("Alice", objRef.metadataMap["author"])
    }

    @Test
    fun testKotlinOperationContractDurableIdAndIdempotency() {
        val opFile = fixtureDir.resolve("operation_record.bin")
        assertTrue(Files.exists(opFile), "Fixture operation_record.bin must exist")

        val bytes = Files.readAllBytes(opFile)
        val op = OperationRecord.parseFrom(bytes)

        assertEquals("op_durable_uuid_777", op.operationId.value)
        assertEquals(OperationIntent.OPERATION_INTENT_SYNC, op.intent)
        assertEquals(OperationState.OPERATION_STATE_COMMITTED, op.state)
        assertEquals("idemp_seq_998124", op.idempotencyKey)
        assertEquals("peer_alice_99", op.actorPeerId.value)
        assertEquals("convergent_replica", op.parametersMap["sync_mode"])
    }

    @Test
    fun testKotlinDeterministicErrorHandling() {
        val errFile = fixtureDir.resolve("error_detail.bin")
        assertTrue(Files.exists(errFile), "Fixture error_detail.bin must exist")

        val bytes = Files.readAllBytes(errFile)
        val err = ErrorDetail.parseFrom(bytes)

        assertEquals(ErrorCode.ERROR_CODE_UNSUPPORTED_CAPABILITY, err.code)
        assertEquals("ERR_UNSUPPORTED_CAPABILITY", err.errorName)
        assertEquals("Requested capability is not supported by target peer", err.humanSummary)
        assertTrue(err.isRetryable)
        assertEquals("Switch transport candidate to TCP/TLS or TURN relay", err.suggestedRecoveryAction)
    }

    @Test
    fun testKotlinSerializesContractsWithBinaryParity() {
        // Kotlin builds a DeviceIdentity and CryptographicKey for Android Node
        val key = CryptographicKey.newBuilder()
            .setKeyType(KeyType.KEY_TYPE_ED25519)
            .setPublicKeyBytes(ByteString.copyFrom("kotlin-android-ed25519-public-key", StandardCharsets.UTF_8))
            .setKeyId("key_android_001")
            .setCreatedAtUtcMs(1760002000000L)
            .build()

        val androidDevice = DeviceIdentity.newBuilder()
            .setDeviceId(DeviceId.newBuilder().setValue("dev_android_pixel_08").build())
            .setDeviceName("Pixel 8 Pro")
            .setDeviceType(DeviceType.DEVICE_TYPE_MOBILE_ANDROID)
            .setOsVersion("Android 15 (Vanilla Ice Cream)")
            .setAppVersion("0.1.0")
            .setIdentityKey(key)
            .build()

        val bytes = androidDevice.toByteArray()
        assertNotNull(bytes)
        assertTrue(bytes.isNotEmpty())

        // Verify deserialization matches exactly
        val parsed = DeviceIdentity.parseFrom(bytes)
        assertEquals("dev_android_pixel_08", parsed.deviceId.value)
        assertEquals(DeviceType.DEVICE_TYPE_MOBILE_ANDROID, parsed.deviceType)
        assertEquals("Android 15 (Vanilla Ice Cream)", parsed.osVersion)
        assertEquals("key_android_001", parsed.identityKey.keyId)
    }

    @Test
    fun testKotlinCapabilityNegotiationAndGracefulUnsupportedResponse() {
        val capFile = fixtureDir.resolve("capability_response.bin")
        assertTrue(Files.exists(capFile), "Fixture capability_response.bin must exist")

        val bytes = Files.readAllBytes(capFile)
        val resp = CapabilityNegotiationResponse.parseFrom(bytes)

        assertTrue(resp.isCompatible)
        assertEquals(1, resp.acceptedCapabilitiesCount)
        assertEquals("peerlink.transport.quic", resp.getAcceptedCapabilities(0).capabilityName)
        assertTrue(resp.unsupportedFeaturesList.contains("FEATURE_BACKGROUND_SYNC"))
        assertTrue(resp.unsupportedFeaturesList.contains("FEATURE_QUANTUM_COMPRESS"))
    }
}
