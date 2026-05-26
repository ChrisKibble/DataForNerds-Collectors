# Contributing to DataForNerds Collectors

Thank you for your interest in contributing to DataForNerds Collectors! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please be respectful and constructive in all interactions. We are committed to providing a welcoming and inclusive experience for everyone.

## How to Contribute

### Reporting Bugs

If a collector is returning incorrect or incomplete data, please [open an issue](https://github.com/ChrisKibble/DataForNerds-Collectors/issues/new) with:

- The collector function name (e.g., `Get-WindowsUpdateHistory`)
- What you expected vs. what you got
- Your PowerShell version (`$PSVersionTable.PSVersion`)
- Your operating system

### Suggesting New Collectors

New collector ideas are welcome. Open an issue describing:

- The data source (must be publicly accessible Microsoft documentation)
- The fields you'd expect in the output
- A link to the source page

### Submitting Changes

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Test on both Windows and PowerShell 7.4+ on Linux if possible
5. Submit a pull request

## Development Setup

```powershell
git clone https://github.com/<your-fork>/DataForNerds-Collectors.git
cd DataForNerds-Collectors
git config core.hooksPath .githooks
Import-Module ./Modules/DataForNerdsCollectors -Force
```

The `core.hooksPath` setting activates the pre-commit hook that auto-increments the module's patch version when module files change.

## Project Structure

```
Collectors/
├── .githooks/                          # Pre-commit version bump
└── Modules/DataForNerdsCollectors/
    ├── DataForNerdsCollectors.psd1     # Module manifest
    ├── DataForNerdsCollectors.psm1     # Module loader
    ├── Public/                         # Exported functions (one per file)
    └── Private/                        # Internal helpers and parsers
```

## Adding a New Collector

1. Create a public function in `Public/` (e.g., `Get-NewDataSource.ps1`)
2. Create a corresponding parser in `Private/` (e.g., `ConvertTo-NewDataSourceEntries.ps1`)
3. Use `Invoke-ModuleWebRequest` for all HTTP requests
4. Add the function name to `FunctionsToExport` in the `.psd1` manifest
5. Define clear, consistent field names in the output objects

## Coding Guidelines

- **PowerShell 7.4+** is required, but do not use features from a newer major version
- **Cross-platform**: collectors must work on both Windows and Linux
- **JSON-serializable output**: all returned objects must serialize cleanly with `ConvertTo-Json`
- **No hardcoded column positions**: parse table headers dynamically when scraping HTML tables
- **One file per function**: public functions in `Public/`, private helpers in `Private/`
- **Use `Invoke-ModuleWebRequest`**: do not call `Invoke-WebRequest` or `Invoke-RestMethod` directly

## Versioning

The module follows a `1.x.y` versioning scheme:

- **Major (1)**: locked
- **Minor (x)**: incremented manually when merging to `main`; resets patch to 0
- **Patch (y)**: auto-incremented by the pre-commit hook

Do not manually change the patch version; the hook handles it.

## Questions?

Open an issue or visit [datafornerds.io](https://datafornerds.io) for more information about the project.
