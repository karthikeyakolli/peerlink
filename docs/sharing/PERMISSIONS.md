# Sharing Permissions Reference

## Permission Levels

| Permission | What It Allows |
|---|---|
| BROWSE | List directory contents and read metadata |
| SEARCH | Perform filename/content search within share |
| PREVIEW | Read limited bytes of file content (safe preview rules apply) |
| DOWNLOAD | Transfer complete file(s) to local device |
| DOWNLOAD_SINGLE | Download exactly one file (used for one-time shares) |

## Scoping Rules

1. **Capabilities carry explicit permission sets** — no implicit escalation.
2. **Share-level permissions constrain the maximum scope** — a capability cannot grant more than the share allows.
3. **Token-level permissions may be a subset** of share-level permissions.
4. **Permission checks are deterministic** — the same input always produces the same authorization decision.
5. **Scope cannot be bypassed** — there is no "super" flag or override path.

## Token Permission Hierarchy

`
ShareObject.permissions   (maximum allowed)
        │
        ▼ (subset or equal)
ShareCapability.permissions  (what token grants)
        │
        ▼ (exact match required)
Requested permission
`

## Guest Permission Constraints

- Guest tokens are isolated; they operate in an untrusted context.
- Guests cannot hold DOWNLOAD unless explicitly granted in the guest token.
- Guests cannot escalate to any trusted-peer permission by claiming a peer ID.
- Each guest token is scoped independently, with no inheritance from peer-specific tokens.

---

## Safe Preview Engine & Executable Ban

Files matching any executable or script patterns are strictly forbidden from preview generation:
- Extensions: `.exe`, `.dll`, `.so`, `.dylib`, `.bat`, `.cmd`, `.sh`, `.ps1`, `.app`, `.jar`, `.msi`, `.bin`, `.scr`, `.com`, `.vbs`, `.elf`
- Preview requests for these types throw `UnsafePreviewException` immediately.
- Previews for safe types (text, markdown, json, images) are capped to 64 KB maximum to prevent buffer overflow.

---

## Untrusted Remote Path Validation

Remote paths provided across the wire are treated as completely untrusted input:
- **Parent Traversal**: Sequences containing `..` or leading `/` or `\` are rejected.
- **Drive Letter Injection**: Windows drive patterns (e.g. `C:\`, `D:`) are rejected.
- **UNC Paths**: Network shares (e.g. `\\host\share`) are rejected.
- **Alternate Data Streams**: NTFS ADS streams (e.g. `file.txt:$DATA`) are rejected.
- **Null-Byte Poisoning**: Paths with `\0` are rejected.
- Paths must strictly resolve within the canonical `shareRoot` folder.

