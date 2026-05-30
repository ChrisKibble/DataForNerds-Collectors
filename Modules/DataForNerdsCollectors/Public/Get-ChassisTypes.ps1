function Get-ChassisTypes {
    <#
    .SYNOPSIS
        Returns the SMBIOS chassis type codes and names from Microsoft's Win32_SystemEnclosure documentation.

    .DESCRIPTION
        Fetches the Microsoft Learn "Win32_SystemEnclosure class" page and parses the
        enumeration listed under the ChassisTypes property. Returns one object per
        chassis type with:

            ID   - SMBIOS chassis type numeric identifier, e.g. 9 (Laptop)
            Type - Human-readable chassis type, e.g. 'Laptop', 'Desktop', 'Pizza Box'

        Only the ChassisTypes enumeration is returned; other value tables on the same
        page (SecurityBreach, SecurityStatus, ServiceDescriptions) are ignored.

    .EXAMPLE
        Get-ChassisTypes | ConvertTo-Json

        Returns all chassis types as a JSON array.

    .EXAMPLE
        Get-ChassisTypes | Where-Object { $_.ID -eq 9 }

        Returns the entry for Laptop (ID 9).

    .OUTPUTS
        PSCustomObject[]
        Each object has: ID (Int), Type (String).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param ()

    $ChassisTypesUrl = 'https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-systemenclosure'

    Write-Verbose "Fetching chassis types from Microsoft Learn"
    $response = Invoke-ModuleWebRequest -Uri $ChassisTypesUrl -ErrorAction SilentlyContinue

    if (-not $response) {
        Write-Warning 'Failed to fetch chassis types page.'
        return @()
    }

    Write-Verbose "Page size: $($response.Content.Length) bytes"
    $chassisTypes = ConvertTo-ChassisTypeEntries -Html $response.Content

    if ($chassisTypes.Count -eq 0) {
        Write-Warning 'No chassis type entries were found. The page structure may have changed.'
    }
    else {
        Write-Verbose "Returning $($chassisTypes.Count) chassis type entries"
    }

    return $chassisTypes
}
