# PeerLink for Linux (Self-Contained Platform Project)

This directory contains the complete, self-contained implementation of PeerLink for Linux.

## Modules:
- core/, protocol/, operations/, transfer/, sync/, backup/, access/, sharing/, workspace/, clipboard/, compatibility/, security/, recovery/, diagnostics/
- filesystem/: Linux inotify watcher
- os/: Linux native integrations (D-Bus, XDG, Secret Service, systemd-logind power management)
- networking/: Linux epoll Netty transport
- app/: Flutter desktop application for Linux
