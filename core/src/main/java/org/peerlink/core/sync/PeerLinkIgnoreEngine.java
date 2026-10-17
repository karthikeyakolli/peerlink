package org.peerlink.core.sync;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Intelligent .peerlinkignore / .gitignore evaluation engine.
 *
 * <p>Enforces local-first exclusion rules before syncing or scanning,
 * preventing temporary files, lock files, build artifacts (node_modules, target, .git),
 * and system caches from degrading sync performance.
 */
public final class PeerLinkIgnoreEngine {

    private static final Logger log = LoggerFactory.getLogger(PeerLinkIgnoreEngine.class);

    private final List<PeerLinkIgnoreRule> rules;

    public PeerLinkIgnoreEngine(List<PeerLinkIgnoreRule> rules) {
        this.rules = List.copyOf(rules);
    }

    public static PeerLinkIgnoreEngine parse(String content) {
        if (content == null || content.isBlank()) {
            return new PeerLinkIgnoreEngine(List.of());
        }
        return parse(Arrays.asList(content.split("\\r?\\n")));
    }

    public static PeerLinkIgnoreEngine parse(List<String> lines) {
        List<PeerLinkIgnoreRule> parsed = new ArrayList<>();
        if (lines != null) {
            for (String line : lines) {
                String trimmed = line.trim();
                if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                    continue;
                }
                parsed.add(new PeerLinkIgnoreRule(trimmed));
            }
        }
        return new PeerLinkIgnoreEngine(parsed);
    }

    /**
     * Inspect a sync root directory. If .peerlinkignore or .gitignore exists,
     * load and wrap into a SelectiveSyncFilter. Otherwise, return acceptAll().
     */
    public static SelectiveSyncFilter loadFromRoot(Path rootDir) {
        if (rootDir == null || !Files.exists(rootDir) || !Files.isDirectory(rootDir)) {
            return SelectiveSyncFilter.acceptAll();
        }

        Path peerlinkIgnore = rootDir.resolve(".peerlinkignore");
        if (Files.exists(peerlinkIgnore) && Files.isRegularFile(peerlinkIgnore)) {
            try {
                PeerLinkIgnoreEngine engine = parse(Files.readAllLines(peerlinkIgnore));
                log.info("Loaded .peerlinkignore with {} rules from {}", engine.getRuleCount(), rootDir);
                return engine.toSelectiveSyncFilter();
            } catch (IOException e) {
                log.warn("Failed to read .peerlinkignore at {}: {}", peerlinkIgnore, e.getMessage());
            }
        }

        Path gitIgnore = rootDir.resolve(".gitignore");
        if (Files.exists(gitIgnore) && Files.isRegularFile(gitIgnore)) {
            try {
                PeerLinkIgnoreEngine engine = parse(Files.readAllLines(gitIgnore));
                log.info("Loaded .gitignore with {} rules from {}", engine.getRuleCount(), rootDir);
                return engine.toSelectiveSyncFilter();
            } catch (IOException e) {
                log.warn("Failed to read .gitignore at {}: {}", gitIgnore, e.getMessage());
            }
        }

        return SelectiveSyncFilter.acceptAll();
    }

    /**
     * Built-in preset for software development directories.
     */
    public static PeerLinkIgnoreEngine developerDefaults() {
        return parse(List.of(
                "node_modules/",
                "target/",
                "build/",
                "dist/",
                ".git/",
                ".svn/",
                ".gradle/",
                ".venv/",
                "venv/",
                "__pycache__/",
                "*.pyc",
                ".idea/",
                ".vscode/",
                "*.class",
                "*.o",
                "*.obj",
                "*.tmp",
                "*.swp",
                ".DS_Store",
                "Thumbs.db",
                "desktop.ini"
        ));
    }

    /**
     * Built-in preset for audio/video media workspaces.
     */
    public static PeerLinkIgnoreEngine mediaProductionDefaults() {
        return parse(List.of(
                "*.tmp",
                "*.part",
                "*.crdownload",
                "*.autosave",
                "*.bak",
                ".DS_Store",
                "Thumbs.db",
                "desktop.ini",
                "Adobe Premiere Pro Auto-Save/",
                "Proxy/"
        ));
    }

    /**
     * Built-in preset for office and enterprise documents.
     */
    public static PeerLinkIgnoreEngine officeDefaults() {
        return parse(List.of(
                "~$*.docx",
                "~$*.xlsx",
                "~$*.pptx",
                "*.tmp",
                "*.lock",
                ".DS_Store",
                "Thumbs.db",
                "desktop.ini"
        ));
    }

    /**
     * Evaluates all rules sequentially.
     * Later negation rules (!pattern) override earlier exclusion rules.
     */
    public boolean isIgnored(String relativePath, boolean isDirectory) {
        boolean ignored = false;
        for (PeerLinkIgnoreRule rule : rules) {
            if (rule.matches(relativePath, isDirectory)) {
                ignored = !rule.isNegation();
            }
        }
        return ignored;
    }

    public int getRuleCount() {
        return rules.size();
    }

    public SelectiveSyncFilter toSelectiveSyncFilter() {
        return new SelectiveSyncFilter(this);
    }
}
