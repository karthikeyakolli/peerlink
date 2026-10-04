package org.peerlink.core.platform;

import java.util.Collections;
import java.util.List;
import java.util.Objects;

/**
 * Platform-independent notification request model.
 */
public final class PlatformNotification {
    public enum Priority {
        LOW,
        NORMAL,
        HIGH,
        CRITICAL
    }

    public enum Category {
        TRANSFER_COMPLETED,
        TRANSFER_FAILED,
        PAIRING_REQUEST,
        SECURITY_ALERT,
        SYNC_CONFLICT,
        GENERAL
    }

    private final String id;
    private final String title;
    private final String body;
    private final Priority priority;
    private final Category category;
    private final List<String> actions;
    private final String payloadPath;

    public PlatformNotification(
            String id,
            String title,
            String body,
            Priority priority,
            Category category,
            List<String> actions,
            String payloadPath) {
        this.id = Objects.requireNonNull(id, "id must not be null");
        this.title = Objects.requireNonNull(title, "title must not be null");
        this.body = Objects.requireNonNull(body, "body must not be null");
        this.priority = priority != null ? priority : Priority.NORMAL;
        this.category = category != null ? category : Category.GENERAL;
        this.actions = actions != null ? Collections.unmodifiableList(actions) : Collections.emptyList();
        this.payloadPath = payloadPath;
    }

    public String getId() {
        return id;
    }

    public String getTitle() {
        return title;
    }

    public String getBody() {
        return body;
    }

    public Priority getPriority() {
        return priority;
    }

    public Category getCategory() {
        return category;
    }

    public List<String> getActions() {
        return actions;
    }

    public String getPayloadPath() {
        return payloadPath;
    }

    @Override
    public String toString() {
        return "PlatformNotification{" +
                "id='" + id + '\'' +
                ", title='" + title + '\'' +
                ", priority=" + priority +
                ", category=" + category +
                '}';
    }
}
