# PeerLink — Agent Instructions

## Mission

Build PeerLink according to the frozen architecture and phase plan. Prefer correctness, recoverability, security and interoperability over speed of code generation.

## Mandatory rules

1. Read the relevant specification before modifying code.
2. Do not change frozen architecture silently.
3. Work in one phase/vertical slice at a time.
4. Do not mark a task complete without running the required verification.
5. Never place normal user file content in Supabase.
6. Never treat discovery as trust.
7. Never treat timestamps as sync truth.
8. Never treat watcher events as filesystem truth.
9. Never blindly replay destructive operations after uncertain outcomes.
10. Never auto-execute received files.
11. Never give AI authority over identity, encryption, trust, authorization, integrity, sync truth, deletion or execution.
12. Never trust localhost merely because it is localhost.

## Before coding

- inspect current repository
- identify affected contracts
- state plan
- identify tests
- identify platform-specific behavior

## After coding

- compile
- unit test
- integration test
- run application where applicable
- execute acceptance scenario
- inspect logs
- test at least one failure path
- report exact results

## No fabricated verification

Do not claim tests passed if they were not actually executed. Report unavailable tooling or untested platform cases explicitly.

## Scope discipline

Do not add convenience features, dependencies or frameworks unless they are justified by an existing frozen requirement or ADR.
