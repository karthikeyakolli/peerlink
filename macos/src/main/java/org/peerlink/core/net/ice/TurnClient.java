package org.peerlink.core.net.ice;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.io.IOException;
import java.net.*;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Arrays;

/**
 * Standard RFC 5766 / RFC 6156 TURN Client for coturn server relay allocation and data exchange.
 *
 * CRITICAL SECURITY INVARIANT:
 * The TURN relay is treated as an untrusted dumb pipe.
 * All application payloads encapsulated in TURN indications/channel data
 * MUST be end-to-end encrypted ciphertexts. The relay never sees plaintext.
 */
public class TurnClient {

    public static final short ALLOCATE_REQUEST = 0x0003;
    public static final short ALLOCATE_RESPONSE = 0x0103;
    public static final short ALLOCATE_ERROR_RESPONSE = 0x0113;
    public static final short CREATE_PERMISSION_REQUEST = 0x0008;
    public static final short CREATE_PERMISSION_RESPONSE = 0x0108;
    public static final short CHANNEL_BIND_REQUEST = 0x0009;
    public static final short CHANNEL_BIND_RESPONSE = 0x0109;
    public static final short SEND_INDICATION = 0x0016;
    public static final short DATA_INDICATION = 0x0017;

    public static final short ATTR_USERNAME = 0x0006;
    public static final short ATTR_MESSAGE_INTEGRITY = 0x0008;
    public static final short ATTR_ERROR_CODE = 0x0009;
    public static final short ATTR_LIFETIME = 0x000D;
    public static final short ATTR_XOR_PEER_ADDRESS = 0x0012;
    public static final short ATTR_DATA = 0x0013;
    public static final short ATTR_REALM = 0x0014;
    public static final short ATTR_NONCE = 0x0015;
    public static final short ATTR_XOR_RELAYED_ADDRESS = 0x0016;
    public static final short ATTR_REQUESTED_TRANSPORT = 0x0019;

    private final SecureRandom random = new SecureRandom();

    /**
     * Allocates a relayed address on the coturn server via UDP or TCP.
     */
    public IceCandidate allocateRelayCandidate(DatagramSocket localSocket,
                                               CoturnConfig coturnConfig,
                                               int timeoutMs) throws IOException {
        InetSocketAddress serverAddr = new InetSocketAddress(coturnConfig.getHost(), coturnConfig.getPort());
        byte[] txId = new byte[12];
        random.nextBytes(txId);

        // Step 1: Initial unauthenticated Allocate Request (to receive Realm and Nonce)
        byte[] req1 = buildAllocateRequest(txId, null, null, null, null);
        DatagramPacket sendPkt1 = new DatagramPacket(req1, req1.length, serverAddr.getAddress(), serverAddr.getPort());
        localSocket.setSoTimeout(Math.max(500, timeoutMs));
        localSocket.send(sendPkt1);

        byte[] buf = new byte[2048];
        DatagramPacket recvPkt = new DatagramPacket(buf, buf.length);

        String realm = coturnConfig.getRealm();
        String nonce = null;

        long deadline = System.currentTimeMillis() + timeoutMs;
        while (System.currentTimeMillis() < deadline) {
            try {
                localSocket.receive(recvPkt);
                TurnResponse resp = parseTurnResponse(recvPkt.getData(), recvPkt.getLength());
                if (resp != null) {
                    if (resp.msgType == ALLOCATE_RESPONSE && resp.relayedAddress != null) {
                        // Direct success without auth challenge (rare)
                        String baseIp = localSocket.getLocalAddress().getHostAddress();
                        int basePort = localSocket.getLocalPort();
                        return IceCandidate.relay(
                                resp.relayedAddress.getAddress().getHostAddress(),
                                resp.relayedAddress.getPort(),
                                baseIp,
                                basePort,
                                coturnConfig.getTransport()
                        );
                    } else if (resp.msgType == ALLOCATE_ERROR_RESPONSE) {
                        // Expected 401 Unauthorized challenge with REALM and NONCE
                        if (resp.realm != null) realm = resp.realm;
                        nonce = resp.nonce;
                        break;
                    }
                }
            } catch (SocketTimeoutException e) {
                break;
            }
        }

        if (nonce == null) {
            // If no challenge response was returned, allocate mock/fallback relay candidate for offline or coturn testing
            throw new IOException("Failed to obtain TURN auth challenge from " + serverAddr);
        }

        // Step 2: Authenticated Allocate Request with HMAC-SHA1
        byte[] key = computeTurnKey(coturnConfig.getUsername(), realm, coturnConfig.getCredential());
        byte[] txId2 = new byte[12];
        random.nextBytes(txId2);
        byte[] req2 = buildAllocateRequest(txId2, coturnConfig.getUsername(), realm, nonce, key);
        DatagramPacket sendPkt2 = new DatagramPacket(req2, req2.length, serverAddr.getAddress(), serverAddr.getPort());
        localSocket.send(sendPkt2);

        while (System.currentTimeMillis() < deadline) {
            try {
                localSocket.receive(recvPkt);
                TurnResponse resp = parseTurnResponse(recvPkt.getData(), recvPkt.getLength());
                if (resp != null && resp.msgType == ALLOCATE_RESPONSE && resp.relayedAddress != null) {
                    String baseIp = localSocket.getLocalAddress().getHostAddress();
                    int basePort = localSocket.getLocalPort();
                    return IceCandidate.relay(
                            resp.relayedAddress.getAddress().getHostAddress(),
                            resp.relayedAddress.getPort(),
                            baseIp,
                            basePort,
                            coturnConfig.getTransport()
                    );
                }
            } catch (SocketTimeoutException e) {
                break;
            }
        }

        throw new IOException("TURN authenticated allocation timed out for " + serverAddr);
    }

    public static byte[] computeTurnKey(String username, String realm, String password) {
        try {
            MessageDigest md5 = MessageDigest.getInstance("MD5");
            String input = username + ":" + realm + ":" + password;
            return md5.digest(input.getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            throw new RuntimeException("MD5 not available", e);
        }
    }

    public static byte[] buildAllocateRequest(byte[] txId, String username, String realm, String nonce, byte[] key) {
        ByteBuffer body = ByteBuffer.allocate(512);

        // Requested transport: UDP (0x11000000)
        body.putShort(ATTR_REQUESTED_TRANSPORT);
        body.putShort((short) 4);
        body.put((byte) 17); // UDP
        body.put((byte) 0);
        body.put((byte) 0);
        body.put((byte) 0);

        if (username != null && realm != null && nonce != null) {
            // USERNAME
            byte[] userBytes = username.getBytes(StandardCharsets.UTF_8);
            body.putShort(ATTR_USERNAME);
            body.putShort((short) userBytes.length);
            body.put(userBytes);
            pad(body, userBytes.length);

            // REALM
            byte[] realmBytes = realm.getBytes(StandardCharsets.UTF_8);
            body.putShort(ATTR_REALM);
            body.putShort((short) realmBytes.length);
            body.put(realmBytes);
            pad(body, realmBytes.length);

            // NONCE
            byte[] nonceBytes = nonce.getBytes(StandardCharsets.UTF_8);
            body.putShort(ATTR_NONCE);
            body.putShort((short) nonceBytes.length);
            body.put(nonceBytes);
            pad(body, nonceBytes.length);
        }

        int bodyLen = body.position();
        int totalLen = 20 + bodyLen + (key != null ? 24 : 0);

        ByteBuffer header = ByteBuffer.allocate(20);
        header.putShort(ALLOCATE_REQUEST);
        header.putShort((short) (bodyLen + (key != null ? 24 : 0)));
        header.putInt(StunClient.STUN_MAGIC_COOKIE);
        header.put(txId);

        byte[] result = new byte[totalLen];
        System.arraycopy(header.array(), 0, result, 0, 20);
        System.arraycopy(body.array(), 0, result, 20, bodyLen);

        if (key != null) {
            // Compute HMAC-SHA1 over header + body up to MESSAGE-INTEGRITY attribute
            byte[] hmac = computeHmacSha1(result, 20 + bodyLen, key);
            ByteBuffer integrityBuf = ByteBuffer.wrap(result, 20 + bodyLen, 24);
            integrityBuf.putShort(ATTR_MESSAGE_INTEGRITY);
            integrityBuf.putShort((short) 20);
            integrityBuf.put(hmac);
        }

        return result;
    }

    private static void pad(ByteBuffer buf, int len) {
        int padding = (4 - (len % 4)) % 4;
        for (int i = 0; i < padding; i++) {
            buf.put((byte) 0);
        }
    }

    private static byte[] computeHmacSha1(byte[] data, int length, byte[] key) {
        try {
            Mac mac = Mac.getInstance("HmacSHA1");
            mac.init(new SecretKeySpec(key, "HmacSHA1"));
            mac.update(data, 0, length);
            return mac.doFinal();
        } catch (Exception e) {
            throw new RuntimeException("HMAC-SHA1 error", e);
        }
    }

    public static class TurnResponse {
        public short msgType;
        public InetSocketAddress relayedAddress;
        public String realm;
        public String nonce;
        public int errorCode;
    }

    public static TurnResponse parseTurnResponse(byte[] data, int length) {
        if (length < 20) return null;
        ByteBuffer buf = ByteBuffer.wrap(data, 0, length);
        short type = buf.getShort();
        int msgLen = buf.getShort() & 0xFFFF;
        int cookie = buf.getInt();
        if (cookie != StunClient.STUN_MAGIC_COOKIE) return null;

        byte[] txId = new byte[12];
        buf.get(txId);

        TurnResponse resp = new TurnResponse();
        resp.msgType = type;

        int remaining = Math.min(msgLen, length - 20);
        while (remaining >= 4) {
            int attrType = buf.getShort() & 0xFFFF;
            int attrLen = buf.getShort() & 0xFFFF;
            remaining -= 4;

            if (remaining < attrLen) break;

            if (attrType == ATTR_XOR_RELAYED_ADDRESS) {
                resp.relayedAddress = parseXorAddress(buf, attrLen, cookie);
            } else if (attrType == ATTR_REALM) {
                byte[] rb = new byte[attrLen];
                buf.get(rb);
                resp.realm = new String(rb, StandardCharsets.UTF_8);
            } else if (attrType == ATTR_NONCE) {
                byte[] nb = new byte[attrLen];
                buf.get(nb);
                resp.nonce = new String(nb, StandardCharsets.UTF_8);
            } else if (attrType == ATTR_ERROR_CODE) {
                if (attrLen >= 4) {
                    buf.getShort(); // reserved
                    byte errClass = buf.get();
                    byte errNumber = buf.get();
                    resp.errorCode = (errClass * 100) + (errNumber & 0xFF);
                    int reasonLen = attrLen - 4;
                    buf.position(buf.position() + reasonLen);
                } else {
                    buf.position(buf.position() + attrLen);
                }
            } else {
                buf.position(buf.position() + attrLen);
            }
            remaining -= attrLen;

            int padding = (4 - (attrLen % 4)) % 4;
            if (remaining >= padding) {
                buf.position(buf.position() + padding);
                remaining -= padding;
            }
        }

        return resp;
    }

    private static InetSocketAddress parseXorAddress(ByteBuffer buf, int len, int cookie) {
        if (len < 4) return null;
        buf.get(); // reserved
        byte family = buf.get();
        int xorPort = buf.getShort() & 0xFFFF;
        int port = xorPort ^ (cookie >>> 16);

        if (family == 0x01) { // IPv4
            if (len < 8) return null;
            int xorIp = buf.getInt();
            int ip = xorIp ^ cookie;
            try {
                byte[] ipBytes = new byte[]{
                        (byte) ((ip >>> 24) & 0xFF),
                        (byte) ((ip >>> 16) & 0xFF),
                        (byte) ((ip >>> 8) & 0xFF),
                        (byte) (ip & 0xFF)
                };
                return new InetSocketAddress(InetAddress.getByAddress(ipBytes), port);
            } catch (UnknownHostException e) {
                return null;
            }
        }
        return null;
    }
}
