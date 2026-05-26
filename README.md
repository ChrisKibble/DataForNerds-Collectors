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

## Consuming the Data

The collected data is available as a free JSON API. See the [API Reference](https://datafornerds.io/api/overview) for endpoints, schemas, and usage examples.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute.

## License

See the [LICENSE](LICENSE) file for details.
