package org.peerlink.core.android;

import org.peerlink.core.identity.IdentityMetadataStore;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;

/**
 * File-backed IdentityMetadataStore storing device identity metadata in private application storage.
 * Enforces atomic writes to prevent corruption during unexpected shutdowns.
 */
public class FileIdentityMetadataStore implements IdentityMetadataStore {
    private static final Logger log = LoggerFactory.getLogger(FileIdentityMetadataStore.class);
    private static final String METADATA_FILENAME = "device_identity_meta.properties";

    private final Path metadataFile;

    public FileIdentityMetadataStore(File baseDir) {
        Objects.requireNonNull(baseDir, "baseDir must not be null");
        if (!baseDir.exists()) {
            baseDir.mkdirs();
        }
        this.metadataFile = baseDir.toPath().resolve(METADATA_FILENAME);
    }

    public FileIdentityMetadataStore(Path metadataFile) {
        this.metadataFile = Objects.requireNonNull(metadataFile, "metadataFile must not be null");
    }

    @Override
    public synchronized Optional<Map<String, String>> loadIdentityMetadata() {
        if (!Files.exists(metadataFile)) {
            return Optional.empty();
        }

        try (InputStream in = Files.newInputStream(metadataFile)) {
            Properties props = new Properties();
            props.load(new InputStreamReader(in, StandardCharsets.UTF_8));

            Map<String, String> result = new HashMap<>();
            for (String name : props.stringPropertyNames()) {
                result.put(name, props.getProperty(name));
            }
            return Optional.of(result);
        } catch (IOException e) {
            log.error("Failed to read identity metadata from {}", metadataFile, e);
            return Optional.empty();
        }
    }

    @Override
    public synchronized void saveIdentityMetadata(Map<String, String> metadata) {
        Objects.requireNonNull(metadata, "metadata must not be null");

        Properties props = new Properties();
        metadata.forEach(props::setProperty);

        Path tempFile = metadataFile.resolveSibling(metadataFile.getFileName() + ".tmp");
        try {
            if (metadataFile.getParent() != null) {
                Files.createDirectories(metadataFile.getParent());
            }

            try (OutputStream out = Files.newOutputStream(tempFile, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING)) {
                props.store(new OutputStreamWriter(out, StandardCharsets.UTF_8), "PeerLink Device Identity Metadata (Non-sensitive)");
            }

            try {
                Files.move(tempFile, metadataFile, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
            } catch (AtomicMoveNotSupportedException e) {
                Files.move(tempFile, metadataFile, StandardCopyOption.REPLACE_EXISTING);
            }
            log.info("Persisted device identity metadata to {}", metadataFile);
        } catch (IOException e) {
            throw new RuntimeException("Failed to persist identity metadata to " + metadataFile, e);
        }
    }

    @Override
    public synchronized boolean hasIdentityMetadata() {
        return Files.exists(metadataFile);
    }
}
