# File Branch Lineage Tracking

Within a Shared Space, collaborative file updates are recorded as an immutable sequence of revisions:
- `ObjectId`: Persistent logical identity of the entity.
- `versionSequence`: Monotonically incrementing revision counter.
- `modifierPeerId`: Peer identity that authored the change.
- `parentVersionSequence`: Immediate causal parent.
- `lineageHash`: Cryptographic SHA-256 chain validating history integrity.