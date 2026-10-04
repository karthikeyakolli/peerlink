package org.peerlink.core.safety;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

/**
 * Inspects EXIF, XMP, and document metadata for sensitive information (GPS, author, serials).
 * Invariant: Never silently strip metadata.
 */
public final class MetadataPrivacyInspector {

    public record MetadataPrivacyReport(
            boolean hasSensitiveMetadata,
            boolean hasGpsCoordinates,
            String gpsDetails,
            List<String> personalIdentifiers
    ) {}

    public static MetadataPrivacyReport inspect(Path file) throws IOException {
        byte[] bytes = Files.readAllBytes(file);
        String content = new String(bytes, StandardCharsets.ISO_8859_1);

        boolean hasGps = false;
        String gpsDetails = null;
        List<String> identifiers = new ArrayList<>();

        // Detect GPS EXIF markers or text patterns
        if (content.contains("GPSLatitude") || content.contains("GPSLongitude") || content.contains("GPSPosition") || content.contains("exif:GPSLatitude")) {
            hasGps = true;
            gpsDetails = "Embedded GPS Location detected in EXIF/XMP tags";
        }

        // Detect author / device identifiers
        if (content.contains("CameraSerialNumber") || content.contains("InternalSerialNumber")) {
            identifiers.add("Camera/Device Hardware Serial Number");
        }
        if (content.contains("dc:creator") || content.contains("AuthorName")) {
            identifiers.add("Author/Creator Name Identifier");
        }

        boolean hasSensitive = hasGps || !identifiers.isEmpty();
        return new MetadataPrivacyReport(hasSensitive, hasGps, gpsDetails, identifiers);
    }
}