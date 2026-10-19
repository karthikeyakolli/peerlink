package org.peerlink.core.transfer;

import org.peerlink.core.filesystem.PathSafetyValidator;
import org.peerlink.protocol.v1.DuplicateDestinationPolicy;

import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Resolves destination file paths in accordance with user-selected DuplicateDestinationPolicy.
 *
 * <p>Invariants:
 * <ul>
 *   <li>NEVER allow path traversal outside the destination root.</li>
 *   <li>NEVER silently rename due to OS or filename incompatibility.</li>
 *   <li>NEVER silently convert file types or extensions.</li>
 *   <li>If exact destination was requested with {@code FAIL_IF_EXISTS}, existing target throws {@link DestinationConflictException}.</li>
 * </ul>
 */
public final class DestinationConflictResolver {

    /**
     * Resolve the target destination path for a given item relative path and policy.
     *
     * @param destinationRoot The root destination directory
     * @param relativePath The normalized relative path of the item
     * @param policy The collision handling policy
     * @return Resolved destination Path
     * @throws DestinationConflictException if file exists and policy is FAIL_IF_EXISTS
     */
    public Path resolveDestination(Path destinationRoot, String relativePath, DuplicateDestinationPolicy policy)
            throws DestinationConflictException {

        // Validate and resolve target strictly inside destinationRoot
        Path target = PathSafetyValidator.resolveSafeDestination(destinationRoot, relativePath);

        if (!Files.exists(target)) {
            return target;
        }

        // File already exists at exact target
        return switch (policy) {
            case DUPLICATE_DESTINATION_POLICY_OVERWRITE -> target;

            case DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS,
                 DUPLICATE_DESTINATION_POLICY_UNSPECIFIED ->
                    throw new DestinationConflictException(
                            target,
                            "Destination file already exists and policy forbids overwrite: " + target);

            case DUPLICATE_DESTINATION_POLICY_RENAME_WITH_SUFFIX -> generateSuffixedPath(target);

            default -> throw new IllegalArgumentException("Unsupported duplicate destination policy: " + policy);
        };
    }

    private Path generateSuffixedPath(Path original) {
        Path parent = original.getParent();
        Path fileNamePath = original.getFileName();
        String fileName = fileNamePath != null ? fileNamePath.toString() : "file";

        String baseName;
        String extension;
        int dotIndex = fileName.lastIndexOf('.');
        if (dotIndex > 0 && dotIndex < fileName.length() - 1) {
            baseName = fileName.substring(0, dotIndex);
            extension = fileName.substring(dotIndex);
        } else {
            baseName = fileName;
            extension = "";
        }

        int suffix = 1;
        Path candidate;
        do {
            String candidateName = String.format("%s (%d)%s", baseName, suffix, extension);
            candidate = parent != null ? parent.resolve(candidateName) : Path.of(candidateName);
            suffix++;
        } while (Files.exists(candidate));

        return candidate;
    }
}
