# Scanner Providers & Adapters

## ScannerProvider Abstraction

PeerLink connects to host antimalware engines using the `ScannerProvider` interface:
- `String getProviderName()`
- `boolean isAvailable()`
- `SecurityVerdict scanStream(InputStream inputStream)`
- `SecurityVerdict scanFile(String filePath)`

## Supported Adapters

### 1. Microsoft Defender (`WindowsDefenderScanner`)
- Uses `MpCmdRun.exe` CLI (`-Scan -ScanType 3 -File <path> -DisableRemediation`).
- Disables automatic remediation to preserve quarantine management within PeerLink.
- Exit code 0 indicates clean; exit code 2 indicates threat detected.

### 2. ClamAV (`ClamAvScanner`)
- Designed for Linux and cross-platform servers.
- Uses `clamd` UNIX domain socket or TCP port (`zINSTREAM` protocol).

### 3. Scan Cache (`ScanCache`)
- Caches scan results keyed by file `ContentHash`.
- Cache entries have a 24-hour TTL.
- Invariant: `UNAVAILABLE` and `SCAN_FAILED` verdicts are never cached.