package org.peerlink.core.identity;

import com.google.protobuf.ByteString;
import org.peerlink.core.security.KeyStorageException;
import org.peerlink.core.security.PeerCryptoSigner;
import org.peerlink.core.security.SecureKeyStore;
import org.peerlink.protocol.v1.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;

/**
 * Manages local device cryptographic identity, stable Peer ID, account binding, and key lifecycle.
 * Invariant: Supabase account identity != PeerLink cryptographic device identity.
 */
public class DeviceIdentityManager {

    private static final Logger log = LoggerFactory.getLogger(DeviceIdentityManager.class);

    private final SecureKeyStore keyStore;
    private final PeerCryptoSigner signer;
    private final PeerIdentity peerIdentity;
    private final DeviceIdentity deviceIdentity;

    private DeviceIdentityManager(SecureKeyStore keyStore,
                                 PeerCryptoSigner signer,
                                 PeerIdentity peerIdentity,
                                 DeviceIdentity deviceIdentity) {
        this.keyStore = keyStore;
        this.signer = signer;
        this.peerIdentity = peerIdentity;
        this.deviceIdentity = deviceIdentity;
    }

    /**
     * Initializes a brand new device identity with fresh Ed25519 keypair and stable IDs.
     */
    public static DeviceIdentityManager createNew(SecureKeyStore keyStore,
                                                  String displayName,
                                                  DeviceType deviceType,
                                                  String osVersion,
                                                  String appVersion) throws KeyStorageException {
        String keyId = "key_ed25519_" + UUID.randomUUID();
        PeerCryptoSigner signer = PeerCryptoSigner.generate(keyId);

        // Store private key safely in SecureKeyStore
        keyStore.storePrivateKey(keyId, signer.getPrivateKeyBytes());

        String peerIdStr = "peer_" + UUID.randomUUID();
        String deviceIdStr = "dev_" + UUID.randomUUID();
        long now = System.currentTimeMillis();

        CryptographicKey cryptoKey = signer.toProtobufKey(now);
        String fingerprint = signer.getFingerprintHex();

        DeviceIdentity device = DeviceIdentity.newBuilder()
                .setDeviceId(DeviceId.newBuilder().setValue(deviceIdStr).build())
                .setDeviceName(displayName + " Device")
                .setDeviceType(deviceType)
                .setOsVersion(osVersion)
                .setAppVersion(appVersion)
                .setIdentityKey(cryptoKey)
                .build();

        PeerIdentity peer = PeerIdentity.newBuilder()
                .setPeerId(PeerId.newBuilder().setValue(peerIdStr).build())
                .setDeviceId(device.getDeviceId())
                .setDisplayName(displayName)
                .setIdentityKey(cryptoKey)
                .setFingerprintHex(fingerprint)
                .setTrustLevel(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED)
                .setPairedAtUtcMs(now)
                .build();

        log.info("Initialized new device identity: peerId={}, deviceId={}, fingerprint={}",
                peerIdStr, deviceIdStr, fingerprint);

        return new DeviceIdentityManager(keyStore, signer, peer, device);
    }

    /**
     * Creates a DeviceIdentityManager with an existing signer (useful for tests or reloads).
     */
    public static DeviceIdentityManager fromExisting(SecureKeyStore keyStore,
                                                     PeerCryptoSigner signer,
                                                     String peerIdStr,
                                                     String deviceIdStr,
                                                     String displayName,
                                                     DeviceType deviceType) {
        long now = System.currentTimeMillis();
        CryptographicKey cryptoKey = signer.toProtobufKey(now);
        String fingerprint = signer.getFingerprintHex();

        DeviceIdentity device = DeviceIdentity.newBuilder()
                .setDeviceId(DeviceId.newBuilder().setValue(deviceIdStr).build())
                .setDeviceName(displayName + " Device")
                .setDeviceType(deviceType)
                .setIdentityKey(cryptoKey)
                .build();

        PeerIdentity peer = PeerIdentity.newBuilder()
                .setPeerId(PeerId.newBuilder().setValue(peerIdStr).build())
                .setDeviceId(device.getDeviceId())
                .setDisplayName(displayName)
                .setIdentityKey(cryptoKey)
                .setFingerprintHex(fingerprint)
                .setTrustLevel(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED)
                .setPairedAtUtcMs(now)
                .build();

        return new DeviceIdentityManager(keyStore, signer, peer, device);
    }

    public PeerCryptoSigner getSigner() {
        return signer;
    }

    public PeerIdentity getPeerIdentity() {
        return peerIdentity;
    }

    public DeviceIdentity getDeviceIdentity() {
        return deviceIdentity;
    }

    public String getFingerprint() {
        return signer.getFingerprintHex();
    }

    /**
     * Binds an external Supabase account identity to this device identity without coupling trust anchors.
     */
    public PeerIdentity bindAccount(String accountId, String accountEmail) {
        long now = System.currentTimeMillis();
        String payloadToSign = "bind_account:" + accountId + ":" + accountEmail + ":" + now;
        byte[] sig = signer.signChallenge(
                signer.getKeyId(),
                deviceIdentity.getDeviceId().getValue(),
                peerIdentity.getPeerId().getValue(),
                payloadToSign.getBytes(StandardCharsets.UTF_8),
                now
        );

        AccountBinding binding = AccountBinding.newBuilder()
                .setAccountId(accountId)
                .setAccountEmail(accountEmail)
                .setBoundAtUtcMs(now)
                .setOwnershipProofSignature(ByteString.copyFrom(sig))
                .build();

        log.info("Bound cryptographic identity [{}] to account [{}]",
                peerIdentity.getPeerId().getValue(), accountEmail);

        return peerIdentity.toBuilder().setAccountBinding(binding).build();
    }

    /**
     * Generates a device replacement/recovery authorization record.
     */
    public DeviceReplacementRecord authorizeDeviceReplacement(DeviceId newDeviceId, String recoveryToken) {
        long now = System.currentTimeMillis();
        String payload = "replace_device:" + deviceIdentity.getDeviceId().getValue() + ":" +
                newDeviceId.getValue() + ":" + recoveryToken + ":" + now;

        byte[] sig = signer.signChallenge(
                signer.getKeyId(),
                deviceIdentity.getDeviceId().getValue(),
                peerIdentity.getPeerId().getValue(),
                payload.getBytes(StandardCharsets.UTF_8),
                now
        );

        return DeviceReplacementRecord.newBuilder()
                .setOldDeviceId(deviceIdentity.getDeviceId())
                .setNewDeviceId(newDeviceId)
                .setPeerId(peerIdentity.getPeerId())
                .setReplacementToken(recoveryToken)
                .setReplacedAtUtcMs(now)
                .setAuthorizationSignature(ByteString.copyFrom(sig))
                .build();
    }

    /**
     * Validates identity record completeness and detects malformed records.
     */
    public static void validateIdentityRecord(PeerIdentity identity) {
        Objects.requireNonNull(identity, "PeerIdentity must not be null");
        if (!identity.hasPeerId() || identity.getPeerId().getValue().isBlank()) {
            throw new IllegalArgumentException("Malformed identity: missing peer_id");
        }
        if (!identity.hasIdentityKey() || identity.getIdentityKey().getPublicKeyBytes().isEmpty()) {
            throw new IllegalArgumentException("Malformed identity: missing public key");
        }
        if (identity.getFingerprintHex().isBlank() || !identity.getFingerprintHex().startsWith("SHA256:")) {
            throw new IllegalArgumentException("Malformed identity: invalid SHA256 fingerprint format");
        }
    }
}
