package org.peerlink.core.collaboration.smart;

import java.nio.file.Path;
import java.util.Objects;

/**
 * Monitored folder that triggers automated action when files are deposited.
 */
public final class SmartDropZone {
    private final String dropZoneId;
    private final Path folderPath;
    private final String targetPeerId;
    private final TransferRecipe recipe;
    private final boolean autoDispatch;

    public SmartDropZone(String dropZoneId, Path folderPath, String targetPeerId, TransferRecipe recipe, boolean autoDispatch) {
        this.dropZoneId = Objects.requireNonNull(dropZoneId, "dropZoneId is required");
        this.folderPath = Objects.requireNonNull(folderPath, "folderPath is required");
        this.targetPeerId = Objects.requireNonNull(targetPeerId, "targetPeerId is required");
        this.recipe = recipe;
        this.autoDispatch = autoDispatch;
    }

    public String getDropZoneId() { return dropZoneId; }
    public Path getFolderPath() { return folderPath; }
    public String getTargetPeerId() { return targetPeerId; }
    public TransferRecipe getRecipe() { return recipe; }
    public boolean isAutoDispatch() { return autoDispatch; }
}