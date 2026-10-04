# coturn Server Deployment & Integration

## 1. Overview
PeerLink uses **coturn** as its standard, high-performance open-source STUN and TURN server implementation.

---

## 2. Minimal `turnserver.conf` Configuration
```conf
# Networking & Listening Ports
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0
external-ip=203.0.113.1

# Transport protocols
udp-thread=4
no-udp=false
no-tcp=false
no-tls=false

# Realm & Authentication
realm=peerlink.org
lt-cred-mech

# Static Credentials (for private relay)
user=peerlink_node:SecureCoturnSecret2026!

# Ephemeral Port Allocation Range
min-port=49152
max-port=65535

# Security hardening
no-loopback-peers
no-multicast-peers
mobility
fingerprint
```

---

## 3. Docker Deployment
```bash
docker run -d \
  --name peerlink-coturn \
  --network host \
  coturn/coturn:latest \
  -n --log-file=stdout \
  --listening-port=3478 \
  --fingerprint \
  --lt-cred-mech \
  --realm=peerlink.org \
  --user=peerlink_node:SecureCoturnSecret2026! \
  --external-ip=203.0.113.1
```

---

## 4. Client Configuration in PeerLink
```java
CoturnConfig config = CoturnConfig.create(
    "turn.peerlink.org",
    3478,
    "peerlink_node",
    "SecureCoturnSecret2026!",
    TransportProtocol.UDP
);
```
