package org.peerlink.core.ai.policy;

import java.util.regex.Pattern;

/**
 * Defends against prompt injection and instruction override attempts in untrusted content.
 */
public final class PromptInjectionGuard {

    private static final Pattern INJECTION_PATTERNS = Pattern.compile(
            "(?i)(ignore\\s+(all\\s+)?previous\\s+instructions" +
            "|disregard\\s+prior\\s+rules" +
            "|you\\s+are\\s+now\\s+(in\\s+developer\\s+mode|root|admin|unrestricted)" +
            "|override\\s+system\\s+prompt" +
            "|system\\s+override" +
            "|execute\\s+(command|shell|terminal|bash|powershell|cmd|binary)" +
            "|grant\\s+(trust|admin|root|access|permission)" +
            "|authorize\\s+peer" +
            "|bypass\\s+(safety|security|policy|guardrails|confirmation)" +
            "|disable\\s+scanner" +
            "|delete\\s+(all\\s+)?files" +
            "|rm\\s+-rf" +
            "|del\\s+/f\\s+/s" +
            "|format\\s+[a-z]:)"
    );

    /**
     * Encloses untrusted data inside non-executable boundary markers.
     */
    public static String wrapUntrustedInput(String input, String sourceTag) {
        if (input == null) return "";
        return "<untrusted_input source=\"" + sourceTag + "\">\n" +
                input.replace("<untrusted_input", "&lt;untrusted_input")
                        .replace("</untrusted_input>", "&lt;/untrusted_input&gt;") +
                "\n</untrusted_input>";
    }

    /**
     * Inspects text for obvious prompt-injection override attempts.
     */
    public static boolean containsInjectionPattern(String text) {
        if (text == null) return false;
        return INJECTION_PATTERNS.matcher(text).find();
    }
}
