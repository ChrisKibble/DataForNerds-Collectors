# CLAUDE.MD

## Project: DataForNerdsCollectors

A PowerShell 7.5+ module that scrapes data from public sources and provides normalized, JSON-ready output for IT professionals. Designed to be portable and run on both Windows and Linux.

## Current State (v1.0.1)

**Module**: `DataForNerdsCollectors` in `Modules/DataForNerdsCollectors/`

**Current Collector**: Windows Update History
- `Get-WindowsUpdateHistory`: Scrapes Windows 10 and Windows 11 client OS update pages from Microsoft
- Supports `-MajorVersion`, `-WindowsVersion`, `-IncludePreview`, `-IncludeHotpatch` filters
- Output: 9 fields including `OSType` (always 'Client' for now)

**Architecture**:
- `.psm1` loader: Constants (URLs, headers) + recursive dot-sourcing of `Public/*.ps1` and `Private/**/*.ps1`
- `Public/`: Exported functions (one file per function)
- `Private/`: Internal helpers (no folder structure yet, but will have subfolders like `Private/WindowsClient/` when server support added)
- Pre-commit hook at `.githooks/`: Auto-increments build (patch) version when module files change

**Versioning** (1.x.y):
- Major: 1 (locked)
- Minor: Incremented manually when merging to main (reset patch to 0)
- Patch/Build: Auto-incremented by pre-commit hook on any staged module changes

**Output Schema** (9 fields):
```
OSType, MajorVersion, WindowsVersion, KBNumber, OSBuild, FullVersion, ReleaseDate, ReleaseType, ArticleUrl
```
OSType is 'Client' now; will be 'Server' for future server OS collectors.

## Key Guidelines

- Do not automatically stage new code in git
- PowerShell v7.5.5+ required (but never a newer major version)
- Cross-platform (Windows and Linux)
- Output must be JSON-serializable
- Code: well-documented, easy to understand, not obfuscated
- Cite original sources when code from other projects is used

## Future Expansion

Module is intentionally named broad (DataForNerdsCollectors, not WindowsUpdateCollectors) to accommodate:
- Server OS update history (Windows Server 2019, 2022, etc.) — will add `Get-WindowsServerUpdateHistory`
- Other IT data collectors (DNS, patching timelines, etc.)

When adding new collectors:
1. Create new Public function file
2. Create new Private subfolder (e.g., `Private/WindowsServer/`) for OS-specific parsers
3. Ensure output includes appropriate `OSType` field for filtering

## Git Setup

After cloning: `git config core.hooksPath .githooks` to activate auto-versioning hook.

.gitignore excludes:
- Local settings (*.local.json)
- Secrets (.env, credentials, keys)
- OS/IDE files
- Build artifacts
- Downloaded data (output/, data/, downloads/)