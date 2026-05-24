function Get-WindowsReleaseHistory {
    <#
    .SYNOPSIS
        Returns the Windows 10 and Windows 11 client version-to-base-build mapping from Microsoft's release information pages.

    .DESCRIPTION
        Fetches the Microsoft Learn "Windows 10 release information" and "Windows 11 release
        information" pages and parses each version section heading. Returns one object per
        listed Windows client version, including end-of-service versions still documented
        on the pages.

            OSType         - Always 'Client'
            MajorVersion   - 10 or 11
            WindowsVersion - e.g. '24H2', '22H2', '1809', or '1507' (initial Windows 10 release)
            OSBuild        - Base OS build, e.g. '26100' (no patch suffix)
            FullVersion    - '{MajorVersion}.0.{OSBuild}' form, e.g. '10.0.19045', '11.0.26100'

        Use Get-WindowsUpdateHistory when you need the full per-update detail
        (KB number, patched build, release date, etc.); this function returns only the
        version-to-base-build reference table.

    .EXAMPLE
        Get-WindowsReleaseHistory | ConvertTo-Json

        Returns every listed Windows 10 and Windows 11 client version as a JSON array.

    .EXAMPLE
        Get-WindowsReleaseHistory | Format-Table

        Displays the version-to-base-build mapping as a table.

    .OUTPUTS
        PSCustomObject[]
        Each object has: OSType (String), MajorVersion (Int), WindowsVersion (String),
        OSBuild (String), FullVersion (String).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param ()

    $allResults = [System.Collections.Generic.List[PSCustomObject]]::new()

    # --- Windows 10 ---
    Write-Verbose "Fetching Windows 10 release information page"
    $win10Response = Invoke-ModuleWebRequest -Uri $script:Windows10ReleaseHistoryUrl -ErrorAction SilentlyContinue
    if ($win10Response) {
        Write-Verbose "Windows 10 page size: $($win10Response.Content.Length) bytes"
        $win10Entries = ConvertTo-WindowsReleaseHistoryEntries -Html $win10Response.Content -MajorVersion 10
        foreach ($entry in $win10Entries) { $allResults.Add($entry) }
    }
    else {
        Write-Warning 'Failed to fetch Windows 10 release information page.'
    }

    # --- Windows 11 ---
    Write-Verbose "Fetching Windows 11 release information page"
    $win11Response = Invoke-ModuleWebRequest -Uri $script:Windows11ReleaseHistoryUrl -ErrorAction SilentlyContinue
    if ($win11Response) {
        Write-Verbose "Windows 11 page size: $($win11Response.Content.Length) bytes"
        $win11Entries = ConvertTo-WindowsReleaseHistoryEntries -Html $win11Response.Content -MajorVersion 11
        foreach ($entry in $win11Entries) { $allResults.Add($entry) }
    }
    else {
        Write-Warning 'Failed to fetch Windows 11 release information page.'
    }

    if ($allResults.Count -eq 0) {
        Write-Warning 'No Windows release entries were found. The page structure may have changed.'
    }
    else {
        Write-Verbose "Returning $($allResults.Count) Windows release entries"
    }

    return $allResults
}
