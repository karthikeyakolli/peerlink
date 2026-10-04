# PeerLink Testing & Diagnostics Tools

This directory contains standalone tools and harnesses used for P2P testing, conformance verification, and diagnostics:

1. **`peerlink-test-peer/`**: Standalone mock node instance runner to simulate remote peers on localhost or local network.
2. **`protocol-tester/`**: Protocol conformance harness sending raw protobuf frames to verify version negotiation, error handling, and malformed input safety.
3. **`network-fault-injector/`**: Traffic manipulation tool for testing latency, packet loss, socket drops, and NAT timeout behavior.
4. **`file-generator/`**: Deterministic test file generator for edge cases (0 bytes, 100MB+, sparse files, Unicode paths, locked handles).
5. **`diagnostics/`**: Environment collector and crash dump analyzer.
