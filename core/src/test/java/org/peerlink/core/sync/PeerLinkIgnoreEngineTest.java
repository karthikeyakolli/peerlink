package org.peerlink.core.sync;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("PeerLinkIgnore Rule Engine Tests")
class PeerLinkIgnoreEngineTest {

    @TempDir
    Path tempDir;

    @Test
    @DisplayName("Parses standard gitignore syntax with comments and wildcards")
    void parsesStandardSyntax() {
        String content = """
                # This is a comment
                *.tmp
                target/
                .git/
                node_modules/
                /root_only.log
                debug_*.log
                """;

        PeerLinkIgnoreEngine engine = PeerLinkIgnoreEngine.parse(content);

        // Wildcard extensions
        assertTrue(engine.isIgnored("notes.tmp", false));
        assertTrue(engine.isIgnored("deep/folder/cache.tmp", false));
        assertFalse(engine.isIgnored("notes.txt", false));

        // Directory rules
        assertTrue(engine.isIgnored("target", true));
        assertTrue(engine.isIgnored("target/classes/App.class", false));
        assertTrue(engine.isIgnored("project/target", true));
        assertTrue(engine.isIgnored("node_modules", true));
        assertTrue(engine.isIgnored("node_modules/package.json", false));

        // Root anchored rule
        assertTrue(engine.isIgnored("root_only.log", false));
        assertFalse(engine.isIgnored("subdir/root_only.log", false));

        // Wildcard prefix
        assertTrue(engine.isIgnored("debug_123.log", false));
        assertFalse(engine.isIgnored("production.log", false));
    }

    @Test
    @DisplayName("Negation rules (!pattern) correctly re-include files")
    void negationRuleReIncludes() {
        String content = """
                *.log
                !critical.log
                docs/*.md
                !docs/README.md
                """;

        PeerLinkIgnoreEngine engine = PeerLinkIgnoreEngine.parse(content);

        assertTrue(engine.isIgnored("server.log", false));
        assertTrue(engine.isIgnored("error.log", false));
        assertFalse(engine.isIgnored("critical.log", false), "critical.log must be re-included by negation");

        assertTrue(engine.isIgnored("docs/architecture.md", false));
        assertFalse(engine.isIgnored("docs/README.md", false), "docs/README.md must be re-included");
    }

    @Test
    @DisplayName("Built-in developer defaults preset filters build artifacts and node_modules")
    void developerDefaultsPreset() {
        PeerLinkIgnoreEngine engine = PeerLinkIgnoreEngine.developerDefaults();

        assertTrue(engine.isIgnored("node_modules", true));
        assertTrue(engine.isIgnored("node_modules/express/index.js", false));
        assertTrue(engine.isIgnored("target/classes", true));
        assertTrue(engine.isIgnored(".git", true));
        assertTrue(engine.isIgnored(".idea/workspace.xml", false));
        assertTrue(engine.isIgnored(".venv", true));
        assertTrue(engine.isIgnored("package/__pycache__", true));
        assertTrue(engine.isIgnored("app.class", false));
        assertTrue(engine.isIgnored(".DS_Store", false));
        assertTrue(engine.isIgnored("Thumbs.db", false));

        // Valid source files are NOT ignored
        assertFalse(engine.isIgnored("src/main/java/App.java", false));
        assertFalse(engine.isIgnored("package.json", false));
        assertFalse(engine.isIgnored("README.md", false));
    }

    @Test
    @DisplayName("FilesystemScanner automatically applies .peerlinkignore file in root directory")
    void scannerAutoAppliesPeerlinkIgnore() throws IOException {
        Path root = tempDir.resolve("workspace");
        Files.createDirectories(root);

        // Create .peerlinkignore
        Files.writeString(root.resolve(".peerlinkignore"), """
                *.tmp
                build/
                """);

        // Create sample files
        Files.writeString(root.resolve("valid_code.py"), "print('hello')");
        Files.writeString(root.resolve("scratch.tmp"), "transient");

        Path buildDir = root.resolve("build");
        Files.createDirectories(buildDir);
        Files.writeString(buildDir.resolve("binary.exe"), "compiled binary");

        Path srcDir = root.resolve("src");
        Files.createDirectories(srcDir);
        Files.writeString(srcDir.resolve("main.py"), "main entry");

        FilesystemScanner scanner = new FilesystemScanner(PeerLinkIgnoreEngine.loadFromRoot(root));
        List<ChangeDetector.FsEntry> entries = scanner.scan(root);

        var paths = entries.stream().map(ChangeDetector.FsEntry::relativePath).toList();

        assertTrue(paths.contains("valid_code.py"));
        assertTrue(paths.contains("src"));
        assertTrue(paths.contains("src/main.py"));

        // Ignored files and directories must NOT be in scan results
        assertFalse(paths.contains("scratch.tmp"));
        assertFalse(paths.contains("build"));
        assertFalse(paths.contains("build/binary.exe"));
    }
}
