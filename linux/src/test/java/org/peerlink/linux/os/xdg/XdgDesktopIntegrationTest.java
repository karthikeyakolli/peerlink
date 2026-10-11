package org.peerlink.linux.os.xdg;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.*;

class XdgDesktopIntegrationTest {

    @TempDir
    Path tempDir;

    @Test
    void testGenerateDesktopEntryContent() {
        Path exePath = tempDir.resolve("peerlink-node");
        Path iconPath = tempDir.resolve("peerlink.png");

        String entry = XdgDesktopIntegration.generateDesktopEntry(exePath, iconPath);
        assertNotNull(entry);
        assertTrue(entry.contains("[Desktop Entry]"));
        assertTrue(entry.contains("Name=PeerLink"));
        assertTrue(entry.contains("Categories=Network;FileTransfer;"));
        assertTrue(entry.contains("Exec=\"" + exePath.toAbsolutePath().toString() + "\" %u"));
        assertTrue(entry.contains("Icon=" + iconPath.toAbsolutePath().toString()));
    }

    @Test
    void testXdgPathsResolution() {
        Path configHome = XdgDesktopIntegration.getXdgConfigHome();
        assertNotNull(configHome);

        Path dataHome = XdgDesktopIntegration.getXdgDataHome();
        assertNotNull(dataHome);

        Path cacheHome = XdgDesktopIntegration.getXdgCacheHome();
        assertNotNull(cacheHome);

        Path runtimeDir = XdgDesktopIntegration.getXdgRuntimeDir();
        assertNotNull(runtimeDir);
    }
}
