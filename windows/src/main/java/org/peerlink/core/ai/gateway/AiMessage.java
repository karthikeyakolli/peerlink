package org.peerlink.core.ai.gateway;

import org.peerlink.core.ai.model.PrivacyLevel;

import java.util.Collections;
import java.util.List;
import java.util.Objects;

/**
 * Message in an AI conversation context.
 */
public final class AiMessage {
    private final AiRole role;
    private final String content;
    private final PrivacyLevel privacyLevel;
    private final List<AiToolCall> toolCalls;

    public AiMessage(AiRole role, String content) {
        this(role, content, PrivacyLevel.NORMAL, Collections.emptyList());
    }

    public AiMessage(AiRole role, String content, PrivacyLevel privacyLevel) {
        this(role, content, privacyLevel, Collections.emptyList());
    }

    public AiMessage(AiRole role, String content, PrivacyLevel privacyLevel, List<AiToolCall> toolCalls) {
        this.role = Objects.requireNonNull(role, "role is required");
        this.content = content != null ? content : "";
        this.privacyLevel = privacyLevel != null ? privacyLevel : PrivacyLevel.NORMAL;
        this.toolCalls = toolCalls != null ? Collections.unmodifiableList(toolCalls) : Collections.emptyList();
    }

    public AiRole getRole() {
        return role;
    }

    public String getContent() {
        return content;
    }

    public PrivacyLevel getPrivacyLevel() {
        return privacyLevel;
    }

    public List<AiToolCall> getToolCalls() {
        return toolCalls;
    }

    @Override
    public String toString() {
        return "AiMessage{role=" + role + ", level=" + privacyLevel + ", length=" + content.length() + "}";
    }
}
