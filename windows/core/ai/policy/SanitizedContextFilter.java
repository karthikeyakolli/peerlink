package org.peerlink.core.ai.policy;

import org.peerlink.core.ai.gateway.AiMessage;
import org.peerlink.core.ai.model.PrivacyLevel;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

/**
 * Enforces context minimization and prevents sensitive data leaks into external LLM prompts.
 *
 * INVARIANTS:
 * - HIGHLY_SENSITIVE context (keys, passphrases, tokens, private file contents) is NEVER sent.
 * - SENSITIVE context is redacted to minimal operational identifiers.
 */
public final class SanitizedContextFilter {

    private static final Pattern AUTH_TOKEN_PATTERN = Pattern.compile("(?i)(bearer\\s+[a-zA-Z0-9_\\-\\.]+|token[:=]\\s*[a-zA-Z0-9_\\-\\.]+|key[:=]\\s*[a-zA-Z0-9_\\-\\.]+)");
    private static final Pattern PRIVATE_KEY_PATTERN = Pattern.compile("(?i)(-----BEGIN [A-Z ]+PRIVATE KEY-----|[a-f0-9]{64}|ed25519:[a-zA-Z0-9+/=]{32,})");
    private static final Pattern SENSITIVE_PATH_PATTERN = Pattern.compile("(?i)([a-zA-Z]:\\\\users\\\\[^\\\\]+|/home/[^/]+)");
    private static final Pattern FILENAME_PATTERN = Pattern.compile("(?i)\\b[a-zA-Z0-9_\\-\\.]+\\.(pdf|docx|txt|jpg|png|zip|tar|gz|json|xml|csv|bin|exe|msi|apk)\\b");
    private static final Pattern PEER_ID_PATTERN = Pattern.compile("(?i)\\bpeer_[a-zA-Z0-9_\\-]+\\b");

    public static List<AiMessage> sanitize(List<AiMessage> messages) {
        return sanitize(messages, false);
    }

    public static List<AiMessage> sanitize(List<AiMessage> messages, boolean allowSensitiveDisclosure) {
        List<AiMessage> sanitized = new ArrayList<>();
        for (AiMessage msg : messages) {
            // Drop HIGHLY_SENSITIVE messages completely
            if (msg.getPrivacyLevel() == PrivacyLevel.HIGHLY_SENSITIVE) {
                continue;
            }

            String content = msg.getContent();
            // Always redact private keys before auth tokens so key blocks aren't partially matched by key=...
            content = PRIVATE_KEY_PATTERN.matcher(content).replaceAll("[REDACTED_CRYPTO_KEY]");
            content = AUTH_TOKEN_PATTERN.matcher(content).replaceAll("[REDACTED_AUTH_TOKEN]");

            if (!allowSensitiveDisclosure) {
                // If user has not authorized disclosure of sensitive metadata, redact filenames, peer IDs, and paths
                content = FILENAME_PATTERN.matcher(content).replaceAll("[REDACTED_FILENAME]");
                content = PEER_ID_PATTERN.matcher(content).replaceAll("[REDACTED_PEER_ID]");
                content = SENSITIVE_PATH_PATTERN.matcher(content).replaceAll("[REDACTED_USER_PATH]");
            } else if (msg.getPrivacyLevel() == PrivacyLevel.SENSITIVE) {
                // Even with disclosure authorized, scrub absolute OS user paths
                content = SENSITIVE_PATH_PATTERN.matcher(content).replaceAll("[REDACTED_USER_PATH]");
            }

            sanitized.add(new AiMessage(msg.getRole(), content, msg.getPrivacyLevel(), msg.getToolCalls()));
        }
        return sanitized;
    }

    public static boolean containsForbiddenSecrets(String text) {
        if (text == null) return false;
        return AUTH_TOKEN_PATTERN.matcher(text).find() || PRIVATE_KEY_PATTERN.matcher(text).find();
    }
}
