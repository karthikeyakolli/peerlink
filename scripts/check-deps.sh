#!/usr/bin/env bash
set -euo pipefail

echo "Verifying PeerLink architectural boundaries and forbidden dependencies..."

violations=0
forbidden=("org.springframework" "spring-boot" "redis.clients" "io.lettuce" "javafx" "org.openjfx")

for pom in $(find . -name "pom.xml"); do
    for pattern in "${forbidden[@]}"; do
        if grep -q "$pattern" "$pom" && ! grep -q "bannedDependencies" "$pom"; then
            echo "VIOLATION: Found forbidden dependency pattern '$pattern' in $pom"
            violations=$((violations + 1))
        fi
    done
done

for plat in windows linux macos android core; do
    if [ -d "$plat/src/main/java" ]; then
        for src in $(find "$plat/src/main/java" -name "*.java"); do
            if grep -q -E "import (android\.|com\.sun\.|javafx\.)" "$src"; then
                echo "VIOLATION: $plat source imports OS-specific or banned package in $src"
                violations=$((violations + 1))
            fi
        done
    fi
done

retired_app="apps/""peerlink-app"
for bf in $(find . -type f \( -name "pom.xml" -o -name "pubspec.yaml" -o -name "*.gradle*" \) ! -path "*/.git/*" ! -path "*/target/*" ! -path "*/.dart_tool/*"); do
    if grep -q -E "$retired_app" "$bf"; then
        echo "VIOLATION: Build file references retired apps path in $bf"
        violations=$((violations + 1))
    fi
done

if [ "$violations" -eq 0 ]; then
    echo "PASS: No forbidden dependencies or boundary violations detected."
    exit 0
else
    echo "FAIL: Detected $violations boundary violation(s)."
    exit 1
fi
