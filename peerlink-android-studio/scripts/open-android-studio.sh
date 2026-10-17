#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Opening PeerLink Android Studio Edition in Android Studio..."
if command -v studio >/dev/null 2>&1; then
    studio "$DIR" &
elif command -v studio64.exe >/dev/null 2>&1; then
    studio64.exe "$DIR" &
else
    echo "Please open Android Studio and choose: $DIR"
fi
