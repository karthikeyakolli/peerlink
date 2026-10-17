#!/usr/bin/env bash
# PeerLink Platform Shared Parity Verification Tool (Bash)
# Redirects to the peer-to-peer read-only platform parity verifier.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

exec "$REPO_ROOT/tools/platform-parity/verify-platform-parity.sh" "$@"
