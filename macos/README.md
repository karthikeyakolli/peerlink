# PeerLink for macOS (Self-Contained Platform Project)

This directory contains the complete, self-contained implementation of PeerLink for macOS.

## Modules:
- core/, protocol/, operations/, transfer/, sync/, backup/, access/, sharing/, workspace/, clipboard/, compatibility/, security/, recovery/, diagnostics/
- filesystem/: macOS FSEvents watcher & APFS Unicode normalization
- os/: macOS native integrations (Keychain, Finder Sync, File Provider, IOKit power)
- networking/: macOS kqueue Netty transport
- app/: Flutter desktop application for macOS
