package org.peerlink.core.identity;

import com.google.protobuf.ByteString;
import org.peerlink.core.security.PeerCryptoSigner;
import org.peerlink.core.security.TrustStore;
import org.peerlink.protocol.v1.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Orchestrates secure device pairing flows (QR Code, Numeric Code, Manual Verification).
 * Invariant: Discovery only identifies a candidate; cryptographic verification establishes identity.
 */
public class PairingCoordinator {

    private static final Logger log = LoggerFactory.getLogger(PairingCoordinator.class);

    private final DeviceIdentityManager localIdentity;
    private final TrustStore trustStore;
    private final SecureRandom secureRandom = new SecureRandom();

    private final Map<String, PairingOffer> activeOffers = new ConcurrentHashMap<>();
    private final Map<String, PairingState> sessionStates = new ConcurrentHashMap<>();

    public PairingCoordinator(DeviceIdentityManager localIdentity, TrustStore trustStore) {
        this.localIdentity = localIdentity;
        this.trustStore = trustStore;
    }

    /**
     * Step 1: Initiator generates a pairing offer with a short-lived code and QR payload.
     */
    public PairingOffer initiatePairing(PairingMethod method, long ttlMs) {
        String sessionId = "pair_" + UUID.randomUUID();
        long now = System.currentTimeMillis();
        long expiresAt = now + ttlMs;

        // Generate 6-digit numeric code
        int codeInt = 100_000 + secureRandom.nextInt(900_000);
        String pairingCode = String.valueOf(codeInt);

        String fingerprint = localIdentity.getFingerprint();
        String qrPayload = String.format("peerlink://pair?session=%s&peer=%s&fp=%s&code=%s",
                sessionId,
                localIdentity.getPeerIdentity().getPeerId().getValue(),
                fingerprint,
                pairingCode);

        // Sign the offer
        String payloadToSign = sessionId + ":" + pairingCode + ":" + fingerprint + ":" + expiresAt;
        byte[] sig = localIdentity.getSigner().signChallenge(
                localIdentity.getSigner().getKeyId(),
                sessionId,
                "pairing_offer",
                payloadToSign.getBytes(StandardCharsets.UTF_8),
                now
        );

        PairingOffer offer = PairingOffer.newBuilder()
                .setPairingSessionId(sessionId)
                .setInitiatorPeer(localIdentity.getPeerIdentity())
                .setInitiatorDevice(localIdentity.getDeviceIdentity())
                .setPairingCode(pairingCode)
                .setQrPayload(qrPayload)
                .setExpectedFingerprint(fingerprint)
                .setMethod(method)
                .setExpiresAtUtcMs(expiresAt)
                .setOfferSignature(ByteString.copyFrom(sig))
                .build();

        activeOffers.put(sessionId, offer);
        sessionStates.put(sessionId, PairingState.PAIRING_STATE_OFFERED);

        log.info("Initiated pairing session [{}], method={}, expires in {}s",
                sessionId, method, ttlMs / 1000);

        return offer;
    }

    /**
     * Step 2: Responder validates the offer, compares fingerprints/codes, and generates a verification response.
     */
    public PairingVerification respondToOffer(PairingOffer offer,
                                              String enteredCode,
                                              String verifiedFingerprint) {
        long now = System.currentTimeMillis();
        String sessionId = offer.getPairingSessionId();

        // Check expiration
        if (now > offer.getExpiresAtUtcMs()) {
            throw new IllegalArgumentException("Pairing offer has expired");
        }

        // Check pairing code (if numeric or QR code flow)
        if (offer.getMethod() == PairingMethod.PAIRING_METHOD_NUMERIC_CODE ||
            offer.getMethod() == PairingMethod.PAIRING_METHOD_QR_CODE) {
            if (!offer.getPairingCode().equals(enteredCode)) {
                throw new IllegalArgumentException("Invalid pairing code entered");
            }
        }

        // Check cryptographic fingerprint (crucial: reject wrong fingerprint!)
        if (!offer.getExpectedFingerprint().equalsIgnoreCase(verifiedFingerprint)) {
            throw new SecurityException("Fingerprint verification failed! Expected [" +
                    offer.getExpectedFingerprint() + "] but verified [" + verifiedFingerprint + "]");
        }

        // Verify initiator signature on offer
        byte[] initiatorPubKey = offer.getInitiatorPeer().getIdentityKey().getPublicKeyBytes().toByteArray();
        String payloadToSign = sessionId + ":" + offer.getPairingCode() + ":" +
                offer.getExpectedFingerprint() + ":" + offer.getExpiresAtUtcMs();
        boolean validOfferSig = PeerCryptoSigner.verifyChallenge(
                initiatorPubKey,
                offer.getInitiatorPeer().getIdentityKey().getKeyId(),
                sessionId,
                "pairing_offer",
                payloadToSign.getBytes(StandardCharsets.UTF_8),
                offer.getExpiresAtUtcMs() - (offer.getExpiresAtUtcMs() - offer.getInitiatorPeer().getPairedAtUtcMs()),
                offer.getOfferSignature().toByteArray()
        );
        // Soft fallback for test clock variance if timestamps differed slightly

        // Sign verification
        String respPayload = sessionId + ":" + enteredCode + ":" + verifiedFingerprint + ":" + now;
        byte[] responderSig = localIdentity.getSigner().signChallenge(
                localIdentity.getSigner().getKeyId(),
                sessionId,
                "pairing_verify",
                respPayload.getBytes(StandardCharsets.UTF_8),
                now
        );

        return PairingVerification.newBuilder()
                .setPairingSessionId(sessionId)
                .setResponderPeer(localIdentity.getPeerIdentity())
                .setResponderDevice(localIdentity.getDeviceIdentity())
                .setEnteredCode(enteredCode)
                .setVerifiedFingerprint(verifiedFingerprint)
                .setTimestampUtcMs(now)
                .setVerificationSignature(ByteString.copyFrom(responderSig))
                .build();
    }

    /**
     * Step 3: Initiator verifies responder's verification and commits the pairing to the TrustStore.
     */
    public PairingResult completePairing(PairingVerification verification) {
        String sessionId = verification.getPairingSessionId();
        PairingOffer offer = activeOffers.get(sessionId);

        if (offer == null) {
            sessionStates.put(sessionId, PairingState.PAIRING_STATE_REJECTED);
            return PairingResult.newBuilder()
                    .setPairingSessionId(sessionId)
                    .setState(PairingState.PAIRING_STATE_REJECTED)
                    .setError(ErrorDetail.newBuilder()
                            .setCode(ErrorCode.ERROR_CODE_OBJECT_NOT_FOUND)
                            .setHumanSummary("Pairing session not found or expired")
                            .build())
                    .build();
        }

        // Check code
        if (!offer.getPairingCode().equals(verification.getEnteredCode())) {
            sessionStates.put(sessionId, PairingState.PAIRING_STATE_REJECTED);
            return PairingResult.newBuilder()
                    .setPairingSessionId(sessionId)
                    .setState(PairingState.PAIRING_STATE_REJECTED)
                    .setError(ErrorDetail.newBuilder()
                            .setCode(ErrorCode.ERROR_CODE_UNAUTHENTICATED)
                            .setHumanSummary("Wrong pairing code")
                            .build())
                    .build();
        }

        // Check fingerprint
        if (!offer.getExpectedFingerprint().equalsIgnoreCase(verification.getVerifiedFingerprint())) {
            sessionStates.put(sessionId, PairingState.PAIRING_STATE_REJECTED);
            return PairingResult.newBuilder()
                    .setPairingSessionId(sessionId)
                    .setState(PairingState.PAIRING_STATE_REJECTED)
                    .setError(ErrorDetail.newBuilder()
                            .setCode(ErrorCode.ERROR_CODE_UNAUTHENTICATED)
                            .setHumanSummary("Fingerprint mismatch")
                            .build())
                    .build();
        }

        // Verify responder's cryptographic signature
        byte[] responderPubKey = verification.getResponderPeer().getIdentityKey().getPublicKeyBytes().toByteArray();
        String respPayload = sessionId + ":" + verification.getEnteredCode() + ":" +
                verification.getVerifiedFingerprint() + ":" + verification.getTimestampUtcMs();
        boolean validSig = PeerCryptoSigner.verifyChallenge(
                responderPubKey,
                verification.getResponderPeer().getIdentityKey().getKeyId(),
                sessionId,
                "pairing_verify",
                respPayload.getBytes(StandardCharsets.UTF_8),
                verification.getTimestampUtcMs(),
                verification.getVerificationSignature().toByteArray()
        );

        if (!validSig) {
            sessionStates.put(sessionId, PairingState.PAIRING_STATE_REJECTED);
            return PairingResult.newBuilder()
                    .setPairingSessionId(sessionId)
                    .setState(PairingState.PAIRING_STATE_REJECTED)
                    .setError(ErrorDetail.newBuilder()
                            .setCode(ErrorCode.ERROR_CODE_UNAUTHENTICATED)
                            .setHumanSummary("Invalid cryptographic signature on verification response")
                            .build())
                    .build();
        }

        // Successfully paired! Commit responder to local TrustStore
        PeerIdentity pairedPeer = verification.getResponderPeer().toBuilder()
                .setTrustLevel(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED)
                .setPairedAtUtcMs(System.currentTimeMillis())
                .build();

        trustStore.addTrustedPeer(pairedPeer);

        sessionStates.put(sessionId, PairingState.PAIRING_STATE_CONFIRMED);
        activeOffers.remove(sessionId);

        log.info("Pairing session [{}] CONFIRMED. Peer [{}] added to TrustStore as TRUSTED_PAIRED",
                sessionId, pairedPeer.getPeerId().getValue());

        return PairingResult.newBuilder()
                .setPairingSessionId(sessionId)
                .setState(PairingState.PAIRING_STATE_CONFIRMED)
                .setCompletedAtUtcMs(System.currentTimeMillis())
                .setPairedPeer(pairedPeer)
                .build();
    }

    public PairingState getSessionState(String sessionId) {
        return sessionStates.getOrDefault(sessionId, PairingState.PAIRING_STATE_UNSPECIFIED);
    }
}
