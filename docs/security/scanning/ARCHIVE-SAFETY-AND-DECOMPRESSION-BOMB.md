# Archive Safety & Decompression Bomb Defense

## Defense Mechanism

Decompression bombs (zip bombs) can exhaust memory, CPU, and disk space through extreme compression ratios or recursive nesting.

### Strict Enforcement Limits:
1. **Max Recursion Depth:** 3 levels of nested archives.
2. **Max Total Extracted Bytes:** 100 MB per archive scan.
3. **Max Compression Ratio:** 100:1. If `uncompressedSize / compressedSize > 100.0`, the archive is immediately classified as a decompression bomb.
4. **Max Total Entries:** 5,000 files in a single archive.
5. **Path Traversal Protection:** Entry names containing `..` or leading slashes (`/`, `\`) are immediately rejected.
6. **Zero-Disk Extraction:** Archives are inspected via bounded memory streams without writing untrusted uncompressed files to disk.