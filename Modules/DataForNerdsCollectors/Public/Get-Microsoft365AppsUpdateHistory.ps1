function Get-Microsoft365AppsUpdateHistory {
    <#
    .SYNOPSIS
        Returns Microsoft 365 Apps version and build numbers from the by-date update history page.

    .DESCRIPTION
        Fetches the "Update history for Microsoft 365 Apps (listed by date)" page from
        Microsoft Learn and parses the Version History table. Each cell can contain
        multiple version/build entries; each is emitted as its own record:

            ReleaseDate - ISO yyyy-MM-dd (Year column + Release Date column combined)
            ChannelName - e.g. 'Current Channel', 'Monthly Enterprise Channel',
                          'Semi-Annual Enterprise Channel (Preview)',
                          'Semi-Annual Enterprise Channel'
            Version     - e.g. '2604'
            Build       - e.g. '19929.20172'
            FullBuild   - e.g. '16.0.19929.20172'

    .EXAMPLE
        Get-Microsoft365AppsUpdateHistory | ConvertTo-Json -Depth 3

        Returns all entries as a JSON array.

    .EXAMPLE
        Get-Microsoft365AppsUpdateHistory | Where-Object ChannelName -eq 'Current Channel'

        Returns only Current Channel releases.

    .OUTPUTS
        PSCustomObject[]
        Each object has: ReleaseDate (String, ISO date), ChannelName (String),
        Version (String), Build (String), FullBuild (String).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param ()

    $Microsoft365AppsUpdateHistoryUrl = 'https://learn.microsoft.com/en-us/officeupdates/update-history-microsoft365-apps-by-date'

    Write-Verbose 'Fetching Microsoft 365 Apps update history from Microsoft Learn'
    $response = Invoke-ModuleWebRequest -Uri $Microsoft365AppsUpdateHistoryUrl -ErrorAction SilentlyContinue

    if (-not $response) {
        Write-Warning 'Failed to fetch Microsoft 365 Apps update history page.'
        return @()
    }

    Write-Verbose "Page size: $($response.Content.Length) bytes"
    $entries = ConvertTo-Microsoft365AppsUpdateEntries -Html $response.Content

    if ($entries.Count -eq 0) {
        Write-Warning 'No Microsoft 365 Apps update entries were found. The page structure may have changed.'
    }
    else {
        Write-Verbose "Returning $($entries.Count) Microsoft 365 Apps update entries"
    }

    return $entries
}
