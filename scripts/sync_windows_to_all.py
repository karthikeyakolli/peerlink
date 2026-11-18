#!/usr/bin/env python3
"""
Synchronizes Flutter files from windows/app/flutter to:
- peerlink-android-studio
- android/app/flutter
- shared-source/canonical/flutter
"""

import os
import shutil
import hashlib

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SOURCE = os.path.join(REPO_ROOT, "windows", "app", "flutter")
TARGETS = [
    os.path.join(REPO_ROOT, "peerlink-android-studio"),
    os.path.join(REPO_ROOT, "android", "app", "flutter"),
    os.path.join(REPO_ROOT, "shared-source", "canonical", "flutter"),
]

SYNC_DIRS = ["lib", "test", "assets"]
EXCLUDES = {".dart_tool", "build", ".flutter-plugins", ".flutter-plugins-dependencies", "pubspec.lock"}

def sha256_file(filepath: str) -> str:
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def sync():
    print(f"Syncing from source: {SOURCE}")
    copied = 0
    updated = 0
    identical = 0

    for d in SYNC_DIRS:
        src_base = os.path.join(SOURCE, d)
        if not os.path.exists(src_base):
            continue
        for root, dirs, filenames in os.walk(src_base):
            dirs[:] = [dr for dr in dirs if dr not in EXCLUDES]
            for fn in filenames:
                if fn in EXCLUDES or fn.endswith(".lock"):
                    continue
                src_file = os.path.join(root, fn)
                rel_path = os.path.relpath(src_file, SOURCE)
                src_hash = sha256_file(src_file)

                for tgt in TARGETS:
                    tgt_file = os.path.join(tgt, rel_path)
                    if not os.path.exists(tgt_file):
                        os.makedirs(os.path.dirname(tgt_file), exist_ok=True)
                        shutil.copy2(src_file, tgt_file)
                        copied += 1
                    else:
                        tgt_hash = sha256_file(tgt_file)
                        if tgt_hash != src_hash:
                            shutil.copy2(src_file, tgt_file)
                            updated += 1
                        else:
                            identical += 1

    print(f"Sync Complete: {copied} new files copied, {updated} files updated, {identical} already identical.")

if __name__ == "__main__":
    sync()
