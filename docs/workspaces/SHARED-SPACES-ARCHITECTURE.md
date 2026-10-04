# Shared Spaces Architecture & Role-Based Access Control

## Objectives

Implement collaborative shared spaces on top of PeerLink's core authorization and operation engine.

## Roles & Permissions

Every member in a Shared Space holds one of six distinct roles:

| Role | Admin / Invite | Write / Update | Delete File | Read Payloads | View Metadata |
|---|:---:|:---:|:---:|:---:|:---:|
| `OWNER` | YES | YES | YES | YES | YES |
| `ADMIN` | YES | YES | YES | YES | YES |
| `EDITOR` | NO | YES | YES | YES | YES |
| `CONTRIBUTOR` | NO | YES | NO | YES | YES |
| `VIEWER` | NO | NO | NO | YES | YES |
| `OBSERVER` | NO | NO | NO | NO | YES |

## Policy Epochs & Immediate Revocation

To prevent unauthorized operations from executing with stale capability tokens:
- Every member invitation, removal, revocation, or role change monotonically increments `policyEpoch`.
- In-flight or cached operations presenting an older epoch fail authorization immediately.
- Revoked members are recorded in a permanent tombstone blacklist and cannot be re-invited without explicit administrative pardon.