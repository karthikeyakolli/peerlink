# PeerLink — Supabase Control Plane Boundary

## Supabase responsibilities

- account authentication.
- device registry.
- presence.
- signaling/connection coordination.
- share metadata.
- workspace membership/policy metadata.
- durable control-plane audit records where appropriate.

## Not Supabase responsibilities

- ordinary file contents.
- P2P transfer bytes.
- local file index.
- private sync state that should stay local.
- clipboard contents by default.
- normal previews.

## Durable vs transient

```text
Supabase Postgres
 -> durable control-plane state

Supabase Realtime
 -> presence / wakeup / transient coordination

PeerLink operation journal
 -> authoritative local operation state
```

If a Realtime event is missed, clients must be able to reconcile from durable state.

## Control-plane outage behavior

### Can continue where already authorized

- local file operations.
- existing LAN connections.
- established sessions within their authorization lifetime.

### May be delayed/unavailable

- new Internet discovery.
- cloud-assisted pairing.
- policy/key refresh.
- distributed revocation propagation.
- cloud-dependent account operations.

The UI must distinguish these states from a P2P engine failure.

## RLS and trusted server functions

Use row-level security for ordinary user-owned control data.

Use Edge Functions for privileged workflows that should not be safely exposed as unrestricted client-side database operations.

Never ship a Supabase service-role credential in PeerLink clients.
