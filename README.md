# PeerLink — Project Documentation Baseline

**Status:** Architecture and product scope frozen for implementation, subject only to evidence-driven changes.

## Purpose

PeerLink is a privacy-first distributed personal data platform connecting trusted devices directly. It is **not** a cloud drive and **not** a web application. Its product intents are:

1. **SEND** — copy data once.
2. **ACCESS** — use authorized remote data on demand.
3. **SYNC** — keep replicas convergent.
4. **BACKUP** — preserve recoverable historical copies.

`CONNECT` is the trusted-device relationship underneath those intents.

## Current target platforms

- **V1 implementation priority:** Windows desktop + Android.
- **Architecture-compatible:** Linux + macOS.
- **Future-compatible protocol:** iOS/iPadOS and other clients.

## Core architectural rule

> **PeerLink is protocol-first and platform-aware, not source-code-first.**

Flutter provides the cross-platform application/UI surface. Java is the primary desktop/local-node implementation language and the shared JVM core language where Android compatibility permits. Kotlin/native APIs handle Android and other OS-specific capabilities.

## Read order

1. `docs/architecture/FINAL-ARCHITECTURE.md`
2. `docs/architecture/FROZEN-DECISIONS.md`
3. `docs/architecture/CONTRADICTIONS-AND-CONSTRAINTS.md`
4. `docs/architecture/TECH-STACK.md`
5. `docs/platforms/CROSS-PLATFORM-DESIGN.md`
6. `docs/protocol/PROTOCOL-AND-CONTRACTS.md`
7. `docs/development/DEVELOPMENT-ENVIRONMENT.md`
8. `docs/development/PHASE-WISE-PLAN.md`
9. `docs/testing/VERIFICATION-PLAN.md`
10. `docs/development/AI-AGENT-WORKFLOW.md`
11. `docs/security/SECURITY-SCANNING.md`

## Change policy

Do not silently change architecture. A proposed change must first be categorized as one of:

- security defect
- correctness/data-loss risk
- genuine architectural contradiction
- external platform requirement
- measured scalability/performance requirement

Then create or update an ADR before implementation.
