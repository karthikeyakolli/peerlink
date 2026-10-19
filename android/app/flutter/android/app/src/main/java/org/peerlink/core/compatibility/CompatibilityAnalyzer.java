package org.peerlink.core.compatibility;

import java.util.*;
import java.util.regex.Pattern;

/**
 * Compatibility Analyzer.
 *
 * Checks file compatibility across 6 categories:
 * - transfer
 * - storage
 * - open
 * - application
 * - execution
 * - metadata
 *
 * INVARIANTS:
 * Never silently:
 * - execute
 * - convert
 * - rename
 * - delete
 * - strip metadata
 */
public final class CompatibilityAnalyzer {

    private static final Set<String> WINDOWS_RESERVED_NAMES = Set.of(
            "CON", "PRN", "AUX", "NUL",
            "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
            "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
    );

    private static final Pattern WINDOWS_ILLEGAL_CHARS = Pattern.compile("[<>:\"/\\\\|?*]");

    public enum TargetOperatingSystem {
        WINDOWS,
        LINUX,
        MACOS,
        ANDROID
    }

    public static CompatibilityReport analyze(
            String relativePath,
            long sizeBytes,
            Map<String, String> metadataAttributes,
            TargetOperatingSystem targetOs
    ) {
        List<CompatibilityIssue> issues = new ArrayList<>();

        // 1. STORAGE: Filename & Path compatibility
        checkStorageCompatibility(relativePath, sizeBytes, targetOs, issues);

        // 2. METADATA: Permission & attribute compatibility
        checkMetadataCompatibility(metadataAttributes, targetOs, issues);

        // 3. EXECUTION: Binary/Script compatibility
        checkExecutionCompatibility(relativePath, targetOs, issues);

        // 4. TRANSFER: Chunk & file size limits
        checkTransferCompatibility(sizeBytes, issues);

        // Determine overall result
        CompatibilityResult overall = CompatibilityResult.COMPATIBLE;
        boolean userDecision = false;

        for (CompatibilityIssue issue : issues) {
            if (issue.result() == CompatibilityResult.INCOMPATIBLE) {
                overall = CompatibilityResult.INCOMPATIBLE;
            } else if (issue.result() == CompatibilityResult.REQUIRES_USER_DECISION) {
                userDecision = true;
                if (overall != CompatibilityResult.INCOMPATIBLE) {
                    overall = CompatibilityResult.REQUIRES_USER_DECISION;
                }
            } else if (issue.result() == CompatibilityResult.PARTIALLY_COMPATIBLE) {
                if (overall == CompatibilityResult.COMPATIBLE) {
                    overall = CompatibilityResult.PARTIALLY_COMPATIBLE;
                }
            }
        }

        return new CompatibilityReport(overall, issues, userDecision);
    }

    private static void checkStorageCompatibility(
            String relativePath,
            long sizeBytes,
            TargetOperatingSystem targetOs,
            List<CompatibilityIssue> issues
    ) {
        if (relativePath == null || relativePath.isBlank()) {
            issues.add(new CompatibilityIssue(
                    CompatibilityCategory.STORAGE,
                    CompatibilityResult.INCOMPATIBLE,
                    "EMPTY_RELATIVE_PATH",
                    "Relative path cannot be null or empty.",
                    "Path must be specified."
            ));
            return;
        }

        if (relativePath.contains("..")) {
            issues.add(new CompatibilityIssue(
                    CompatibilityCategory.STORAGE,
                    CompatibilityResult.INCOMPATIBLE,
                    "PATH_TRAVERSAL",
                    "Relative path contains prohibited parent directory traversal sequence.",
                    "Path traversal prohibited."
            ));
        }

        String filename = PathUtils.getFilename(relativePath);

        if (filename.contains("\0")) {
            issues.add(new CompatibilityIssue(
                    CompatibilityCategory.STORAGE,
                    CompatibilityResult.INCOMPATIBLE,
                    "NULL_BYTE_IN_FILENAME",
                    "Filename contains null byte injection sequence.",
                    "Illegal character sequence."
            ));
        }

        if (targetOs == TargetOperatingSystem.WINDOWS) {
            // Reserved names check (CON, PRN, AUX, etc.)
            String base = PathUtils.getBaseName(filename).toUpperCase(Locale.ROOT);
            if (WINDOWS_RESERVED_NAMES.contains(base)) {
                issues.add(new CompatibilityIssue(
                        CompatibilityCategory.STORAGE,
                        CompatibilityResult.REQUIRES_USER_DECISION,
                        "WINDOWS_RESERVED_NAME",
                        "Filename '" + filename + "' is a reserved MS-DOS/Windows device name.",
                        "User must choose a rename destination path. PeerLink will never silently rename."
                ));
            }

            // Illegal characters
            if (WINDOWS_ILLEGAL_CHARS.matcher(filename).find()) {
                issues.add(new CompatibilityIssue(
                        CompatibilityCategory.STORAGE,
                        CompatibilityResult.INCOMPATIBLE,
                        "WINDOWS_ILLEGAL_CHARACTERS",
                        "Filename contains characters not permitted on Windows filesystems (< > : \" | ? *).",
                        "File cannot be stored with these characters. Requires explicit user rename decision."
                ));
            }

            // Trailing periods or spaces
            if (filename.endsWith(".") || filename.endsWith(" ")) {
                issues.add(new CompatibilityIssue(
                        CompatibilityCategory.STORAGE,
                        CompatibilityResult.REQUIRES_USER_DECISION,
                        "TRAILING_DOT_OR_SPACE",
                        "Filename ends with a period or space, which is disallowed in Windows Win32 subsystems.",
                        "Requires explicit user path selection."
                ));
            }

            // Windows MAX_PATH check
            if (relativePath.length() > 260) {
                issues.add(new CompatibilityIssue(
                        CompatibilityCategory.STORAGE,
                        CompatibilityResult.PARTIALLY_COMPATIBLE,
                        "PATH_EXCEEDS_MAX_PATH",
                        "Relative path length (" + relativePath.length() + " chars) exceeds standard Win32 260-char limit.",
                        "Requires extended path prefix or user relocation."
                ));
            }
        }

        // FAT32 / 4GB file size limit
        if (sizeBytes > 4294967295L) {
            issues.add(new CompatibilityIssue(
                    CompatibilityCategory.STORAGE,
                    CompatibilityResult.PARTIALLY_COMPATIBLE,
                    "EXCEEDS_FAT32_LIMIT",
                    "File size (" + sizeBytes + " bytes) exceeds 4GB single file limit on FAT32 volumes.",
                    "Verify target volume filesystem is NTFS/ext4/APFS."
            ));
        }
    }

    private static void checkMetadataCompatibility(
            Map<String, String> metadataAttributes,
            TargetOperatingSystem targetOs,
            List<CompatibilityIssue> issues
    ) {
        if (metadataAttributes == null) return;

        // POSIX permissions on Windows
        if (targetOs == TargetOperatingSystem.WINDOWS && metadataAttributes.containsKey("posix_permissions")) {
            String perm = metadataAttributes.get("posix_permissions");
            issues.add(new CompatibilityIssue(
                    CompatibilityCategory.METADATA,
                    CompatibilityResult.PARTIALLY_COMPATIBLE,
                    "POSIX_PERMISSIONS_ON_WINDOWS",
                    "File includes POSIX permission mode '" + perm + "' which has no direct NTFS ACL equivalent.",
                    "Metadata preserved in PeerLink index; will not be silently stripped."
            ));
        }

        // Symlinks
        if (Boolean.parseBoolean(metadataAttributes.get("is_symlink"))) {
            issues.add(new CompatibilityIssue(
                    CompatibilityCategory.METADATA,
                    CompatibilityResult.REQUIRES_USER_DECISION,
                    "SYMLINK_REPRESENTATION",
                    "File is a symbolic link. Target system privileges may be required to recreate symlinks.",
                    "User must decide whether to recreate link or restore target file payload."
            ));
        }

        // Extended attributes / xattrs
        if (metadataAttributes.containsKey("extended_attributes") || metadataAttributes.containsKey("xattrs")) {
            issues.add(new CompatibilityIssue(
                    CompatibilityCategory.METADATA,
                    CompatibilityResult.PARTIALLY_COMPATIBLE,
                    "EXTENDED_ATTRIBUTES_LIMITATION",
                    "File contains POSIX/Darwin extended attributes that may not be supported natively on all volumes.",
                    "Metadata preserved in PeerLink index; will not be silently dropped."
            ));
        }

        // Sensitive EXIF GPS tags
        if (Boolean.parseBoolean(metadataAttributes.get("has_gps")) || metadataAttributes.containsKey("exif_gps")) {
            issues.add(new CompatibilityIssue(
                    CompatibilityCategory.METADATA,
                    CompatibilityResult.PARTIALLY_COMPATIBLE,
                    "SENSITIVE_GPS_METADATA",
                    "File contains embedded geolocation coordinates in EXIF tags.",
                    "Privacy warning reported; metadata preserved without silent stripping."
            ));
        }
    }

    private static void checkExecutionCompatibility(
            String relativePath,
            TargetOperatingSystem targetOs,
            List<CompatibilityIssue> issues
    ) {
        String lower = relativePath.toLowerCase(Locale.ROOT);
        if (lower.endsWith(".exe") || lower.endsWith(".bat") || lower.endsWith(".cmd") || lower.endsWith(".msi")) {
            if (targetOs != TargetOperatingSystem.WINDOWS) {
                issues.add(new CompatibilityIssue(
                        CompatibilityCategory.EXECUTION,
                        CompatibilityResult.INCOMPATIBLE,
                        "WINDOWS_EXECUTABLE_ON_NON_WINDOWS",
                        "Windows executable format is not natively runnable on " + targetOs,
                        "File can be stored as data, but will never be silently executed."
                ));
            } else {
                issues.add(new CompatibilityIssue(
                        CompatibilityCategory.EXECUTION,
                        CompatibilityResult.REQUIRES_USER_DECISION,
                        "EXECUTABLE_RECEIVED",
                        "Inbound executable received. Execution requires explicit user confirmation.",
                        "PeerLink will never silently execute received files."
                ));
            }
        } else if (lower.endsWith(".elf") || lower.endsWith(".so")) {
            if (targetOs != TargetOperatingSystem.LINUX && targetOs != TargetOperatingSystem.ANDROID) {
                issues.add(new CompatibilityIssue(
                        CompatibilityCategory.EXECUTION,
                        CompatibilityResult.INCOMPATIBLE,
                        "LINUX_ELF_ON_NON_LINUX",
                        "Linux ELF binary format is not natively runnable on " + targetOs,
                        "File can be stored as data, but will never be silently executed."
                ));
            }
        } else if (lower.endsWith(".dylib") || lower.endsWith(".app")) {
            if (targetOs != TargetOperatingSystem.MACOS) {
                issues.add(new CompatibilityIssue(
                        CompatibilityCategory.EXECUTION,
                        CompatibilityResult.INCOMPATIBLE,
                        "MACHO_ON_NON_MACOS",
                        "macOS Mach-O application bundle is not natively runnable on " + targetOs,
                        "File can be stored as data, but will never be silently executed."
                ));
            }
        }
    }

    private static void checkTransferCompatibility(long sizeBytes, List<CompatibilityIssue> issues) {
        if (sizeBytes == 0) {
            issues.add(new CompatibilityIssue(
                    CompatibilityCategory.TRANSFER,
                    CompatibilityResult.COMPATIBLE,
                    "ZERO_BYTE_FILE",
                    "Empty 0-byte file transfer",
                    "No payload chunks needed"
            ));
        } else if (sizeBytes < 0) {
            issues.add(new CompatibilityIssue(
                    CompatibilityCategory.TRANSFER,
                    CompatibilityResult.INCOMPATIBLE,
                    "INVALID_FILE_SIZE",
                    "Negative file size is invalid: " + sizeBytes,
                    "Transfer rejected."
            ));
        }
    }

    private static class PathUtils {
        static String getFilename(String path) {
            int idx = Math.max(path.lastIndexOf('/'), path.lastIndexOf('\\'));
            return idx == -1 ? path : path.substring(idx + 1);
        }

        static String getBaseName(String filename) {
            int dot = filename.indexOf('.');
            return dot == -1 ? filename : filename.substring(0, dot);
        }
    }
}
