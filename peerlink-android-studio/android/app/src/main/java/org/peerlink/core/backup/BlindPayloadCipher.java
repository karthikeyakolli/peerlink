package org.peerlink.core.backup;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.security.GeneralSecurityException;
import java.security.SecureRandom;
import java.util.Arrays;

/**
 * Client-side cipher for Blind Encrypted Backup.
 * Uses AES-256-GCM authenticated encryption.
 * Target holds only ciphertext and has NO decryption authority.
 * Transport encryption and storage encryption are conceptually separate!
 */
public final class BlindPayloadCipher {
    private static final String AES = "AES";
    private static final String AES_GCM = "AES/GCM/NoPadding";
    private static final int GCM_IV_LENGTH = 12;
    private static final int GCM_TAG_LENGTH = 128; // bits
    private static final SecureRandom RANDOM = new SecureRandom();

    public static byte[] generateKey() {
        byte[] key = new byte[32]; // 256 bits
        RANDOM.nextBytes(key);
        return key;
    }

    public static byte[] encrypt(byte[] plaintext, byte[] key) throws GeneralSecurityException {
        if (key.length != 32) throw new IllegalArgumentException("Key must be 32 bytes for AES-256");
        byte[] iv = new byte[GCM_IV_LENGTH];
        RANDOM.nextBytes(iv);

        Cipher cipher = Cipher.getInstance(AES_GCM);
        SecretKey secretKey = new SecretKeySpec(key, AES);
        cipher.init(Cipher.ENCRYPT_MODE, secretKey, new GCMParameterSpec(GCM_TAG_LENGTH, iv));
        byte[] ciphertext = cipher.doFinal(plaintext);

        byte[] result = new byte[iv.length + ciphertext.length];
        System.arraycopy(iv, 0, result, 0, iv.length);
        System.arraycopy(ciphertext, 0, result, iv.length, ciphertext.length);
        return result;
    }

    public static byte[] decrypt(byte[] payload, byte[] key) throws GeneralSecurityException {
        if (key.length != 32) throw new IllegalArgumentException("Key must be 32 bytes for AES-256");
        if (payload.length < GCM_IV_LENGTH) throw new IllegalArgumentException("Payload too short");

        byte[] iv = Arrays.copyOfRange(payload, 0, GCM_IV_LENGTH);
        byte[] ciphertext = Arrays.copyOfRange(payload, GCM_IV_LENGTH, payload.length);

        Cipher cipher = Cipher.getInstance(AES_GCM);
        SecretKey secretKey = new SecretKeySpec(key, AES);
        cipher.init(Cipher.DECRYPT_MODE, secretKey, new GCMParameterSpec(GCM_TAG_LENGTH, iv));
        return cipher.doFinal(ciphertext);
    }
}