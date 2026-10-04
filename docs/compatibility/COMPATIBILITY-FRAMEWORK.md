# Cross-Platform Compatibility Framework

## Categories Evaluated

Every transfer is analyzed across six distinct categories:

1. **TRANSFER:** MTU bounds, chunk size limits, network payload framing.
2. **STORAGE:** Filesystem volume constraints (FAT32 4GB limits, max path lengths, illegal filename characters).
3. **OPEN:** Registered MIME handlers and default application associations.
4. **APPLICATION:** File format versions and schema continuity.
5. **EXECUTION:** Target OS architecture compatibility (PE on Windows, ELF on Linux, Mach-O on macOS).
6. **METADATA:** Preservation of POSIX permissions, symlinks, extended attributes, and EXIF privacy tags.

## Standard Results

- `COMPATIBLE`: Fully supported on target environment.
- `PARTIALLY_COMPATIBLE`: Usable, but some platform-specific attributes cannot be mapped directly.
- `INCOMPATIBLE`: Cannot be stored or opened on target without modification.
- `UNKNOWN`: Insufficient host environment information.
- `REQUIRES_USER_DECISION`: Requires explicit user confirmation (e.g., executing unsigned binaries, renaming reserved names).