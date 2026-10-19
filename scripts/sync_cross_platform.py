#!/usr/bin/env python3
"""
PeerLink Cross-Platform Source Synchronization Tool
Authoritatively synchronizes the PeerLink Android Studio Edition's Flutter
source tree into all maintained OS-specific projects and shared-source canonical.

Invariants:
- Preserves native project structure and build metadata.
- Non-destructive (no arbitrary deletions).
- Dry-run / preview mode supported.
- Idempotent repeat execution.
- Generates machine-readable manifest and human-readable summary.
"""

import os
import sys
import hashlib
import json
import argparse
import shutil
from typing import Dict, List, Tuple

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
REF_PROJECT = os.path.join(REPO_ROOT, "peerlink-android-studio")

TARGET_PROJECTS = {
    "windows_flutter": os.path.join(REPO_ROOT, "windows", "app", "flutter"),
    "linux_flutter": os.path.join(REPO_ROOT, "linux", "app", "flutter"),
    "macos_flutter": os.path.join(REPO_ROOT, "macos", "app", "flutter"),
    "android_flutter": os.path.join(REPO_ROOT, "android", "app", "flutter"),
    "canonical_flutter": os.path.join(REPO_ROOT, "shared-source", "canonical", "flutter")
}

SYNC_DIRECTORIES = ["lib", "test", "assets"]

# Files to strictly exclude from bulk synchronization
EXCLUDE_REL_PATHS = {
    ".dart_tool",
    "build",
    ".flutter-plugins",
    ".flutter-plugins-dependencies",
    "pubspec.lock"
}

def sha256_file(filepath: str) -> str:
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def collect_reference_files() -> Dict[str, str]:
    files = {}
    for d in SYNC_DIRECTORIES:
        base_dir = os.path.join(REF_PROJECT, d)
        if not os.path.exists(base_dir):
            continue
        for root, dirs, filenames in os.walk(base_dir):
            dirs[:] = [dr for dr in dirs if dr not in EXCLUDE_REL_PATHS]
            for fn in filenames:
                if fn in EXCLUDE_REL_PATHS or fn.endswith(".lock"):
                    continue
                full_path = os.path.join(root, fn)
                rel_path = os.path.relpath(full_path, REF_PROJECT).replace("\\", "/")
                files[rel_path] = full_path
    return files

def sync_targets(apply_changes: bool, selected_targets: List[str] = None) -> Dict:
    ref_files = collect_reference_files()
    targets = {k: v for k, v in TARGET_PROJECTS.items() if (selected_targets is None or k in selected_targets)}

    summary = {
        "apply": apply_changes,
        "reference_file_count": len(ref_files),
        "target_results": {}
    }

    print("=" * 80)
    print(f"PeerLink Cross-Platform Source Synchronization ({'APPLY' if apply_changes else 'DRY RUN'})")
    print(f"Reference: {REF_PROJECT} ({len(ref_files)} files)")
    print("=" * 80)

    for target_name, target_dir in targets.items():
        print(f"\nProcessing target: {target_name} -> {target_dir}")
        identical_count = 0
        created_files = []
        updated_files = []

        for rel_path, ref_full_path in sorted(ref_files.items()):
            target_file_path = os.path.join(target_dir, rel_path)
            ref_hash = sha256_file(ref_full_path)

            if not os.path.exists(target_file_path):
                created_files.append((rel_path, ref_hash))
                if apply_changes:
                    os.makedirs(os.path.dirname(target_file_path), exist_ok=True)
                    shutil.copy2(ref_full_path, target_file_path)
            else:
                target_hash = sha256_file(target_file_path)
                if target_hash == ref_hash:
                    identical_count += 1
                else:
                    updated_files.append((rel_path, target_hash[:8], ref_hash[:8]))
                    if apply_changes:
                        shutil.copy2(ref_full_path, target_file_path)

        summary["target_results"][target_name] = {
            "identical": identical_count,
            "created": [p for p, _ in created_files],
            "updated": [p for p, _, _ in updated_files],
            "total_synced": len(ref_files)
        }

        print(f"  Identical: {identical_count}")
        print(f"  New (to create): {len(created_files)}")
        for p, h in created_files:
            print(f"    + [NEW] {p}")
        print(f"  Divergent (to update): {len(updated_files)}")
        for p, old_h, new_h in updated_files:
            print(f"    ~ [UPDATE] {p} ({old_h} -> {new_h})")

    return summary

def main():
    parser = argparse.ArgumentParser(description="Synchronize PeerLink Android Studio source into OS targets")
    parser.add_argument("--apply", action="store_true", help="Apply synchronization changes (default: dry-run)")
    parser.add_argument("--dry-run", action="store_true", help="Explicit preview mode (default: dry-run)")
    parser.add_argument("--json", help="Save machine-readable summary JSON to filepath")
    parser.add_argument("--targets", nargs="+", help="Specific targets to synchronize")
    args = parser.parse_args()

    apply_mode = args.apply and not args.dry_run
    results = sync_targets(apply_changes=apply_mode, selected_targets=args.targets)

    if args.json:
        with open(args.json, "w") as f:
            json.dump(results, f, indent=2)
        print(f"\nManifest saved to: {args.json}")

    print("\n" + "=" * 80)
    if not args.apply:
        print("Dry run complete. Run with --apply to replicate changes.")
    else:
        print("Source synchronization complete.")
    print("=" * 80)

if __name__ == "__main__":
    main()
