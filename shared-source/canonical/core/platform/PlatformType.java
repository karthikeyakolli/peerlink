package org.peerlink.core.platform;

/**
 * Enumeration of supported operating system platforms.
 */
public enum PlatformType {
    WINDOWS,
    MACOS,
    LINUX,
    ANDROID,
    UNKNOWN;

    /**
     * Determines current runtime platform.
     */
    public static PlatformType detectCurrent() {
        String osName = System.getProperty("os.name", "").toLowerCase();
        String javaVendor = System.getProperty("java.vendor", "").toLowerCase();
        String javaVmName = System.getProperty("java.vm.name", "").toLowerCase();

        if (javaVendor.contains("android") || javaVmName.contains("dalvik") || javaVmName.contains("art")) {
            return ANDROID;
        }
        if (osName.contains("win")) {
            return WINDOWS;
        }
        if (osName.contains("mac") || osName.contains("darwin")) {
            return MACOS;
        }
        if (osName.contains("nix") || osName.contains("nux") || osName.contains("aix")) {
            return LINUX;
        }
        return UNKNOWN;
    }
}
