package org.peerlink.core.chaos;

import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * File generator for PeerLink chaos, interoperability, and real-world stress testing.
 */
public final class ChaosFileGenerator {

    private final Random random;

    public ChaosFileGenerator() {
        this(123456789L); // deterministic default seed
    }

    public ChaosFileGenerator(long seed) {
        this.random = new Random(seed);
    }

    public Path createEmptyFile(Path dir, String fileName) throws IOException {
        Path file = dir.resolve(fileName);
        Files.createDirectories(file.getParent());
        Files.deleteIfExists(file);
        return Files.createFile(file);
    }

    public Path createTinyFile(Path dir, String fileName, int sizeBytes) throws IOException {
        Path file = dir.resolve(fileName);
        Files.createDirectories(file.getParent());
        byte[] bytes = new byte[sizeBytes];
        random.nextBytes(bytes);
        Files.write(file, bytes, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING);
        return file;
    }

    public Path createLargeFile(Path dir, String fileName, long sizeBytes) throws IOException {
        Path file = dir.resolve(fileName);
        Files.createDirectories(file.getParent());
        byte[] buffer = new byte[64 * 1024]; // 64 KB chunks
        long remaining = sizeBytes;
        try (RandomAccessFile raf = new RandomAccessFile(file.toFile(), "rw")) {
            raf.setLength(0);
            while (remaining > 0) {
                int toWrite = (int) Math.min(buffer.length, remaining);
                random.nextBytes(buffer);
                raf.write(buffer, 0, toWrite);
                remaining -= toWrite;
            }
        }
        return file;
    }

    public List<Path> createManySmallFiles(Path dir, int count, int depth) throws IOException {
        List<Path> created = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            int subDirLevel = i % depth;
            Path parent = dir;
            for (int d = 0; d < subDirLevel; d++) {
                parent = parent.resolve("level_" + d);
            }
            Files.createDirectories(parent);
            Path file = parent.resolve("small_file_" + i + ".txt");
            byte[] content = ("Small file content index: " + i + " random=" + random.nextInt()).getBytes(StandardCharsets.UTF_8);
            Files.write(file, content, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING);
            created.add(file);
        }
        return created;
    }

    public List<Path> createUnicodeFiles(Path dir) throws IOException {
        List<Path> created = new ArrayList<>();
        String[] unicodeNames = {
                "📄_تقرير_2026_файл.txt",
                "🎉_photo_ünïcøde_日本語.dat",
                "слово_кириллица.bin",
                "한글_테스트_문서.log",
                "café_mélange_étudiant.txt"
        };
        for (String name : unicodeNames) {
            Path file = dir.resolve(name);
            Files.createDirectories(file.getParent());
            byte[] content = ("Unicode file: " + name + " timestamp=" + System.currentTimeMillis()).getBytes(StandardCharsets.UTF_8);
            Files.write(file, content, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING);
            created.add(file);
        }
        return created;
    }

    public Path createLongPathFile(Path dir) throws IOException {
        Path deep = dir;
        // Create nested subdirectories to test long path handling
        for (int i = 0; i < 6; i++) {
            deep = deep.resolve("nested_directory_segment_level_" + i);
        }
        Files.createDirectories(deep);
        Path file = deep.resolve("deeply_nested_long_path_file_target_data_2026.bin");
        Files.writeString(file, "Deeply nested file payload content for long path verification.");
        return file;
    }

    public Path createSparseOrZeroFilledFile(Path dir, String fileName, long sizeBytes) throws IOException {
        Path file = dir.resolve(fileName);
        Files.createDirectories(file.getParent());
        try (RandomAccessFile raf = new RandomAccessFile(file.toFile(), "rw")) {
            raf.setLength(sizeBytes);
        }
        return file;
    }
}
