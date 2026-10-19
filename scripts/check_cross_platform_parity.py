#!/usr/bin/env python3
"""
PeerLink Cross-Platform Parity Checker
Non-destructively audits every maintained OS-specific project against the
reference Android Studio Edition.

Outputs:
- Machine-readable JSON manifest
- Human-readable summary table
- Classifications: IDENTICAL, DIVERGENT, MISSING, INTENTIONALLY_PLATFORM_SPECIFIC
"""

import os
import sys
import hashlib
import json
import argparse
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

def classify_file(rel_path: str) -> str:
    norm = rel_path.replace("\\", "/")
    if norm.startswith("test/"):
        return "8. Tests and fixtures"
    elif "android_node_bridge" in norm or "android_node_status" in norm:
        return "3. Android-specific bridge or implementation"
    elif "windows_file_dialog" in norm:
        return "4. Windows-specific bridge or implementation"
    elif "linux" in norm and not norm.startswith("lib/design_system"):
        return "5. Linux-specific bridge or implementation"
    elif "macos" in norm and not norm.startswith("lib/design_system"):
        return "6. macOS-specific bridge or implementation"
    elif norm.startswith("lib/core/protocol/") or norm in [
        "lib/core/app_constants.dart",
        "lib/core/pairing_invitation.dart",
        "lib/core/transfer/transfer_progress_model.dart",
        "lib/core/sync_backup_service.dart",
        "lib/core/device_trust_service.dart",
        "lib/core/operation_journal_service.dart",
        "lib/core/node_ipc_client.dart",
        "lib/core/platform/platform_capabilities.dart",
        "lib/platform/platform_capabilities.dart"
    ]:
        return "1. Platform-neutral model or contract"
    elif norm in ["pubspec.yaml", "analysis_options.yaml"]:
        return "7. Canonical source or build configuration"
    else:
        return "2. Shared Flutter UI or application logic"

# Explicit allowlist of files with intentional platform-specific divergence if needed
INTENTIONAL_PLATFORM_SPECIFIC_ALLOWLIST = {
    "windows_flutter": {"lib/platform/windows_file_dialog.dart"},
    "android_flutter": {"lib/platform/android_node_bridge.dart", "lib/features/android/android_node_status_widget.dart"},
    "linux_flutter": set(),
    "macos_flutter": set(),
    "canonical_flutter": set()
}

def audit_parity() -> Dict:
    ref_files = {}
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
                ref_files[rel_path] = (full_path, sha256_file(full_path), classify_file(rel_path))

    report = {
        "reference_files_total": len(ref_files),
        "classification_summary": {},
        "targets": {}
    }

    # Count categories in reference
    for _, _, cat in ref_files.values():
        report["classification_summary"][cat] = report["classification_summary"].get(cat, 0) + 1

    for target_key, target_path in TARGET_PROJECTS.items():
        allowed_divergences = INTENTIONAL_PLATFORM_SPECIFIC_ALLOWLIST.get(target_key, set())
        target_info = {
            "path": os.path.relpath(target_path, REPO_ROOT).replace("\\", "/"),
            "identical": [],
            "divergent": [],
            "missing": [],
            "intentionally_adapted": [],
            "by_category": {},
            "stats": {
                "identical_count": 0,
                "divergent_count": 0,
                "missing_count": 0,
                "intentionally_adapted_count": 0,
                "total_checked": len(ref_files)
            }
        }

        for rel_path, (ref_full, ref_hash, category) in sorted(ref_files.items()):
            target_file = os.path.join(target_path, rel_path)
            cat_stats = target_info["by_category"].setdefault(category, {
                "identical": 0, "divergent": 0, "missing": 0, "adapted": 0, "total": 0
            })
            cat_stats["total"] += 1

            if not os.path.exists(target_file):
                target_info["missing"].append({
                    "path": rel_path,
                    "category": category,
                    "expected_sha256": ref_hash
                })
                cat_stats["missing"] += 1
            else:
                target_hash = sha256_file(target_file)
                if target_hash == ref_hash:
                    target_info["identical"].append({
                        "path": rel_path,
                        "category": category,
                        "sha256": ref_hash
                    })
                    cat_stats["identical"] += 1
                elif rel_path in allowed_divergences:
                    target_info["intentionally_adapted"].append({
                        "path": rel_path,
                        "category": category,
                        "target_sha256": target_hash,
                        "ref_sha256": ref_hash
                    })
                    cat_stats["adapted"] += 1
                else:
                    target_info["divergent"].append({
                        "path": rel_path,
                        "category": category,
                        "target_sha256": target_hash,
                        "ref_sha256": ref_hash
                    })
                    cat_stats["divergent"] += 1

        target_info["stats"]["identical_count"] = len(target_info["identical"])
        target_info["stats"]["divergent_count"] = len(target_info["divergent"])
        target_info["stats"]["missing_count"] = len(target_info["missing"])
        target_info["stats"]["intentionally_adapted_count"] = len(target_info["intentionally_adapted"])
        report["targets"][target_key] = target_info

    return report

def print_summary_table(report: Dict):
    print("=" * 80)
    print("PEERLINK CROSS-PLATFORM PARITY AUDIT SUMMARY (PHASE 11.2)")
    print(f"Reference: peerlink-android-studio ({report['reference_files_total']} source files)")
    print("=" * 80)
    print("Reference Source Breakdown by Classification Category:")
    for cat, count in sorted(report["classification_summary"].items()):
        print(f"  - {cat:<48}: {count:>3} files")
    print("-" * 80)
    print(f"{'Target Project':<26} | {'Identical':<9} | {'Adapted':<8} | {'Divergent':<9} | {'Missing':<7} | {'Parity %':<9}")
    print("-" * 80)

    for target_key, info in report["targets"].items():
        s = info["stats"]
        total = s["total_checked"]
        effective_matches = s["identical_count"] + s["intentionally_adapted_count"]
        pct = (effective_matches / total * 100.0) if total > 0 else 0.0
        print(f"{target_key:<26} | {s['identical_count']:<9} | {s['intentionally_adapted_count']:<8} | {s['divergent_count']:<9} | {s['missing_count']:<7} | {pct:>8.1f}%")

    print("=" * 80)

def main():
    parser = argparse.ArgumentParser(description="Check PeerLink cross-platform source parity")
    parser.add_argument("--json", help="Save machine-readable audit report to file")
    args = parser.parse_args()

    report = audit_parity()
    print_summary_table(report)

    if args.json:
        with open(args.json, "w") as f:
            json.dump(report, f, indent=2)
        print(f"Audit manifest written to: {args.json}")

if __name__ == "__main__":
    main()
