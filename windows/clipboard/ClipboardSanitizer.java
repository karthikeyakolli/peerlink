package org.peerlink.core.clipboard;

import java.util.regex.Pattern;

public final class ClipboardSanitizer {
    private static final Pattern CARD_PATTERN = Pattern.compile("\\b(?:\\d[ -]*?){13,16}\\b");
    private static final Pattern KEY_PATTERN = Pattern.compile("(?i)(?:api_key|secret|password|bearer)\\s*[:=]\\s*\\S+");

    public static boolean containsSensitiveData(String text) {
        if (text == null) return false;
        return CARD_PATTERN.matcher(text).find() || KEY_PATTERN.matcher(text).find();
    }

    public static String sanitize(String text) {
        if (text == null) return "";
        if (containsSensitiveData(text)) {
            return "[REDACTED - SENSITIVE CONTENT DETECTED]";
        }
        return text;
    }
}
