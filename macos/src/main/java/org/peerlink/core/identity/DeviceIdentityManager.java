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

    public static final String DERIVATION_RULE_V1 = "v1:ed25519:sha256_16";

    /**
     * Loads an existing device identity from metadata storage and secure key store,
     * or provisions a brand new identity on first startup.
     * Enforces invariant: Never silently regenerate an identity if existing records are corrupted.
     */
    public static DeviceIdentityManager loadOrCreate(SecureKeyStore keyStore,
                                                     IdentityMetadataStore metadataStore,
                                                     String displayName,
                                                     DeviceType deviceType,
                                                     String osVersion,
                                                     String appVersion) throws KeyStorageException {
        Objects.requireNonNull(keyStore, "keyStore must not be null");
        Objects.requireNonNull(metadataStore, "metadataStore must not be null");

        if (metadataStore.hasIdentityMetadata()) {
            Map<String, String> meta = metadataStore.loadIdentityMetadata()
                    .orElseThrow(() -> new IdentityCorruptionException("Identity metadata reported present but failed to load"));

            String peerIdStr = meta.get("peer_id");
            String deviceIdStr = meta.get("device_id");
            String keyId = meta.get("key_id");
            String pubKeyHex = meta.get("public_key_hex");
            String fingerprint = meta.get("fingerprint");

            if (peerIdStr == null || peerIdStr.isBlank() ||
                deviceIdStr == null || deviceIdStr.isBlank() ||
                keyId == null || keyId.isBlank() ||
                pubKeyHex == null || pubKeyHex.isBlank()) {
                throw new IdentityCorruptionException("Corrupted identity metadata: missing mandatory fields; refusing silent regeneration");
            }

            byte[] privateKeyBytes = keyStore.getPrivateKey(keyId);
            if (privateKeyBytes == null || privateKeyBytes.length == 0) {
                throw new KeyStorageException("Private key [" + keyId + "] not found in KeyStore; refusing silent regeneration");
            }

            byte[] pubKeyBytes = java.util.HexFormat.of().parseHex(pubKeyHex);
            PeerCryptoSigner signer = PeerCryptoSigner.fromPrivateKeyBytes(keyId, privateKeyBytes, pubKeyBytes);

            // Verify integrity
            String computedFingerprint = signer.getFingerprintHex();
            if (fingerprint != null && !fingerprint.equalsIgnoreCase(computedFingerprint)) {
                throw new IdentityCorruptionException("Fingerprint mismatch between metadata [" + fingerprint +
                        "] and derived public key [" + computedFingerprint + "]; possible corruption");
            }

            long createdAt = meta.containsKey("created_at_ms") ? Long.parseLong(meta.get("created_at_ms")) : System.currentTimeMillis();
            CryptographicKey cryptoKey = signer.toProtobufKey(createdAt);

            DeviceIdentity device = DeviceIdentity.newBuilder()
                    .setDeviceId(DeviceId.newBuilder().setValue(deviceIdStr).build())
                    .setDeviceName(meta.getOrDefault("device_name", displayName + " Device"))
                    .setDeviceType(deviceType)
                    .setOsVersion(osVersion)
                    .setAppVersion(appVersion)
                    .setIdentityKey(cryptoKey)
                    .build();

            PeerIdentity peer = PeerIdentity.newBuilder()
                    .setPeerId(PeerId.newBuilder().setValue(peerIdStr).build())
                    .setDeviceId(device.getDeviceId())
                    .setDisplayName(meta.getOrDefault("display_name", displayName))
                    .setIdentityKey(cryptoKey)
                    .setFingerprintHex(computedFingerprint)
                    .setTrustLevel(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED)
                    .setPairedAtUtcMs(createdAt)
                    .build();

            log.info("Loaded existing device identity across restart: peerId={}, deviceId={}, fingerprint={}",
                    peerIdStr, deviceIdStr, computedFingerprint);

            return new DeviceIdentityManager(keyStore, signer, peer, device);
        }

        // First startup: provision brand new identity
        return createAndPersist(keyStore, metadataStore, displayName, deviceType, osVersion, appVersion);
    }

    private static DeviceIdentityManager createAndPersist(SecureKeyStore keyStore,
                                                          IdentityMetadataStore metadataStore,
                                                          String displayName,
                                                          DeviceType deviceType,
                                                          String osVersion,
                                                          String appVersion) throws KeyStorageException {
        String keyId = "key_ed25519_" + UUID.randomUUID();
        PeerCryptoSigner signer = PeerCryptoSigner.generate(keyId);

        // Store private key safely in SecureKeyStore
        keyStore.storePrivateKey(keyId, signer.getPrivateKeyBytes());

        // Derive stable Peer ID deterministically from Ed25519 public key (V1 rule)
        String peerIdStr = PeerCryptoSigner.deriveStablePeerId(signer.getPublicKeyEncoded());
        String deviceIdStr = "dev_" + UUID.randomUUID();
        long now = System.currentTimeMillis();

        CryptographicKey cryptoKey = signer.toProtobufKey(now);
        String fingerprint = signer.getFingerprintHex();
        String pubKeyHex = java.util.HexFormat.of().formatHex(signer.getPublicKeyEncoded());

        // Persist metadata
        Map<String, String> meta = Map.of(
                "peer_id", peerIdStr,
                "device_id", deviceIdStr,
                "display_name", displayName,
                "device_name", displayName + " Device",
                "device_type", deviceType.name(),
                "key_id", keyId,
                "public_key_hex", pubKeyHex,
                "fingerprint", fingerprint,
                "created_at_ms", String.valueOf(now),
                "derivation_version", DERIVATION_RULE_V1
        );
        metadataStore.saveIdentityMetadata(meta);

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

        log.info("Initialized and persisted new device identity: peerId={}, deviceId={}, fingerprint={}, rule={}",
                peerIdStr, deviceIdStr, fingerprint, DERIVATION_RULE_V1);

        return new DeviceIdentityManager(keyStore, signer, peer, device);
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

        // Derive stable Peer ID deterministically from Ed25519 public key (V1 rule)
        String peerIdStr = PeerCryptoSigner.deriveStablePeerId(signer.getPublicKeyEncoded());
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
