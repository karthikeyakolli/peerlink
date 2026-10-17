package org.peerlink.core.sharing.web;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;
import org.peerlink.core.filesystem.PathSafetyValidator;
import org.peerlink.core.transfer.FileManifestBuilder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.*;
import java.net.InetSocketAddress;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.security.SecureRandom;
import java.util.HexFormat;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Zero-Install Browser Web Share Micro-Portal.
 *
 * <p>Spins up a lightweight, ephemeral local HTTP server to allow non-PeerLink devices
 * (iPhones, guest laptops, Chromebooks) on the same Wi-Fi subnet to download shared files
 * and optionally upload return files via any web browser without installing an app.
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

    private HttpServer server;
    private java.util.concurrent.ExecutorService executor;
    private ScheduledExecutorService scheduler;
    private final AtomicInteger downloadCount = new AtomicInteger(0);
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
        if (server != null) {
            return;
        }

        if (sharedFile != null && Files.exists(sharedFile)) {
            this.fileSizeBytes = Files.size(sharedFile);
            this.fileSha256 = FileManifestBuilder.calculateSha256Hex(sharedFile);
        } else {
            this.fileSizeBytes = 0;
            this.fileSha256 = "";
        }

        server = HttpServer.create(new InetSocketAddress("0.0.0.0", configuredPort), 0);
        this.executor = Executors.newCachedThreadPool();
        server.setExecutor(executor);

        server.createContext("/", new RootHandler());
        server.createContext("/download", new DownloadHandler());
        server.createContext("/upload", new UploadHandler());

        server.start();
        log.info("WebSharePortal started on port {} with token {}", getPort(), accessToken);

        if (autoExpireMinutes > 0) {
            scheduler = Executors.newSingleThreadScheduledExecutor();
            scheduler.schedule(this::close, autoExpireMinutes, TimeUnit.MINUTES);
        }
    }

    public int getPort() {
        if (server == null) {
            return -1;
        }
        return server.getAddress().getPort();
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
        if (server != null) {
            log.info("Stopping WebSharePortal on port {}", getPort());
            server.stop(0);
            server = null;
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

    private boolean validateToken(HttpExchange exchange) {
        String query = exchange.getRequestURI().getQuery();
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

    private class RootHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            if (!validateToken(exchange)) {
                sendError(exchange, 401, "Unauthorized: Invalid or missing access token");
                return;
            }

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
            exchange.getResponseHeaders().set("Content-Type", "text/html; charset=UTF-8");
            exchange.sendResponseHeaders(200, responseBytes.length);
            try (OutputStream os = exchange.getResponseBody()) {
                os.write(responseBytes);
            }
        }
    }

    private class DownloadHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            if (!validateToken(exchange)) {
                sendError(exchange, 401, "Unauthorized: Invalid access token");
                return;
            }

            if (sharedFile == null || !Files.exists(sharedFile) || !Files.isRegularFile(sharedFile)) {
                sendError(exchange, 404, "Shared file not found");
                return;
            }

            String filename = sharedFile.getFileName().toString();
            long length = Files.size(sharedFile);

            exchange.getResponseHeaders().set("Content-Type", "application/octet-stream");
            exchange.getResponseHeaders().set("Content-Disposition", "attachment; filename=\"" + filename + "\"");
            exchange.getResponseHeaders().set("X-Content-SHA256", fileSha256);
            exchange.sendResponseHeaders(200, length);

            byte[] buffer = new byte[64 * 1024];
            try (InputStream in = new BufferedInputStream(Files.newInputStream(sharedFile));
                 OutputStream out = exchange.getResponseBody()) {
                int read;
                while ((read = in.read(buffer)) != -1) {
                    out.write(buffer, 0, read);
                }
            }

            int count = downloadCount.incrementAndGet();
            log.info("Download completed for {}. Total downloads: {}", filename, count);

            if (maxDownloads > 0 && count >= maxDownloads) {
                log.info("Max download quota ({}) reached. Closing portal.", maxDownloads);
                close();
            }
        }
    }

    private class UploadHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            if (!validateToken(exchange)) {
                sendError(exchange, 401, "Unauthorized: Invalid access token");
                return;
            }

            if (!"POST".equalsIgnoreCase(exchange.getRequestMethod())) {
                sendError(exchange, 405, "Method Not Allowed. Use POST.");
                return;
            }

            if (quarantineInbox == null) {
                sendError(exchange, 403, "Uploads are disabled on this portal.");
                return;
            }

            // Extract filename from query parameter
            String query = exchange.getRequestURI().getQuery();
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

            // Path safety validation
            String sanitizedName = PathSafetyValidator.validateRelativePath(requestedFileName);
            if (!Files.exists(quarantineInbox)) {
                Files.createDirectories(quarantineInbox);
            }

            Path stagedUpload = quarantineInbox.resolve(sanitizedName);
            try (InputStream in = exchange.getRequestBody();
                 OutputStream out = Files.newOutputStream(stagedUpload)) {
                in.transferTo(out);
            }

            String uploadedSha = FileManifestBuilder.calculateSha256Hex(stagedUpload);
            log.info("Received quarantined file upload: {} ({} bytes, SHA-256: {})",
                    stagedUpload.getFileName(), Files.size(stagedUpload), uploadedSha);

            String reply = "{\"status\": \"ok\", \"message\": \"Upload successful\", \"sha256\": \"" + uploadedSha + "\"}";
            byte[] replyBytes = reply.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, replyBytes.length);
            try (OutputStream out = exchange.getResponseBody()) {
                out.write(replyBytes);
            }
        }
    }

    private void sendError(HttpExchange exchange, int statusCode, String message) throws IOException {
        byte[] bytes = message.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "text/plain; charset=UTF-8");
        exchange.sendResponseHeaders(statusCode, bytes.length);
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(bytes);
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
