# PeerLink Transport Abstraction Architecture

## 1. Overview and Core Philosophy

PeerLink's transport layer is designed around absolute portability and clean separation of concerns. In accordance with the project's architectural invariants:
- **Zero Netty or Transport Framework Leaks in Core:** The shared `core` module contains purely portable JVM abstractions (`TransportProvider`, `TransportConnection`, `TransportFrameHandler`, `ConnectionLifecycleListener`).
- **Pluggable Native Implementations:** Desktop nodes leverage Netty 4.2 for direct TCP/TLS and lightweight UDP framing for QUIC prototypes. Future Android or iOS platforms can implement `TransportProvider` using native platform sockets or Android-specific Cronet/QUIC libraries without touching protocol logic.
- **Protocol Agnostic to Transport:** The PeerLink protocol operates over generic length-delimited `TransportFrame` protobuf envelopes regardless of whether the underlying channel is QUIC, TCP/TLS, or a future relay.

```
       PeerLink Protocol (Protobuf V1)
                     ↓
             PeerSessionManager
                     ↓
             PeerSession (Authenticated)
                     ↓
             TransportConnection (Channel Contract)
                     ↓
       ┌─────────────────────────────┐
       │      TransportProvider      │
       └──────────────┬──────────────┘
                      │
        ┌─────────────┴─────────────┐
        ▼                           ▼
Desktop QUIC (UDP)         Desktop TCP/TLS (Netty)
(Priority 1: Default)      (Priority 2: Fallback)
```

---

## 2. Abstraction Interfaces (`org.peerlink.core.transport`)

### 2.1 `TransportProvider`
Represents an available network transport mechanism (e.g., Direct QUIC, TCP/TLS):
```java
public interface TransportProvider extends AutoCloseable {
    TransportType getTransportType();
    int getPriority(); // Lower value = higher priority (QUIC = 1, TCP/TLS = 2)
    boolean isAvailable();
    void startListening(int port, TransportConnectionListener listener) throws IOException;
    int getListeningPort();
    CompletableFuture<TransportConnection> connectAsync(InetSocketAddress remoteAddress);
}
```

### 2.2 `TransportConnection`
Represents an established, bidirectional communication channel between two network endpoints:
```java
public interface TransportConnection extends AutoCloseable {
    ConnectionId getConnectionId();
    TransportType getTransportType();
    ConnectionState getState(); // CONNECTING, CONNECTED, CLOSING, CLOSED
    InetSocketAddress getRemoteAddress();
    InetSocketAddress getLocalAddress();
    CompletableFuture<Void> sendFrameAsync(TransportFrame frame);
    void setFrameHandler(TransportFrameHandler handler);
    void addLifecycleListener(ConnectionLifecycleListener listener);
    CompletableFuture<Void> closeAsync();
}
```

### 2.3 `ConnectionLifecycleListener`
Provides asynchronous hooks for transport-level events:
```java
public interface ConnectionLifecycleListener {
    void onStateChanged(TransportConnection connection, ConnectionState oldState, ConnectionState newState);
    void onError(TransportConnection connection, Throwable throwable);
}
```

---

## 3. Desktop Implementations (`org.peerlink.desktop.transport`)

### 3.1 Direct QUIC Prototype (`DesktopQuicTransportProvider` & `DesktopQuicTransportConnection`)
- **Transport Type:** `TRANSPORT_TYPE_DIRECT_QUIC`
- **Priority:** `1` (Preferred candidate)
- **Protocol:** UDP Datagram with QUIC 1-RTT short-header framing:
  - 1 Byte Flags (`0xC0` short header marker)
  - 8 Bytes Destination Connection ID (DCID)
  - 8 Bytes Source Connection ID (SCID)
  - 8 Bytes Monotonic Packet Number
  - 4 Bytes Payload Length
  - N Bytes `TransportFrame` Protobuf Payload
- **Multiplexing:** Inbound datagrams are demultiplexed by DCID into discrete `DesktopQuicTransportConnection` instances.

### 3.2 Direct TCP/TLS Fallback (`NettyTcpTlsTransportProvider` & `NettyTcpTransportConnection`)
- **Transport Type:** `TRANSPORT_TYPE_DIRECT_TCP_TLS`
- **Priority:** `2` (Fallback candidate)
- **Engine:** Netty 4.2 `MultiThreadIoEventLoopGroup` with NIO transport (`NioServerSocketChannel`, `NioSocketChannel`).
- **Codec:** `TransportFrameCodec` (`ByteToMessageCodec<TransportFrame>`):
  - 4-byte length prefix framing (`ByteBuf.writeInt(len)`)
  - Protobuf parse/serialize (`TransportFrame.parseFrom(bytes)`)
  - Resource protection: Maximum frame size capped at 16MB (`MAX_FRAME_LENGTH`).

---

## 4. Capability Negotiation (`TransportCapabilityNegotiator`)

During session initiation, nodes exchange supported transport profiles in the handshake:
1. The initiator advertises all locally supported transports sorted by priority in `HandshakeFrame.supported_transports`.
2. The responder intersects the initiator's transports with its locally active providers.
3. The mutual candidate with the highest priority is chosen. If QUIC is mutually available, QUIC is selected. If only TCP/TLS is available, TCP/TLS is selected.
4. If no overlap exists, the handshake aborts with `ERROR_CODE_INCOMPATIBLE_PROTOCOL_VERSION`.

---

## 5. Session Lifecycle and Management

### 5.1 Keepalive and Heartbeats
- Periodic `KeepalivePing` frames are scheduled at configurable intervals (default: 5 seconds).
- The receiving peer immediately echoes a `KeepalivePong` containing the same sequence number and timestamp.
- Missed heartbeats exceeding the timeout threshold transition the session to `SESSION_STATE_CLOSED`.

### 5.2 Reconnection Skeleton
- Reconnection logic employs exponential backoff (`reconnectAsync`):
  - Base delay: 50ms
  - Multiplier: 2x per attempt
  - Maximum cap: 2,000ms
  - Configurable maximum retry attempts (e.g., 3-5).

### 5.3 Graceful Teardown
- Either peer can issue a `SessionCloseFrame` containing an optional `ErrorDetail` or reason string.
- In-flight operations finish before the underlying `TransportConnection.closeAsync()` tears down the network socket.
- `PeerSessionManager` automatically deregisters the closed session from both `activeSessionsByPeerId` and `activeSessionsBySessionId`.
