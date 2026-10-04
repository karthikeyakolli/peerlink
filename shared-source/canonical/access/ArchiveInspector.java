package org.peerlink.core.access;

import org.peerlink.protocol.v1.ArchiveEntryDescriptor;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Safe archive inspector that reads archive entry metadata in-memory without
 * extracting files to disk.
 *
 * <p>Protects against:
 * <ul>
 *   <li>Zip Slip vulnerabilities (path traversal inside archive entry names)</li>
 *   <li>Zip bombs (excessive uncompressed size or extreme compression ratios)</li>
 *   <li>Denial of service via unbounded entry iteration</li>
 * </ul>
 */
public final class ArchiveInspector {

    public static final int MAX_ENTRIES_TO_INSPECT = 1000;
    public static final long MAX_UNCOMPRESSED_TOTAL_BYTES = 500L * 1024 * 1024; // 500 MB limit
    public static final double MAX_ALLOWED_RATIO = 100.0; // 100:1 ratio alert

    /**
     * Inspects a ZIP archive file safely.
     *
     * @param zipPath path to the zip file
     * @return list of ArchiveEntryDescriptors
     * @throws IOException on I/O failure
     */
    public List<ArchiveEntryDescriptor> inspectZip(Path zipPath) throws IOException {
        List<ArchiveEntryDescriptor> results = new ArrayList<>();
        long totalUncompressed = 0;

        try (InputStream fis = Files.newInputStream(zipPath);
             ZipInputStream zis = new ZipInputStream(fis)) {

            ZipEntry entry;
            int count = 0;
            while ((entry = zis.getNextEntry()) != null && count < MAX_ENTRIES_TO_INSPECT) {
                count++;
                String name = entry.getName();
                long uncompressedSize = entry.getSize();
                long compressedSize = entry.getCompressedSize();
                boolean isDir = entry.isDirectory();
                long modifiedUtc = entry.getTime() > 0 ? entry.getTime() : System.currentTimeMillis();

                boolean isSafe = true;
                StringBuilder warning = new StringBuilder();

                // 1. Check for Zip Slip / Path Traversal
                if (name.contains("..") || name.startsWith("/") || name.startsWith("\\") || name.contains(":\0")) {
                    isSafe = false;
                    warning.append("Zip-Slip traversal detected; ");
                }

                // 2. Check for suspicious compression ratio / zip bomb
                if (uncompressedSize > 0) {
                    totalUncompressed += uncompressedSize;
                    if (compressedSize > 0) {
                        double ratio = (double) uncompressedSize / (double) compressedSize;
                        if (ratio > MAX_ALLOWED_RATIO) {
                            isSafe = false;
                            warning.append(String.format("Excessive compression ratio (%.1f:1); ", ratio));
                        }
                    }
                    if (totalUncompressed > MAX_UNCOMPRESSED_TOTAL_BYTES) {
                        isSafe = false;
                        warning.append("Archive exceeds safe uncompressed threshold; ");
                    }
                }

                ArchiveEntryDescriptor descriptor = ArchiveEntryDescriptor.newBuilder()
                        .setEntryPath(name)
                        .setUncompressedSizeBytes(uncompressedSize)
                        .setCompressedSizeBytes(compressedSize)
                        .setIsDirectory(isDir)
                        .setModifiedTimeUtcMs(modifiedUtc)
                        .setIsSafe(isSafe)
                        .setWarning(warning.toString().trim())
                        .build();

                results.add(descriptor);
                zis.closeEntry();
            }
        }

        return results;
    }
}
