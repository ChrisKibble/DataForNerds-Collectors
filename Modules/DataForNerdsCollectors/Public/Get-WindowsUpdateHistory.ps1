function Get-WindowsUpdateHistory {
    <#
    .SYNOPSIS
        Returns Windows 10 and Windows 11 update entries from Microsoft's update history pages.

    .DESCRIPTION
        Fetches the Windows 10 and Windows 11 update history pages and parses the left-side
        navigation menus. Returns every discovered update — Standard, Preview, Out-of-band,
        Hotpatch, and Hotpatch-OOB — with the following fields:

            MajorVersion   - 10 or 11
            WindowsVersion - e.g. '22H2' (Win10), '24H2' (Win11), 'RTM' (Win10 initial)
            KBNumber       - e.g. 'KB5089544'
            OSBuild        - OS build string, e.g. '19045.7291' or '26100.8457'
            FullVersion    - Full Windows version in {Major}.0.{Build}.{UBR} format
            ReleaseDate    - ISO 8601 date, e.g. '2026-05-12'
            ReleaseType    - 'Standard', 'Preview', 'Out-of-band', 'Hotpatch', or 'Hotpatch-OOB'
            ArticleUrl     - Full URL of the KB article on support.microsoft.com

        When a KB targets multiple simultaneous OS builds, one object is returned per build.

    .PARAMETER MajorVersion
        Filters results to a specific Windows major version (10, 11, or both).
        Accepts an array; default is @(10, 11) (both versions).

    .PARAMETER WindowsVersion
        Filters results to a single version label, e.g. '22H2' (Win10) or '24H2' (Win11).
        When omitted, updates for all discovered versions are returned.

    .EXAMPLE
        Get-WindowsUpdateHistory | ConvertTo-Json -Depth 3

        Returns every update (Win10 + Win11, all release types, plus Win11 hotpatches) as JSON.

    .EXAMPLE
        Get-WindowsUpdateHistory -MajorVersion 11 -WindowsVersion '24H2' | ConvertTo-Json -Depth 3

        Returns all Windows 11 24H2 updates as JSON.

    .EXAMPLE
        Get-WindowsUpdateHistory | Where-Object ReleaseType -eq 'Preview'

        Returns only Preview releases across all versions.

    .OUTPUTS
        PSCustomObject[]
        Each object has: OSType (String), MajorVersion (Int), WindowsVersion (String),
        KBNumber (String), OSBuild (String), FullVersion (String), ReleaseDate (String),
        ReleaseType (String), ArticleUrl (String).
        OSType is always 'Client' for this function; use it to distinguish from server
        OS entries when combining output from multiple collectors.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(HelpMessage = "Filter to specific Windows major version(s): 10, 11, or both (default: both)")]
        [ValidateScript({ $_ -in @(10, 11) }, ErrorMessage = "MajorVersion must be 10 or 11")]
        [int[]]$MajorVersion,

        [Parameter(HelpMessage = "Filter to a specific version label, e.g. '22H2' (Win10) or '24H2' (Win11)")]
        [string]$WindowsVersion
    )

    $versionsToQuery = if ($MajorVersion) { $MajorVersion | Select-Object -Unique } else { @(10, 11) }
    $allResults      = [System.Collections.Generic.List[PSCustomObject]]::new()

    # --- Fetch Windows 10 updates if requested ---
    if (10 -in $versionsToQuery) {
        Write-Verbose "Fetching Windows 10 update history"
        $win10Response = Invoke-ModuleWebRequest -Uri $script:Win10UpdateHistoryUrl -ErrorAction SilentlyContinue
        if ($win10Response) {
            Write-Verbose "Windows 10 page size: $($win10Response.Content.Length) bytes"
            $win10Results = ConvertTo-Win10UpdateEntries -Html $win10Response.Content `
                                                        -WindowsVersion $WindowsVersion
            foreach ($result in $win10Results) {
                $allResults.Add($result)
            }
        }
    }

    # --- Fetch Windows 11 updates if requested ---
    if (11 -in $versionsToQuery) {
        Write-Verbose "Fetching Windows 11 update history"
        $win11Response = Invoke-ModuleWebRequest -Uri $script:Win11UpdateHistoryUrl -ErrorAction SilentlyContinue
        if ($win11Response) {
            Write-Verbose "Windows 11 page landed on: $($win11Response.BaseResponse.RequestMessage.RequestUri.AbsoluteUri)"
            Write-Verbose "Windows 11 page size: $($win11Response.Content.Length) bytes"
            $win11Results = ConvertTo-Win11UpdateEntries -Html $win11Response.Content `
                                                        -WindowsVersion $WindowsVersion
            foreach ($result in $win11Results) {
                $allResults.Add($result)
            }

            # --- Fetch and merge Windows 11 hotpatch entries ---
            Write-Verbose "Fetching Windows 11 hotpatch history"
            $hotpatchResponse = Invoke-ModuleWebRequest -Uri $script:Win11HotpatchHistoryUrl -ErrorAction SilentlyContinue
            if ($hotpatchResponse) {
                Write-Verbose "Hotpatch page size: $($hotpatchResponse.Content.Length) bytes"
                $hotpatchResults = ConvertTo-Win11HotpatchEntries -Html $hotpatchResponse.Content `
                                                                  -WindowsVersion $WindowsVersion
                foreach ($result in $hotpatchResults) {
                    $allResults.Add($result)
                }
                Write-Verbose "Hotpatch entries found: $($hotpatchResults.Count)"
            }
        }
    }

    if ($allResults.Count -eq 0) {
        Write-Warning 'No update entries were found. The page structure may have changed.'
    }
    else {
        Write-Verbose "Returning $($allResults.Count) update entries"
    }

    return $allResults
}
