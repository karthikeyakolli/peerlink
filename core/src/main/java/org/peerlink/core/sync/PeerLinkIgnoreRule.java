package org.peerlink.core.sync;

import java.util.regex.Pattern;

/**
 * A single parsed rule for ignore file filtering.
 * Supports gitignore/stignore semantics:
 * - Leading '#' denotes comments
 * - Leading '!' denotes negation (re-inclusion)
 * - Trailing '/' denotes directory-only matching
 * - Leading '/' anchors match to root
 * - '*' matches any characters except '/'
 * - '**' matches any character including '/'
 * - '?' matches any single character except '/'
 */
public final class PeerLinkIgnoreRule {

    private final String rawLine;
    private final boolean isNegation;
    private final boolean directoryOnly;
    private final boolean rootAnchored;
    private final Pattern regexPattern;

    public PeerLinkIgnoreRule(String rawLine) {
        this.rawLine = rawLine.trim();

        String line = this.rawLine;
        if (line.startsWith("!")) {
            this.isNegation = true;
            line = line.substring(1).trim();
        } else {
            this.isNegation = false;
        }

        if (line.endsWith("/")) {
            this.directoryOnly = true;
            line = line.substring(0, line.length() - 1);
        } else {
            this.directoryOnly = false;
        }

        if (line.startsWith("/")) {
            this.rootAnchored = true;
            line = line.substring(1);
        } else {
            // If pattern contains an internal slash, it is also path-anchored
            this.rootAnchored = line.contains("/");
        }

        this.regexPattern = compileGlobToRegex(line, rootAnchored);
    }

    public boolean isNegation() {
        return isNegation;
    }

    public boolean isDirectoryOnly() {
        return directoryOnly;
    }

    /**
     * Test whether this rule matches the candidate relative path.
     */
    public boolean matches(String relativePath, boolean isDirectory) {
        String normalized = relativePath.replace('\\', '/');
        if (normalized.startsWith("/")) {
            normalized = normalized.substring(1);
        }

        // Direct regex match
        if (regexPattern.matcher(normalized).matches()) {
            return true;
        }

        // If directory-only or matching directory ancestor:
        // E.g., rule "target/" matches "target" (isDir=true),
        // and also matches "target/foo/bar.txt" (isDir=false)
        if (directoryOnly || isDirectory) {
            // Check prefix
            int slashIndex = normalized.indexOf('/');
            while (slashIndex != -1) {
                String parentDir = normalized.substring(0, slashIndex);
                if (regexPattern.matcher(parentDir).matches()) {
                    return true;
                }
                slashIndex = normalized.indexOf('/', slashIndex + 1);
            }
        }

        return false;
    }

    private static Pattern compileGlobToRegex(String glob, boolean rootAnchored) {
        StringBuilder sb = new StringBuilder();
        if (rootAnchored) {
            sb.append("^");
        } else {
            sb.append("(?:^|.*/)");
        }

        int i = 0;
        int len = glob.length();
        while (i < len) {
            char c = glob.charAt(i);
            if (c == '*') {
                if (i + 1 < len && glob.charAt(i + 1) == '*') {
                    sb.append(".*");
                    i += 2;
                    if (i < len && glob.charAt(i) == '/') {
                        i++; // skip slash after **
                    }
                    continue;
                } else {
                    sb.append("[^/]*");
                    i++;
                    continue;
                }
            } else if (c == '?') {
                sb.append("[^/]");
            } else if (c == '.') {
                sb.append("\\.");
            } else if ("+()^$.{}|\\".indexOf(c) != -1) {
                sb.append('\\').append(c);
            } else {
                sb.append(c);
            }
            i++;
        }

        sb.append("$");
        return Pattern.compile(sb.toString());
    }

    @Override
    public String toString() {
        return rawLine;
    }
}
