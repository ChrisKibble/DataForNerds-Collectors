# DataForNerds Collectors

A PowerShell module that collects and normalizes data from public Microsoft documentation into structured, JSON-ready objects. Part of the [DataForNerds](https://datafornerds.io) project.

The collected data is published as a free API at [api.datafornerds.io](https://api.datafornerds.io).

## Collectors

| Function | Description |
|---|---|
| `Get-WindowsUpdateHistory` | Windows 10, Windows 11, and Windows Server cumulative update history |
| `Get-WindowsReleaseHistory` | Windows 10 and Windows 11 version-to-build mappings |
| `Get-Microsoft365AppsUpdateHistory` | Microsoft 365 Apps version and build numbers by channel |
| `Get-LanguageCodes` | Office language locale IDs (LCID) and BCP 47 codes |

## Requirements

- PowerShell 7.4 or later
- Works on Windows and Linux

## Installation

```powershell
git clone https://github.com/ChrisKibble/DataForNerds-Collectors.git
cd DataForNerds-Collectors
Import-Module ./Modules/DataForNerdsCollectors
```

## Usage

```powershell
# Get all Windows update history
Get-WindowsUpdateHistory

# Filter to Windows 11 only
Get-WindowsUpdateHistory -MajorVersion 11

# Filter to a specific version
Get-WindowsUpdateHistory -MajorVersion 11 -WindowsVersion '24H2'

# Get Microsoft 365 Apps update history
Get-Microsoft365AppsUpdateHistory

# Get Windows release info
Get-WindowsReleaseHistory

# Get Office language codes
Get-LanguageCodes
```

## Output

Every function returns structured objects that serialize cleanly to JSON. See the [API documentation](https://datafornerds.io/api/overview) for full schema details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute.

## License

See the [LICENSE](LICENSE) file for details.
