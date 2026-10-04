package org.peerlink.core.safety;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Safe archive inspector enforcing decompression limits and zip bomb defense.
 * Invariant: Never extracts files unsafely to disk. Inspects metadata and ratio in stream.
 */
public final class ArchiveSafetyInspector {
    public static final int MAX_RECURSION_DEPTH = 3;
    public static final long MAX_UNCOMPRESSED_BYTES = 100 * 1024 * 1024L; // 100 MB
    public static final double MAX_COMPRESSION_RATIO = 100.0;
    public static final int MAX_TOTAL_ENTRIES = 5000;

    public record ArchiveSafetyVerdict(
            boolean isSafe,
            boolean isDecompressionBomb,
            boolean hasPathTraversal,
            int totalEntries,
            long totalUncompressedBytes,
            double maxRatioObserved,
            List<String> findings
    ) {}

    public static boolean isArchive(String relativePath) {
        String lower = relativePath.toLowerCase();
        return lower.endsWith(".zip") || lower.endsWith(".jar") || lower.endsWith(".war") || lower.endsWith(".tar");
    }

    public static ArchiveSafetyVerdict inspectZip(Path zipFile) throws IOException {
        byte[] bytes = Files.readAllBytes(zipFile);
        return inspectZipBytes(bytes, 1);
    }

    public static ArchiveSafetyVerdict inspectZipBytes(byte[] zipBytes, int depth) {
        List<String> findings = new ArrayList<>();
        int entryCount = 0;
        long totalUncompressed = 0;
        double maxRatio = 0.0;
        boolean isBomb = false;
        boolean hasTraversal = false;

        if (depth > MAX_RECURSION_DEPTH) {
            findings.add("Nested archive exceeds max recursion depth: " + depth);
            return new ArchiveSafetyVerdict(false, true, false, 0, 0, 0, findings);
        }

        try (ZipInputStream zis = new ZipInputStream(new ByteArrayInputStream(zipBytes))) {
            ZipEntry entry;
            byte[] buffer = new byte[8192];

            while ((entry = zis.getNextEntry()) != null) {
                entryCount++;
                String name = entry.getName();

                // Path traversal check
                if (name.contains("..") || name.startsWith("/") || name.startsWith("\\")) {
                    hasTraversal = true;
                    findings.add("Path traversal sequence in entry name: " + name);
                }

                if (entryCount > MAX_TOTAL_ENTRIES) {
                    findings.add("Archive contains excessive entries (> " + MAX_TOTAL_ENTRIES + ")");
                    isBomb = true;
                    break;
                }

                ByteArrayOutputStream nestedBaos = name.toLowerCase().endsWith(".zip") ? new ByteArrayOutputStream() : null;
                long entryBytes = 0;
                int read;
                while ((read = zis.read(buffer)) != -1) {
                    entryBytes += read;
                    totalUncompressed += read;
                    if (nestedBaos != null) {
                        nestedBaos.write(buffer, 0, read);
                    }
                    if (totalUncompressed > MAX_UNCOMPRESSED_BYTES) {
                        findings.add("Total uncompressed size exceeds limit of " + MAX_UNCOMPRESSED_BYTES + " bytes");
                        isBomb = true;
                        break;
                    }
                }

                long compressedSize = entry.getCompressedSize();
                if (compressedSize > 0) {
                    double ratio = (double) entryBytes / compressedSize;
                    if (ratio > maxRatio) maxRatio = ratio;
                    if (ratio > MAX_COMPRESSION_RATIO) {
                        findings.add("Compression ratio " + String.format(Locale.ROOT, "%.1f", ratio) + ":1 exceeds max allowed " + MAX_COMPRESSION_RATIO + ":1");
                        isBomb = true;
                        break;
                    }
                }

                // If nested zip, inspect recursively
                if (nestedBaos != null && !isBomb) {
                    byte[] nestedZipBytes = nestedBaos.toByteArray();
                    ArchiveSafetyVerdict nestedVerdict = inspectZipBytes(nestedZipBytes, depth + 1);
                    if (!nestedVerdict.isSafe()) {
                        findings.addAll(nestedVerdict.findings());
                        if (nestedVerdict.isDecompressionBomb()) isBomb = true;
                        if (nestedVerdict.hasPathTraversal()) hasTraversal = true;
                    }
                    totalUncompressed += nestedVerdict.totalUncompressedBytes();
                    if (nestedVerdict.maxRatioObserved() > maxRatio) {
                        maxRatio = nestedVerdict.maxRatioObserved();
                    }
                }

                if (isBomb) break;
            }
        } catch (Exception e) {
            findings.add("Corrupted or malformed archive format: " + e.getMessage());
            return new ArchiveSafetyVerdict(false, false, false, entryCount, totalUncompressed, maxRatio, findings);
        }

        boolean isSafe = !isBomb && !hasTraversal && findings.isEmpty();
        return new ArchiveSafetyVerdict(isSafe, isBomb, hasTraversal, entryCount, totalUncompressed, maxRatio, findings);
    }
}