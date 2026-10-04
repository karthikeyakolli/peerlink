# PeerLink — Account, Device Identity and Trust

## Three distinct layers

```text
Account identity
   ↓
Supabase Auth

Device identity
   ↓
PeerLink cryptographic keypair + Peer ID

Peer trust/authorization
   ↓
Local trust store + policy
```

These layers must never be conflated.

## Account identity

Used for:

- sign-in.
- cloud control-plane access.
- account-level device management.

## Device identity

Every installed PeerLink node owns a cryptographic identity.

Properties:

- stable Peer ID.
- private key protected by platform secure storage.
- public identity material.
- fingerprint.
- key lifecycle state.

## Enrollment

1. Authenticate account.
2. Create or load local cryptographic identity.
3. Register device with the control plane.
4. Bind device identity to the authenticated account.
5. Store only required credentials securely.

## Pairing

Discovery produces a candidate only.

```text
Discovery
 -> candidate
 -> cryptographic handshake
 -> fingerprint verification
 -> authorization
 -> trusted peer
```

IP addresses, hostnames and aliases are never trust anchors.

## Local IPC authentication

Desktop Flutter UI ↔ Java Node must authenticate.

Options include:

- per-installation secret.
- mutually authenticated local channel.
- OS-backed local credential.

The mechanism selected during implementation must prevent another local process from impersonating the UI merely by connecting to the port.

## Revocation

- local revocation is immediate.
- distributed revocation propagates after reconnection.
- active sessions use bounded authorization lifetimes.
- UI explicitly reports revocation propagation state.

## Recovery

Device identity recovery is an ownership-verification process, not an account-login shortcut.

Possible recovery material:

- encrypted recovery package.
- recovery passphrase/key.
- optional trusted-device authorization.

A recovered device must receive a fresh cryptographic binding if the original private key cannot be safely recovered.
