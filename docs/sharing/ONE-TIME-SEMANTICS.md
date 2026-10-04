# One-Time Share Design

## Motivation

One-time shares allow the owner to offer a capability that is consumed exactly once, while still supporting reliable delivery in unreliable network conditions.

## Core Rules

1. **Single consumption**: A one-time share may be used for exactly one complete operation.
2. **Idempotent retry**: The holder may retry the **same operation ID** any number of times (e.g. after a network interruption). The operation ID is the identity of the transfer, not each individual request.
3. **New operation blocked**: Once consumed, any request carrying a **different operation ID** is rejected.
4. **No blind repeat**: The system never blindly repeats a one-time use — the operationId check prevents confusion between a retry and a new, unauthorized use.

## State Machine

`
ACTIVE
  │
  │  first authorized use (op_A)
  ▼
ACTIVE (operation running)
  │
  │  markConsumed(op_A)
  ▼
CONSUMED
  │
  ├─── retry(op_A) ──→ AUTHORIZED (idempotent)
  └─── use(op_B)   ──→ REJECTED
`

## OperationId Lifecycle

- The operation ID is created by the requesting peer at transfer start.
- It must remain stable for all chunks and retries of the same logical transfer.
- It is bound in the one-time ShareCapability token at issuance time.
- On completion, the owner's OneTimeConsumptionTracker records it permanently.
