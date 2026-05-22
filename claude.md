# CLAUDE.MD

## Project: DataForNerdsCollectors

A PowerShell 7.5+ module that scrapes data from public sources and provides normalized, JSON-ready output for IT professionals. Designed to be portable and run on both Windows and Linux.

## Current State (v1.0.1)

**Module**: `DataForNerdsCollectors` in `Modules/DataForNerdsCollectors/`

**Current Collectors**:

1. **Windows Update History** (`Get-WindowsUpdateHistory`)
   - Scrapes Windows 10 and Windows 11 client OS update pages from Microsoft
   - Supports `-MajorVersion`, `-WindowsVersion`, `-IncludePreview`, `-IncludeHotpatch` filters
   - Output: 9 fields (OSType, MajorVersion, WindowsVersion, KBNumber, OSBuild, FullVersion, ReleaseDate, ReleaseType, ArticleUrl)

2. **Office Language Codes** (`Get-LanguageCodes`)
   - Scrapes Office language codes table from MS-OE376 specification (Microsoft Learn)
   - Returns 223 language code entries with LCID mappings to BCP 47 codes
   - Output: 3 fields (LanguageCode, Description, BCP47)

3. **Microsoft 365 Apps Update History** (`Get-Microsoft365AppsUpdateHistory`)
   - Scrapes the "Update history for Microsoft 365 Apps (listed by date)" page (Microsoft Learn)
   - Channel columns are read dynamically from table headers (no hard-coded positions)
   - Cells with multiple `Version NNNN (Build NNNNN.NNNNN)` entries are exploded into one record each
   - Output: 4 fields (ReleaseDate, ChannelName, Version, Build)

**Architecture**:
- `.psm1` loader: Constants (URLs, headers) + recursive dot-sourcing of `Public/*.ps1` and `Private/**/*.ps1`
- `Public/`: Exported functions (one file per function: `Get-WindowsUpdateHistory.ps1`, `Get-LanguageCodes.ps1`, `Get-Microsoft365AppsUpdateHistory.ps1`)
- `Private/`: Internal helpers
  - `Invoke-ModuleWebRequest.ps1`: Reusable web request helper (fetches with standard headers, error handling)
  - Parser functions: `ConvertTo-Win10UpdateEntries.ps1`, `ConvertTo-Win11UpdateEntries.ps1`, `ConvertTo-Win11HotpatchEntries.ps1`, `ConvertTo-LanguageCodeEntries.ps1`, `ConvertTo-Microsoft365AppsUpdateEntries.ps1`
  - Utility functions: `Resolve-ArticleUrl.ps1`
  - Subfolders (e.g., `Private/WindowsServer/`) reserved for future multi-OS support
- Pre-commit hook at `.githooks/`: Auto-increments build (patch) version when module files change

**Versioning** (1.x.y):
- Major: 1 (locked)
- Minor: Incremented manually when merging to main (reset patch to 0)
- Patch/Build: Auto-incremented by pre-commit hook on any staged module changes

**Output Schemas**:
- **Windows Update History** (9 fields):
  ```
  OSType, MajorVersion, WindowsVersion, KBNumber, OSBuild, FullVersion, ReleaseDate, ReleaseType, ArticleUrl
  ```
  OSType is always 'Client'; will distinguish from 'Server' when server OS collectors added.

- **Office Language Codes** (3 fields):
  ```
  LanguageCode, Description, BCP47
  ```
  LanguageCode is the LCID (e.g., '1033'), Description is human-readable (e.g., 'English - United States'), BCP47 is the standard code (e.g., 'en-US').

- **Microsoft 365 Apps Update History** (4 fields):
  ```
  ReleaseDate, ChannelName, Version, Build
  ```
  ReleaseDate is ISO yyyy-MM-dd (Year column + Release Date column combined), ChannelName is the full channel name from the table header (e.g., 'Current Channel', 'Monthly Enterprise Channel'), Version is e.g. '2604', Build is e.g. '19929.20172'.

## Key Guidelines

- Do not automatically stage new code in git
- PowerShell v7.5.5+ required (but never a newer major version)
- Cross-platform (Windows and Linux)
- Output must be JSON-serializable
- Code: well-documented, easy to understand, not obfuscated
- Cite original sources when code from other projects is used
- When running pwsh.exe for testing, use the -NoProfile parameter

## Future Expansion

Module is intentionally named broad (DataForNerdsCollectors, not WindowsUpdateCollectors) to accommodate:
- Server OS update history (Windows Server 2019, 2022, etc.) — will add `Get-WindowsServerUpdateHistory`
- Other IT data collectors (DNS, patching timelines, etc.)

When adding new collectors:
1. Create new Public function file (e.g., `Public/Get-SomethingNew.ps1`)
2. Create corresponding Private parser function (e.g., `Private/ConvertTo-SomethingNewEntries.ps1`)
3. Use `Invoke-ModuleWebRequest` for all web requests to maintain consistent headers and error handling
4. Create new Private subfolder (e.g., `Private/WindowsServer/`) only if collector needs OS-specific parsers
5. Define return schema with clear field names; add `OSType` field if distinguishing from other collectors
6. Export new function in `.psm1` and update `.psd1` manifest

## Git Setup

After cloning: `git config core.hooksPath .githooks` to activate auto-versioning hook.

.gitignore excludes:
- Local settings (*.local.json)
- Secrets (.env, credentials, keys)
- OS/IDE files
- Build artifacts
- Downloaded data (output/, data/, downloads/)