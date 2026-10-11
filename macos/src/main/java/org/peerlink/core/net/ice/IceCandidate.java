package org.peerlink.core.net.ice;

import java.util.HashMap;
import java.util.Map;
import java.util.Objects;

/**
 * Immutable ICE Candidate conforming to RFC 8445 / RFC 5245.
 */
public final class IceCandidate {

    private final String foundation;
    private final int componentId; // 1 for RTP/Direct, 2 for RTCP
    private final TransportProtocol protocol;
    private final long priority;
    private final String ip;
    private final int port;
    private final CandidateType type;
    private final String relAddr;
    private final int relPort;
    private final String tcpType; // active, passive, so

    public IceCandidate(String foundation, int componentId, TransportProtocol protocol,
                        long priority, String ip, int port, CandidateType type,
                        String relAddr, int relPort, String tcpType) {
        this.foundation = Objects.requireNonNull(foundation, "foundation must not be null");
        this.componentId = componentId > 0 ? componentId : 1;
        this.protocol = Objects.requireNonNull(protocol, "protocol must not be null");
        this.priority = priority > 0 ? priority : computePriority(type, 65535, componentId);
        this.ip = Objects.requireNonNull(ip, "ip must not be null");
        this.port = port;
        this.type = Objects.requireNonNull(type, "type must not be null");
        this.relAddr = relAddr;
        this.relPort = relPort;
        this.tcpType = tcpType;
    }

    public static long computePriority(CandidateType type, int localPref, int componentId) {
        // RFC 8445 Section 5.1.2.1 formula:
        // priority = (2^24 * type_pref) + (2^8 * local_pref) + (256 - component_id)
        long typePref = type.getDefaultPreference();
        return (typePref << 24) | ((long) (localPref & 0xFFFF) << 8) | (256 - (componentId & 0xFF));
    }

    public static IceCandidate host(String ip, int port, TransportProtocol protocol) {
        String foundation = "h-" + Math.abs(ip.hashCode() ^ port);
        long prio = computePriority(CandidateType.HOST, 65535, 1);
        return new IceCandidate(foundation, 1, protocol, prio, ip, port, CandidateType.HOST, null, 0, null);
    }

    public static IceCandidate srflx(String publicIp, int publicPort, String baseIp, int basePort, TransportProtocol protocol) {
        String foundation = "s-" + Math.abs(publicIp.hashCode() ^ publicPort);
        long prio = computePriority(CandidateType.SRFLX, 65535, 1);
        return new IceCandidate(foundation, 1, protocol, prio, publicIp, publicPort, CandidateType.SRFLX, baseIp, basePort, null);
    }

    public static IceCandidate relay(String relayIp, int relayPort, String baseIp, int basePort, TransportProtocol protocol) {
        String foundation = "r-" + Math.abs(relayIp.hashCode() ^ relayPort);
        long prio = computePriority(CandidateType.RELAY, 0, 1);
        return new IceCandidate(foundation, 1, protocol, prio, relayIp, relayPort, CandidateType.RELAY, baseIp, basePort, null);
    }

    public String getFoundation() { return foundation; }
    public int getComponentId() { return componentId; }
    public TransportProtocol getProtocol() { return protocol; }
    public long getPriority() { return priority; }
    public String getIp() { return ip; }
    public int getPort() { return port; }
    public CandidateType getType() { return type; }
    public String getRelAddr() { return relAddr; }
    public int getRelPort() { return relPort; }
    public String getTcpType() { return tcpType; }

    public boolean isDirect() {
        return type == CandidateType.HOST || type == CandidateType.SRFLX || type == CandidateType.PRFLX;
    }

    public boolean isRelayed() {
        return type == CandidateType.RELAY;
    }

    public String toSdpLine() {
        StringBuilder sb = new StringBuilder();
        sb.append("candidate:").append(foundation).append(' ')
          .append(componentId).append(' ')
          .append(protocol.name()).append(' ')
          .append(priority).append(' ')
          .append(ip).append(' ')
          .append(port).append(' ')
          .append("typ ").append(type.name().toLowerCase());

        if (relAddr != null && !relAddr.isEmpty()) {
            sb.append(" raddr ").append(relAddr).append(" rport ").append(relPort);
        }
        if (tcpType != null && !tcpType.isEmpty()) {
            sb.append(" tcptype ").append(tcpType);
        }
        return sb.toString();
    }

    public static IceCandidate fromSdpLine(String sdp) {
        if (sdp == null || sdp.isBlank()) {
            throw new IllegalArgumentException("SDP line cannot be null or blank");
        }
        String line = sdp.trim();
        if (line.startsWith("candidate:")) {
            line = line.substring(10).trim();
        }
        String[] parts = line.split("\\s+");
        if (parts.length < 8) {
            throw new IllegalArgumentException("Malformed candidate SDP: " + sdp);
        }

        String foundation = parts[0];
        int compId = Integer.parseInt(parts[1]);
        TransportProtocol proto = TransportProtocol.valueOf(parts[2].toUpperCase());
        long prio = Long.parseLong(parts[3]);
        String ip = parts[4];
        int port = Integer.parseInt(parts[5]);
        // parts[6] should be "typ"
        CandidateType type = CandidateType.valueOf(parts[7].toUpperCase());

        String raddr = null;
        int rport = 0;
        String tcptype = null;

        for (int i = 8; i < parts.length - 1; i += 2) {
            if ("raddr".equalsIgnoreCase(parts[i])) {
                raddr = parts[i + 1];
            } else if ("rport".equalsIgnoreCase(parts[i])) {
                rport = Integer.parseInt(parts[i + 1]);
            } else if ("tcptype".equalsIgnoreCase(parts[i])) {
                tcptype = parts[i + 1];
            }
        }

        return new IceCandidate(foundation, compId, proto, prio, ip, port, type, raddr, rport, tcptype);
    }

    public Map<String, Object> toMap() {
        Map<String, Object> map = new HashMap<>();
        map.put("foundation", foundation);
        map.put("componentId", componentId);
        map.put("protocol", protocol.name());
        map.put("priority", priority);
        map.put("ip", ip);
        map.put("port", port);
        map.put("type", type.name());
        if (relAddr != null) map.put("relAddr", relAddr);
        if (relPort > 0) map.put("relPort", relPort);
        if (tcpType != null) map.put("tcpType", tcpType);
        return map;
    }

    public static IceCandidate fromMap(Map<String, Object> map) {
        String foundation = (String) map.get("foundation");
        Number compNum = (Number) map.get("componentId");
        int compId = compNum != null ? compNum.intValue() : 1;
        String protoStr = (String) map.get("protocol");
        TransportProtocol proto = TransportProtocol.valueOf(protoStr.toUpperCase());
        Number prioNum = (Number) map.get("priority");
        long prio = prioNum != null ? prioNum.longValue() : 0;
        String ip = (String) map.get("ip");
        Number portNum = (Number) map.get("port");
        int port = portNum != null ? portNum.intValue() : 0;
        String typeStr = (String) map.get("type");
        CandidateType type = CandidateType.valueOf(typeStr.toUpperCase());
        String raddr = (String) map.get("relAddr");
        Number rportNum = (Number) map.get("relPort");
        int rport = rportNum != null ? rportNum.intValue() : 0;
        String tcptype = (String) map.get("tcpType");

        return new IceCandidate(foundation, compId, proto, prio, ip, port, type, raddr, rport, tcptype);
    }

    @Override
    public String toString() {
        return toSdpLine();
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof IceCandidate)) return false;
        IceCandidate that = (IceCandidate) o;
        return componentId == that.componentId &&
                port == that.port &&
                protocol == that.protocol &&
                Objects.equals(ip, that.ip) &&
                type == that.type;
    }

    @Override
    public int hashCode() {
        return Objects.hash(componentId, protocol, ip, port, type);
    }
}
