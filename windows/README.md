# PeerLink for Windows (Self-Contained Platform Project)

This directory contains the complete, self-contained implementation of PeerLink for Windows.

## Modules:
- core/, protocol/, operations/, transfer/, sync/, backup/, access/, sharing/, workspace/, clipboard/, compatibility/, security/, recovery/, diagnostics/
- filesystem/: NTFS filesystem watcher & path sanitizer
- os/: Windows integrations (Explorer, DPAPI Credential Store, Firewall, Notifications, Power)
- networking/: Windows Direct QUIC, TCP/TLS, and ICE coordinators
- supabase/: Cloud control plane client
- app/: Flutter desktop application for Windows
