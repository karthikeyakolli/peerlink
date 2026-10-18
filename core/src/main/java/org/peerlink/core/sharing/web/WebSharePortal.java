package org.peerlink.core.sharing.web;

import org.peerlink.core.filesystem.PathSafetyValidator;
import org.peerlink.core.transfer.FileManifestBuilder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.*;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.SocketException;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.SecureRandom;
import java.util.HashMap;
import java.util.HexFormat;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Zero-Install Browser Web Share Micro-Portal.
 *
 * <p>Spins up a lightweight, ephemeral local HTTP server to allow non-PeerLink devices
 * (iPhones, guest laptops, Chromebooks) on the same Wi-Fi subnet to download shared files
 * and optionally upload return files via any web browser without installing an app.
 *
 * <p>Implemented using standard portable Java sockets to guarantee 100% Android SDK
 * compatibility and architectural isolation without forbidden com.sun dependencies.
 *
 * <p>Security Invariants:
 * <ul>
 *   <li>Unguessable 128-bit cryptographic access token required for every endpoint</li>
 *   <li>Only accesses the explicitly designated shared file path</li>
 *   <li>Uploaded files are strictly quarantined in a dedicated inbox directory</li>
 *   <li>Automatic expiration shutdown timer</li>
 * </ul>
 */
public final class WebSharePortal implements AutoCloseable {

    private static final Logger log = LoggerFactory.getLogger(WebSharePortal.class);

    private final Path sharedFile;
    private final Path quarantineInbox;
    private final String senderDeviceName;
    private final int configuredPort;
    private final int maxDownloads;
    private final int autoExpireMinutes;
    private final String accessToken;

    private ServerSocket serverSocket;
    private ExecutorService executor;
    private ScheduledExecutorService scheduler;
    private final AtomicInteger downloadCount = new AtomicInteger(0);
    private final AtomicBoolean running = new AtomicBoolean(false);
    private String fileSha256;
    private long fileSizeBytes;

    private WebSharePortal(Builder builder) {
        this.sharedFile = builder.sharedFile;
        this.quarantineInbox = builder.quarantineInbox;
        this.senderDeviceName = builder.senderDeviceName != null ? builder.senderDeviceName : "PeerLink Node";
        this.configuredPort = builder.port;
        this.maxDownloads = builder.maxDownloads;
        this.autoExpireMinutes = builder.autoExpireMinutes;

        byte[] tokenBytes = new byte[16];
        new SecureRandom().nextBytes(tokenBytes);
        this.accessToken = HexFormat.of().formatHex(tokenBytes);
    }

    public static Builder builder() {
        return new Builder();
    }

    public synchronized void start() throws IOException {
        if (running.get()) {
            return;
        }

        if (sharedFile != null && Files.exists(sharedFile)) {
            this.fileSizeBytes = Files.size(sharedFile);
            this.fileSha256 = FileManifestBuilder.calculateSha256Hex(sharedFile);
        } else {
            this.fileSizeBytes = 0;
            this.fileSha256 = "";
        }

        this.serverSocket = new ServerSocket(configuredPort, 50, InetAddress.getByName("0.0.0.0"));
        this.executor = Executors.newCachedThreadPool();
        this.running.set(true);

        Thread acceptThread = new Thread(this::acceptLoop, "WebSharePortal-Accept");
        acceptThread.setDaemon(true);
        acceptThread.start();

        log.info("WebSharePortal started on port {} with token {}", getPort(), accessToken);

        if (autoExpireMinutes > 0) {
            scheduler = Executors.newSingleThreadScheduledExecutor();
            scheduler.schedule(this::close, autoExpireMinutes, TimeUnit.MINUTES);
        }
    }

    private void acceptLoop() {
        while (running.get() && serverSocket != null && !serverSocket.isClosed()) {
            try {
                Socket socket = serverSocket.accept();
                if (executor != null && !executor.isShutdown()) {
                    executor.submit(() -> handleClient(socket));
                } else {
                    socket.close();
                }
            } catch (SocketException se) {
                // Server closed
                break;
            } catch (IOException e) {
                if (running.get()) {
                    log.warn("Error accepting connection on WebSharePortal", e);
                }
            }
        }
    }

    private void handleClient(Socket socket) {
        try (socket;
             InputStream in = new BufferedInputStream(socket.getInputStream());
             OutputStream out = new BufferedOutputStream(socket.getOutputStream())) {

            // Parse request line: e.g. "GET /?token=123 HTTP/1.1"
            String requestLine = readLine(in);
            if (requestLine == null || requestLine.isBlank()) {
                return;
            }

            String[] lineParts = requestLine.split(" ");
            if (lineParts.length < 2) {
                return;
            }
            String method = lineParts[0].toUpperCase();
            String fullUri = lineParts[1];

            // Parse headers
            Map<String, String> headers = new HashMap<>();
            String headerLine;
            while ((headerLine = readLine(in)) != null && !headerLine.isEmpty()) {
                int colonIdx = headerLine.indexOf(':');
                if (colonIdx > 0) {
                    String name = headerLine.substring(0, colonIdx).trim().toLowerCase();
                    String value = headerLine.substring(colonIdx + 1).trim();
                    headers.put(name, value);
                }
            }

            String path = fullUri;
            String query = null;
            int qIdx = fullUri.indexOf('?');
            if (qIdx >= 0) {
                path = fullUri.substring(0, qIdx);
                query = fullUri.substring(qIdx + 1);
            }

            if (!validateToken(query)) {
                sendResponse(out, 401, "Unauthorized", "text/plain; charset=UTF-8",
                        "Unauthorized: Invalid or missing access token".getBytes(StandardCharsets.UTF_8), null);
                return;
            }

            if ("/".equals(path) || path.isEmpty()) {
                handleRoot(out);
            } else if ("/download".equals(path)) {
                handleDownload(out);
            } else if ("/upload".equals(path)) {
                handleUpload(method, query, in, out, headers);
            } else {
                sendResponse(out, 404, "Not Found", "text/plain", "Not Found".getBytes(StandardCharsets.UTF_8), null);
            }

        } catch (IOException e) {
            log.debug("HTTP exchange closed or interrupted: {}", e.getMessage());
        }
    }

    private boolean validateToken(String query) {
        if (query == null || query.isBlank()) {
            return false;
        }
        for (String param : query.split("&")) {
            String[] kv = param.split("=", 2);
            if (kv.length == 2 && "token".equalsIgnoreCase(kv[0]) && accessToken.equals(kv[1])) {
                return true;
            }
        }
        return false;
    }

    private void handleRoot(OutputStream out) throws IOException {
        String fileName = sharedFile != null ? sharedFile.getFileName().toString() : "No file";
        String sizeStr = formatBytes(fileSizeBytes);

        String html = """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>PeerLink Web Beam</title>
                <style>
                    :root {
                        --bg: #07090E;
                        --card-bg: rgba(255, 255, 255, 0.04);
                        --border: rgba(255, 255, 255, 0.08);
                        --accent: #3B82F6;
                        --accent-glow: rgba(59, 130, 246, 0.25);
                        --text: #F8FAFC;
                        --subtext: #94A3B8;
                    }
                    * { box-sizing: border-box; margin: 0; padding: 0; }
                    body {
                        background-color: var(--bg);
                        color: var(--text);
                        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        min-height: 100vh;
                        padding: 24px;
                    }
                    .glass-card {
                        background: var(--card-bg);
                        backdrop-filter: blur(24px);
                        -webkit-backdrop-filter: blur(24px);
                        border: 1px solid var(--border);
                        border-radius: 24px;
                        box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
                        width: 100%;
                        max-width: 480px;
                        padding: 32px;
                        text-align: center;
                    }
                    .badge {
                        display: inline-block;
                        background: var(--accent-glow);
                        border: 1px solid rgba(59, 130, 246, 0.4);
                        color: #60A5FA;
                        padding: 4px 14px;
                        border-radius: 999px;
                        font-size: 12px;
                        font-weight: 600;
                        margin-bottom: 20px;
                        letter-spacing: 0.5px;
                    }
                    h1 { font-size: 24px; font-weight: 700; margin-bottom: 6px; }
                    .sender { color: var(--subtext); font-size: 14px; margin-bottom: 24px; }
                    .file-box {
                        background: rgba(0, 0, 0, 0.3);
                        border: 1px solid var(--border);
                        border-radius: 16px;
                        padding: 20px;
                        margin-bottom: 24px;
                    }
                    .filename { font-size: 18px; font-weight: 600; word-break: break-all; margin-bottom: 4px; }
                    .filesize { color: var(--subtext); font-size: 14px; }
                    .sha-tag {
                        margin-top: 12px;
                        font-family: monospace;
                        font-size: 11px;
                        color: #64748B;
                        background: rgba(0,0,0,0.4);
                        padding: 6px 10px;
                        border-radius: 8px;
                        word-break: break-all;
                    }
                    .btn-download {
                        display: block;
                        width: 100%;
                        background: linear-gradient(135deg, #2563EB, #1D4ED8);
                        color: #FFFFFF;
                        text-decoration: none;
                        padding: 16px;
                        border-radius: 14px;
                        font-size: 16px;
                        font-weight: 600;
                        box-shadow: 0 10px 25px rgba(37, 99, 235, 0.4);
                        transition: transform 0.15s, box-shadow 0.15s;
                    }
                    .btn-download:hover {
                        transform: translateY(-2px);
                        box-shadow: 0 12px 30px rgba(37, 99, 235, 0.6);
                    }
                </style>
            </head>
            <body>
                <div class="glass-card">
                    <div class="badge">SECURE P2P WEB BEAM</div>
                    <h1>PeerLink Web Beam</h1>
                    <p class="sender">Shared by <strong>{{sender}}</strong></p>
                    <div class="file-box">
                        <div class="filename">{{filename}}</div>
                        <div class="filesize">{{filesize}}</div>
                        <div class="sha-tag">SHA-256: {{sha256}}</div>
                    </div>
                    <a href="/download?token={{token}}" class="btn-download">Download File</a>
                </div>
            </body>
            </html>
            """
            .replace("{{sender}}", senderDeviceName)
            .replace("{{filename}}", fileName)
            .replace("{{filesize}}", sizeStr)
            .replace("{{sha256}}", fileSha256)
            .replace("{{token}}", accessToken);

        byte[] responseBytes = html.getBytes(StandardCharsets.UTF_8);
        sendResponse(out, 200, "OK", "text/html; charset=UTF-8", responseBytes, null);
    }

    private void handleDownload(OutputStream out) throws IOException {
        if (sharedFile == null || !Files.exists(sharedFile) || !Files.isRegularFile(sharedFile)) {
            sendResponse(out, 404, "Not Found", "text/plain", "Shared file not found".getBytes(StandardCharsets.UTF_8), null);
            return;
        }

        String filename = sharedFile.getFileName().toString();
        long length = Files.size(sharedFile);

        Map<String, String> extraHeaders = new HashMap<>();
        extraHeaders.put("Content-Disposition", "attachment; filename=\"" + filename + "\"");
        extraHeaders.put("X-Content-SHA256", fileSha256);

        sendResponseHeaders(out, 200, "OK", "application/octet-stream", length, extraHeaders);

        byte[] buffer = new byte[64 * 1024];
        try (InputStream fileIn = new BufferedInputStream(Files.newInputStream(sharedFile))) {
            int read;
            while ((read = fileIn.read(buffer)) != -1) {
                out.write(buffer, 0, read);
            }
        }
        out.flush();

        int count = downloadCount.incrementAndGet();
        log.info("Download completed for {}. Total downloads: {}", filename, count);

        if (maxDownloads > 0 && count >= maxDownloads) {
            log.info("Max download quota ({}) reached. Closing portal.", maxDownloads);
            close();
        }
    }

    private void handleUpload(String method, String query, InputStream in, OutputStream out, Map<String, String> headers) throws IOException {
        if (!"POST".equalsIgnoreCase(method)) {
            sendResponse(out, 405, "Method Not Allowed", "text/plain", "Method Not Allowed. Use POST.".getBytes(StandardCharsets.UTF_8), null);
            return;
        }

        if (quarantineInbox == null) {
            sendResponse(out, 403, "Forbidden", "text/plain", "Uploads are disabled on this portal.".getBytes(StandardCharsets.UTF_8), null);
            return;
        }

        String requestedFileName = "upload-" + System.currentTimeMillis() + ".bin";
        if (query != null) {
            for (String param : query.split("&")) {
                String[] kv = param.split("=", 2);
                if (kv.length == 2 && "filename".equalsIgnoreCase(kv[0])) {
                    requestedFileName = URLDecoder.decode(kv[1], StandardCharsets.UTF_8);
                    break;
                }
            }
        }

        String sanitizedName = PathSafetyValidator.validateRelativePath(requestedFileName);
        if (!Files.exists(quarantineInbox)) {
            Files.createDirectories(quarantineInbox);
        }

        Path stagedUpload = quarantineInbox.resolve(sanitizedName);

        long contentLength = -1;
        String lenHeader = headers.get("content-length");
        if (lenHeader != null) {
            try {
                contentLength = Long.parseLong(lenHeader);
            } catch (NumberFormatException ignored) {}
        }

        try (OutputStream fileOut = new BufferedOutputStream(Files.newOutputStream(stagedUpload))) {
            if (contentLength >= 0) {
                byte[] buf = new byte[64 * 1024];
                long remaining = contentLength;
                while (remaining > 0) {
                    int toRead = (int) Math.min(buf.length, remaining);
                    int read = in.read(buf, 0, toRead);
                    if (read == -1) break;
                    fileOut.write(buf, 0, read);
                    remaining -= read;
                }
            } else {
                in.transferTo(fileOut);
            }
        }

        String uploadedSha = FileManifestBuilder.calculateSha256Hex(stagedUpload);
        log.info("Received quarantined file upload: {} ({} bytes, SHA-256: {})",
                stagedUpload.getFileName(), Files.size(stagedUpload), uploadedSha);

        String reply = "{\"status\": \"ok\", \"message\": \"Upload successful\", \"sha256\": \"" + uploadedSha + "\"}";
        sendResponse(out, 200, "OK", "application/json", reply.getBytes(StandardCharsets.UTF_8), null);
    }

    private void sendResponse(OutputStream out, int status, String reason, String contentType, byte[] body, Map<String, String> extra) throws IOException {
        sendResponseHeaders(out, status, reason, contentType, body.length, extra);
        out.write(body);
        out.flush();
    }

    private void sendResponseHeaders(OutputStream out, int status, String reason, String contentType, long contentLength, Map<String, String> extra) throws IOException {
        StringBuilder sb = new StringBuilder();
        sb.append("HTTP/1.1 ").append(status).append(" ").append(reason).append("\r\n");
        sb.append("Content-Type: ").append(contentType).append("\r\n");
        sb.append("Content-Length: ").append(contentLength).append("\r\n");
        sb.append("Connection: close\r\n");
        if (extra != null) {
            for (Map.Entry<String, String> e : extra.entrySet()) {
                sb.append(e.getKey()).append(": ").append(e.getValue()).append("\r\n");
            }
        }
        sb.append("\r\n");
        out.write(sb.toString().getBytes(StandardCharsets.US_ASCII));
    }

    private static String readLine(InputStream in) throws IOException {
        ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        int b;
        while ((b = in.read()) != -1) {
            if (b == '\n') {
                break;
            }
            if (b != '\r') {
                buffer.write(b);
            }
        }
        if (b == -1 && buffer.size() == 0) {
            return null;
        }
        return buffer.toString(StandardCharsets.US_ASCII);
    }

    public int getPort() {
        if (serverSocket == null || serverSocket.isClosed()) {
            return -1;
        }
        return serverSocket.getLocalPort();
    }

    public String getAccessToken() {
        return accessToken;
    }

    public String getFileSha256() {
        return fileSha256;
    }

    public long getFileSizeBytes() {
        return fileSizeBytes;
    }

    public String getPortalUrl(String hostIp) {
        return "http://" + hostIp + ":" + getPort() + "/?token=" + accessToken;
    }

    @Override
    public synchronized void close() {
        running.set(false);
        if (serverSocket != null) {
            try {
                serverSocket.close();
            } catch (IOException ignored) {}
            serverSocket = null;
        }
        if (executor != null) {
            executor.shutdownNow();
            executor = null;
        }
        if (scheduler != null) {
            scheduler.shutdownNow();
            scheduler = null;
        }
    }

    private static String formatBytes(long bytes) {
        if (bytes < 1024) return bytes + " B";
        int exp = (int) (Math.log(bytes) / Math.log(1024));
        char unit = "KMGTPE".charAt(exp - 1);
        return String.format("%.1f %sB", bytes / Math.pow(1024, exp), unit);
    }

    public static final class Builder {
        private Path sharedFile;
        private Path quarantineInbox;
        private String senderDeviceName;
        private int port = 0;
        private int maxDownloads = 0;
        private int autoExpireMinutes = 15;

        public Builder sharedFile(Path sharedFile) {
            this.sharedFile = sharedFile;
            return this;
        }

        public Builder quarantineInbox(Path quarantineInbox) {
            this.quarantineInbox = quarantineInbox;
            return this;
        }

        public Builder senderDeviceName(String senderDeviceName) {
            this.senderDeviceName = senderDeviceName;
            return this;
        }

        public Builder port(int port) {
            this.port = port;
            return this;
        }

        public Builder maxDownloads(int maxDownloads) {
            this.maxDownloads = maxDownloads;
            return this;
        }

        public Builder autoExpireMinutes(int autoExpireMinutes) {
            this.autoExpireMinutes = autoExpireMinutes;
            return this;
        }

        public WebSharePortal build() {
            return new WebSharePortal(this);
        }
    }
}
