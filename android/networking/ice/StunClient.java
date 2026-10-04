package org.peerlink.core.net.ice;

import java.io.IOException;
import java.net.*;
import java.nio.ByteBuffer;
import java.security.SecureRandom;
import java.util.Arrays;

/**
 * Standard RFC 5389 STUN Client for NAT traversal and reflexive candidate discovery.
 */
public class StunClient {

    public static final int STUN_MAGIC_COOKIE = 0x2112A442;
    public static final short BINDING_REQUEST = 0x0001;
    public static final short BINDING_RESPONSE = 0x0101;
    public static final short ATTR_MAPPED_ADDRESS = 0x0001;
    public static final short ATTR_XOR_MAPPED_ADDRESS = 0x0020;

    private final SecureRandom random = new SecureRandom();

    /**
     * Discovers server-reflexive address by sending a STUN Binding Request over UDP.
     */
    public IceCandidate discoverReflexiveCandidate(DatagramSocket localSocket,
                                                   InetSocketAddress stunServer,
                                                   int timeoutMs) throws IOException {
        byte[] transactionId = new byte[12];
        random.nextBytes(transactionId);

        byte[] requestPacket = buildBindingRequest(transactionId);
        DatagramPacket sendPacket = new DatagramPacket(
                requestPacket,
                requestPacket.length,
                stunServer.getAddress(),
                stunServer.getPort()
        );

        localSocket.setSoTimeout(Math.max(500, timeoutMs));
        localSocket.send(sendPacket);

        byte[] recvBuf = new byte[1024];
        DatagramPacket recvPacket = new DatagramPacket(recvBuf, recvBuf.length);

        long deadline = System.currentTimeMillis() + timeoutMs;
        while (System.currentTimeMillis() < deadline) {
            try {
                localSocket.receive(recvPacket);
                InetSocketAddress reflexive = parseBindingResponse(recvPacket.getData(), recvPacket.getLength(), transactionId);
                if (reflexive != null) {
                    String baseIp = localSocket.getLocalAddress().getHostAddress();
                    int basePort = localSocket.getLocalPort();
                    return IceCandidate.srflx(
                            reflexive.getAddress().getHostAddress(),
                            reflexive.getPort(),
                            baseIp,
                            basePort,
                            TransportProtocol.UDP
                    );
                }
            } catch (SocketTimeoutException e) {
                break;
            }
        }

        throw new IOException("STUN binding request timed out for server " + stunServer);
    }

    public static byte[] buildBindingRequest(byte[] transactionId) {
        ByteBuffer buf = ByteBuffer.allocate(20);
        buf.putShort(BINDING_REQUEST);
        buf.putShort((short) 0); // message length: 0 attributes
        buf.putInt(STUN_MAGIC_COOKIE);
        buf.put(transactionId);
        return buf.array();
    }

    public static InetSocketAddress parseBindingResponse(byte[] data, int length, byte[] expectedTxId) {
        if (length < 20) return null;
        ByteBuffer buf = ByteBuffer.wrap(data, 0, length);
        short msgType = buf.getShort();
        if (msgType != BINDING_RESPONSE) return null;

        int msgLen = buf.getShort() & 0xFFFF;
        int cookie = buf.getInt();
        if (cookie != STUN_MAGIC_COOKIE) return null;

        byte[] txId = new byte[12];
        buf.get(txId);
        if (expectedTxId != null && !Arrays.equals(txId, expectedTxId)) {
            return null; // Not for this transaction
        }

        int remaining = Math.min(msgLen, length - 20);
        while (remaining >= 4) {
            int attrType = buf.getShort() & 0xFFFF;
            int attrLen = buf.getShort() & 0xFFFF;
            remaining -= 4;

            if (remaining < attrLen) break;

            if (attrType == ATTR_XOR_MAPPED_ADDRESS) {
                return parseXorMappedAddress(buf, attrLen, cookie, txId);
            } else if (attrType == ATTR_MAPPED_ADDRESS) {
                return parseMappedAddress(buf, attrLen);
            } else {
                buf.position(buf.position() + attrLen);
            }
            remaining -= attrLen;

            // Attribute padding to 4-byte boundary
            int padding = (4 - (attrLen % 4)) % 4;
            if (remaining >= padding) {
                buf.position(buf.position() + padding);
                remaining -= padding;
            }
        }
        return null;
    }

    private static InetSocketAddress parseXorMappedAddress(ByteBuffer buf, int len, int cookie, byte[] txId) {
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
                InetAddress addr = InetAddress.getByAddress(ipBytes);
                return new InetSocketAddress(addr, port);
            } catch (UnknownHostException e) {
                return null;
            }
        }
        return null;
    }

    private static InetSocketAddress parseMappedAddress(ByteBuffer buf, int len) {
        if (len < 4) return null;
        buf.get(); // reserved
        byte family = buf.get();
        int port = buf.getShort() & 0xFFFF;

        if (family == 0x01) { // IPv4
            if (len < 8) return null;
            byte[] ipBytes = new byte[4];
            buf.get(ipBytes);
            try {
                InetAddress addr = InetAddress.getByAddress(ipBytes);
                return new InetSocketAddress(addr, port);
            } catch (UnknownHostException e) {
                return null;
            }
        }
        return null;
    }
}
