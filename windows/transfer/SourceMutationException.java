package org.peerlink.core.transfer;

/**
 * Thrown when a source file is mutated (size, modification time, or content hash changed)
 * while a transfer operation is in progress.
 */
public class SourceMutationException extends Exception {
    private final String relativePath;
    private final String detail;

    public SourceMutationException(String relativePath, String detail) {
        super(String.format("Source file mutated during in-flight transfer [%s]: %s", relativePath, detail));
        this.relativePath = relativePath;
        this.detail = detail;
    }

    public String getRelativePath() {
        return relativePath;
    }

    public String getDetail() {
        return detail;
    }
}
