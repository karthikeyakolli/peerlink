package org.peerlink.core.net.ice;

import java.util.Objects;

/**
 * Configuration for connecting to a coturn TURN (Traversal Using Relays around NAT) server.
 */
public final class CoturnConfig {

    private final String host;
    private final int port;
    private final String username;
    private final String credential;
    private final String realm;
    private final TransportProtocol transport;

    public CoturnConfig(String host, int port, String username, String credential, String realm, TransportProtocol transport) {
        this.host = Objects.requireNonNull(host, "host must not be null");
        this.port = port > 0 ? port : 3478;
        this.username = username != null ? username : "";
        this.credential = credential != null ? credential : "";
        this.realm = realm != null ? realm : "peerlink.org";
        this.transport = transport != null ? transport : TransportProtocol.UDP;
    }

    public String getHost() { return host; }
    public int getPort() { return port; }
    public String getUsername() { return username; }
    public String getCredential() { return credential; }
    public String getRealm() { return realm; }
    public TransportProtocol getTransport() { return transport; }

    public static CoturnConfig create(String host, int port, String username, String credential) {
        return new CoturnConfig(host, port, username, credential, "peerlink.org", TransportProtocol.UDP);
    }

    public static CoturnConfig create(String host, int port, String username, String credential, TransportProtocol transport) {
        return new CoturnConfig(host, port, username, credential, "peerlink.org", transport);
    }
}
