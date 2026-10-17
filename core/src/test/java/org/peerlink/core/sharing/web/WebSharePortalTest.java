package org.peerlink.core.sharing.web;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.transfer.FileManifestBuilder;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Zero-Install Web Share Micro-Portal Tests")
class WebSharePortalTest {

    @TempDir
    Path tempDir;

    @Test
    @DisplayName("Portal serves glassmorphic web UI when valid token is provided")
    void servesWebUiWithValidToken() throws Exception {
        Path testFile = tempDir.resolve("project_presentation.pdf");
        Files.writeString(testFile, "Sample presentation content for PeerLink test");

        try (WebSharePortal portal = WebSharePortal.builder()
                .sharedFile(testFile)
                .senderDeviceName("MacBook Pro 16")
                .port(0) // ephemeral port
                .build()) {

            portal.start();
            int port = portal.getPort();
            String token = portal.getAccessToken();

            HttpClient client = HttpClient.newHttpClient();
            URI pageUri = URI.create("http://127.0.0.1:" + port + "/?token=" + token);

            HttpRequest request = HttpRequest.newBuilder().uri(pageUri).GET().build();
            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());

            assertEquals(200, response.statusCode());
            assertTrue(response.body().contains("PeerLink Web Beam"));
            assertTrue(response.body().contains("project_presentation.pdf"));
            assertTrue(response.body().contains("MacBook Pro 16"));
            assertTrue(response.body().contains(portal.getFileSha256()));
        }
    }

    @Test
    @DisplayName("Portal rejects requests without token or with invalid token (401 Unauthorized)")
    void rejectsInvalidTokens() throws Exception {
        Path testFile = tempDir.resolve("secret.txt");
        Files.writeString(testFile, "Confidential document");

        try (WebSharePortal portal = WebSharePortal.builder()
                .sharedFile(testFile)
                .senderDeviceName("Workstation")
                .port(0)
                .build()) {

            portal.start();
            int port = portal.getPort();

            HttpClient client = HttpClient.newHttpClient();

            // Request with no token
            HttpResponse<String> noTokenResp = client.send(
                    HttpRequest.newBuilder().uri(URI.create("http://127.0.0.1:" + port + "/")).GET().build(),
                    HttpResponse.BodyHandlers.ofString());
            assertEquals(401, noTokenResp.statusCode());

            // Request with bad token
            HttpResponse<String> badTokenResp = client.send(
                    HttpRequest.newBuilder().uri(URI.create("http://127.0.0.1:" + port + "/?token=wrong_token")).GET().build(),
                    HttpResponse.BodyHandlers.ofString());
            assertEquals(401, badTokenResp.statusCode());

            // Download with bad token
            HttpResponse<String> badDownloadResp = client.send(
                    HttpRequest.newBuilder().uri(URI.create("http://127.0.0.1:" + port + "/download?token=wrong_token")).GET().build(),
                    HttpResponse.BodyHandlers.ofString());
            assertEquals(401, badDownloadResp.statusCode());
        }
    }

    @Test
    @DisplayName("Browser downloads file with exact content and SHA-256 match")
    void downloadsFileWithExactContent() throws Exception {
        Path testFile = tempDir.resolve("large_archive.zip");
        byte[] payload = new byte[256 * 1024]; // 256 KB
        for (int i = 0; i < payload.length; i++) {
            payload[i] = (byte) (i % 251);
        }
        Files.write(testFile, payload);
        String expectedSha256 = FileManifestBuilder.calculateSha256Hex(testFile);

        try (WebSharePortal portal = WebSharePortal.builder()
                .sharedFile(testFile)
                .senderDeviceName("Pixel 8")
                .port(0)
                .build()) {

            portal.start();
            int port = portal.getPort();
            String token = portal.getAccessToken();

            HttpClient client = HttpClient.newHttpClient();
            URI downloadUri = URI.create("http://127.0.0.1:" + port + "/download?token=" + token);

            HttpResponse<byte[]> response = client.send(
                    HttpRequest.newBuilder().uri(downloadUri).GET().build(),
                    HttpResponse.BodyHandlers.ofByteArray());

            assertEquals(200, response.statusCode());
            assertArrayEquals(payload, response.body());
            assertEquals("attachment; filename=\"large_archive.zip\"", response.headers().firstValue("Content-Disposition").orElse(""));
            assertEquals(expectedSha256, FileManifestBuilder.calculateSha256Hex(response.body()));
        }
    }

    @Test
    @DisplayName("Browser can upload file return to quarantined inbox")
    void uploadsFileToQuarantineInbox() throws Exception {
        Path testFile = tempDir.resolve("shared_brief.txt");
        Files.writeString(testFile, "Review this brief and reply with your signed contract.");
        Path quarantineInbox = tempDir.resolve("web-inbox");

        try (WebSharePortal portal = WebSharePortal.builder()
                .sharedFile(testFile)
                .quarantineInbox(quarantineInbox)
                .senderDeviceName("Office PC")
                .port(0)
                .build()) {

            portal.start();
            int port = portal.getPort();
            String token = portal.getAccessToken();

            HttpClient client = HttpClient.newHttpClient();
            URI uploadUri = URI.create("http://127.0.0.1:" + port + "/upload?token=" + token + "&filename=signed_contract.pdf");

            byte[] uploadData = "Signed contract payload 12345".getBytes();
            HttpResponse<String> response = client.send(
                    HttpRequest.newBuilder()
                            .uri(uploadUri)
                            .POST(HttpRequest.BodyPublishers.ofByteArray(uploadData))
                            .build(),
                    HttpResponse.BodyHandlers.ofString());

            assertEquals(200, response.statusCode());
            assertTrue(response.body().contains("Upload successful"));

            Path receivedFile = quarantineInbox.resolve("signed_contract.pdf");
            assertTrue(Files.exists(receivedFile), "Received file must exist in quarantine inbox");
            assertArrayEquals(uploadData, Files.readAllBytes(receivedFile));
        }
    }
}
