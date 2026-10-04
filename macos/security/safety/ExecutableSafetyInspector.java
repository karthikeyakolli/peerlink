package org.peerlink.core.safety;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

/**
 * Inspects executable formats, headers, disguised extensions, and code sign markers.
 * Invariant: Never silently execute.
 */
public final class ExecutableSafetyInspector {

    private static final Set<String> EXECUTABLE_EXTENSIONS = Set.of(
            "exe", "dll", "bat", "cmd", "vbs", "ps1", "sh", "elf", "so", "dylib", "app", "jar", "msi", "scr", "com"
    );

    public record ExecutableSafetyReport(
            boolean isExecutable,
            boolean isDisguised,
            boolean isSigned,
            String detectedFormat,
            List<String> warnings
    ) {}

    public static ExecutableSafetyReport inspect(Path file, String relativePath) throws IOException {
        byte[] bytes = Files.readAllBytes(file);
        String ext = getExtension(relativePath);
        List<String> warnings = new ArrayList<>();

        boolean declaredExecutable = EXECUTABLE_EXTENSIONS.contains(ext);
        String detectedFormat = "DATA";

        // Check magic bytes
        if (bytes.length >= 2 && bytes[0] == 0x4D && bytes[1] == 0x5A) {
            detectedFormat = "WINDOWS_PE";
        } else if (bytes.length >= 4 && bytes[0] == 0x7F && bytes[1] == 0x45 && bytes[2] == 0x4C && bytes[3] == 0x46) {
            detectedFormat = "LINUX_ELF";
        } else if (bytes.length >= 4 && (
                (bytes[0] == (byte) 0xCA && bytes[1] == (byte) 0xFE && bytes[2] == (byte) 0xBA && bytes[3] == (byte) 0xBE) ||
                (bytes[0] == (byte) 0xCF && bytes[1] == (byte) 0xFA && bytes[2] == (byte) 0xED && bytes[3] == (byte) 0xFE))) {
            detectedFormat = "MACHO_OR_JAVA";
        } else if (bytes.length >= 2 && bytes[0] == '#' && bytes[1] == '!') {
            detectedFormat = "SHELL_SCRIPT";
        }

        boolean headerExecutable = !detectedFormat.equals("DATA");
        boolean isDisguised = headerExecutable && !declaredExecutable;

        if (isDisguised) {
            warnings.add("Disguised executable: declared as ." + ext + " but header is " + detectedFormat);
        }

        // Code sign check (simplified marker search for test/portable verification)
        boolean isSigned = false;
        if (headerExecutable) {
            String content = new String(bytes);
            if (content.contains("Microsoft Authenticode") || content.contains("CodeSign") || content.contains("PKCS7")) {
                isSigned = true;
            } else {
                warnings.add("Unsigned executable: missing verified code signature");
            }
        }

        boolean isExec = declaredExecutable || headerExecutable;
        return new ExecutableSafetyReport(isExec, isDisguised, isSigned, detectedFormat, warnings);
    }

    private static String getExtension(String path) {
        int idx = path.lastIndexOf('.');
        if (idx == -1 || idx == path.length() - 1) return "";
        return path.substring(idx + 1).toLowerCase();
    }
}