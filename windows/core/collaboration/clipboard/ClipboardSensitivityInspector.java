package org.peerlink.core.collaboration.clipboard;

import java.nio.charset.StandardCharsets;
import java.util.regex.Pattern;

/**
 * Inspects clipboard text to prevent inadvertent transmission of credentials or PII.
 */
public final class ClipboardSensitivityInspector {

    private static final Pattern PRIVATE_KEY_PATTERN = Pattern.compile("-----BEGIN (?:RSA )?PRIVATE KEY-----");
    private static final Pattern JWT_PATTERN = Pattern.compile("eyJ[a-zA-Z0-9_-]{4,}\\.[a-zA-Z0-9_-]{4,}");
    private static final Pattern API_KEY_PATTERN = Pattern.compile("(?:ghp_[a-zA-Z0-9]{36}|AKIA[0-9A-Z]{16})");
    private static final Pattern CREDIT_CARD_PATTERN = Pattern.compile("\\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13})\\b");

    public record SensitivityResult(boolean isSensitive, String matchedCategory) {}

    public static SensitivityResult inspect(byte[] payload, ClipboardItemType type) {
        if (type != ClipboardItemType.TEXT && type != ClipboardItemType.URL) {
            return new SensitivityResult(false, null);
        }

        String text = new String(payload, StandardCharsets.UTF_8);

        if (PRIVATE_KEY_PATTERN.matcher(text).find()) {
            return new SensitivityResult(true, "PRIVATE_KEY");
        }
        if (JWT_PATTERN.matcher(text).find()) {
            return new SensitivityResult(true, "JWT_AUTH_TOKEN");
        }
        if (API_KEY_PATTERN.matcher(text).find()) {
            return new SensitivityResult(true, "API_SECRET_KEY");
        }
        if (CREDIT_CARD_PATTERN.matcher(text).find()) {
            return new SensitivityResult(true, "CREDIT_CARD_NUMBER");
        }
        if (text.toLowerCase().contains("password=") || text.toLowerCase().contains("passwd:") || text.toLowerCase().contains("secret_key:")) {
            return new SensitivityResult(true, "CREDENTIAL_STRING");
        }

        return new SensitivityResult(false, null);
    }
}