# Relay Security & Metadata Exposure Analysis

## 1. Core Security Invariants

### 1.1 Relay Never Becomes a Trust Authority
- The coturn TURN relay is strictly a Layer-4 packet forwarder ("dumb pipe").
- It plays **zero role** in peer identity verification, trust evaluation, or session authorization.
- Peer identity is exclusively verified through Ed25519 cryptographic public keys stored in local trust stores.

### 1.2 No Application Plaintext on Relay
- Application payloads forwarded through TURN (such as file metadata, file chunk bytes, operation records) are encrypted using authenticated session ciphers (TLS 1.3 or Noise Protocol Framework).
- The relay only handles outer STUN/TURN headers and opaque ciphertext bytes.
- Even with full administrative access or compromised memory on the coturn server, an attacker cannot read, decrypt, or tamper with user file contents.

---

## 2. Documented Metadata Exposure

While content plaintext is cryptographically protected, relaying traffic inherently exposes certain transport-level metadata to the relay operator or network eavesdroppers:

| Exposed Metadata | Description | Risk Evaluation | Mitigation |
| :--- | :--- | :--- | :--- |
| **IP Addresses** | The public IP addresses of both connecting peers are visible to the TURN server. | Low (Standard routing requirement) | Use Direct P2P or Direct-Only policy when IP privacy between relay operator is required. |
| **Packet Timing & Size** | Arrival times and frame lengths are observable. | Low-to-Medium (Traffic analysis) | Padding frames and fixed chunk sizing (default 1 MB / 4 MB) prevent file fingerprinting. |
| **Data Volume** | Total bytes transferred across the relay can be tracked for quota/billing. | Low | Expected operational metric for TURN bandwidth accounting. |

---

## 3. Direct-Only Policy For Sensitive Environments
For air-gapped, defense, or strict compliance deployments where third-party relaying is unacceptable:
```java
PathSelector.Policy policy = PathSelector.Policy.directOnly();
```
When `directOnly` is enabled, the ICE agent immediately drops all `RELAY` candidates, guaranteeing that connections either establish directly or fail cleanly with an explanatory diagnostic code.
