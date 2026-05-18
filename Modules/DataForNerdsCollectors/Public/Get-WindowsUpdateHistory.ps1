function Get-WindowsUpdateHistory {
    <#
    .SYNOPSIS
        Returns Windows 10 and Windows 11 update entries from Microsoft's update history pages.

    .DESCRIPTION
        Fetches the Windows 10 and Windows 11 update history pages and parses the left-side
        navigation menus. Returns structured objects for each update with:

            MajorVersion   - 10 or 11
            WindowsVersion - e.g. '22H2' (Win10), '24H2' (Win11), 'RTM' (Win10 initial)
            KBNumber       - e.g. 'KB5089544'
            OSBuild        - OS build string, e.g. '19045.7291' or '26100.8457'
            FullVersion    - Full Windows version in {Major}.0.{Build}.{UBR} format
            ReleaseDate    - e.g. 'May 12, 2026'
            ReleaseType    - 'Standard', 'Preview', 'Out-of-band', 'Hotpatch', or 'Hotpatch-OOB'
            ArticleUrl     - Full URL of the KB article on support.microsoft.com

        When a KB targets multiple simultaneous OS builds, one object is returned per build.

    .PARAMETER MajorVersion
        Filters results to a specific Windows major version (10, 11, or both).
        Accepts an array; default is @(10, 11) (both versions).

    .PARAMETER WindowsVersion
        Filters results to a single version label, e.g. '22H2' (Win10) or '24H2' (Win11).
        When omitted, updates for all discovered versions are returned.

    .PARAMETER IncludePreview
        When specified, Preview and Out-of-band releases are included in results.
        By default only standard (Patch Tuesday) releases are returned.

    .PARAMETER IncludeHotpatch
        When specified, hotpatch releases (Windows 11 only) are fetched from the Windows 11
        Hotpatch release notes page and merged into the output. Standard hotpatches are always
        included; out-of-band hotpatches additionally require -IncludePreview.
        Has no effect when -MajorVersion is limited to 10 only.

    .EXAMPLE
        Get-WindowsUpdateHistory | ConvertTo-Json -Depth 3

        Returns all current standard updates (both Win10 and Win11) as a JSON array.

    .EXAMPLE
        Get-WindowsUpdateHistory -MajorVersion 11 -WindowsVersion '24H2' | ConvertTo-Json -Depth 3

        Returns only Windows 11 24H2 standard updates as JSON.

    .EXAMPLE
        Get-WindowsUpdateHistory -IncludePreview | Where-Object ReleaseType -eq 'Preview'

        Returns only Preview releases across all versions.

    .EXAMPLE
        Get-WindowsUpdateHistory -MajorVersion 11 -IncludeHotpatch | ConvertTo-Json -Depth 3

        Returns standard cumulative updates and hotpatches for Windows 11.

    .OUTPUTS
        PSCustomObject[]
        Each object has: MajorVersion (Int), WindowsVersion (String), KBNumber (String),
        OSBuild (String), FullVersion (String), ReleaseDate (String), ReleaseType (String),
        ArticleUrl (String).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(HelpMessage = "Filter to specific Windows major version(s): 10, 11, or both (default: both)")]
        [ValidateScript({ $_ -in @(10, 11) }, ErrorMessage = "MajorVersion must be 10 or 11")]
        [int[]]$MajorVersion,

        [Parameter(HelpMessage = "Filter to a specific version label, e.g. '22H2' (Win10) or '24H2' (Win11)")]
        [string]$WindowsVersion,

        [Parameter(HelpMessage = 'Include Preview and Out-of-band releases (excluded by default)')]
        [switch]$IncludePreview,

        [Parameter(HelpMessage = 'Include hotpatch releases from the Windows 11 Hotpatch release notes page')]
        [switch]$IncludeHotpatch
    )

    $versionsToQuery = if ($MajorVersion) { $MajorVersion | Select-Object -Unique } else { @(10, 11) }
    $allResults      = [System.Collections.Generic.List[PSCustomObject]]::new()

    # --- Fetch Windows 10 updates if requested ---
    if (10 -in $versionsToQuery) {
        Write-Verbose "Fetching Windows 10 update history"
        $win10Response = Invoke-UpdateHistoryPage -Uri $script:Win10UpdateHistoryUrl -ErrorAction SilentlyContinue
        if ($win10Response) {
            Write-Verbose "Windows 10 page size: $($win10Response.Content.Length) bytes"
            $win10Results = ConvertTo-Win10UpdateEntries -Html $win10Response.Content `
                                                        -WindowsVersion $WindowsVersion `
                                                        -IncludePreview:$IncludePreview
            foreach ($result in $win10Results) {
                $allResults.Add($result)
            }
        }
    }

    # --- Fetch Windows 11 updates if requested ---
    if (11 -in $versionsToQuery) {
        Write-Verbose "Fetching Windows 11 update history"
        $win11Response = Invoke-UpdateHistoryPage -Uri $script:Win11UpdateHistoryUrl -ErrorAction SilentlyContinue
        if ($win11Response) {
            Write-Verbose "Windows 11 page landed on: $($win11Response.BaseResponse.RequestMessage.RequestUri.AbsoluteUri)"
            Write-Verbose "Windows 11 page size: $($win11Response.Content.Length) bytes"
            $win11Results = ConvertTo-Win11UpdateEntries -Html $win11Response.Content `
                                                        -WindowsVersion $WindowsVersion `
                                                        -IncludePreview:$IncludePreview
            foreach ($result in $win11Results) {
                $allResults.Add($result)
            }

            # --- Optionally fetch and merge Windows 11 hotpatch entries ---
            if ($IncludeHotpatch) {
                Write-Verbose "Fetching Windows 11 hotpatch history"
                $hotpatchResponse = Invoke-UpdateHistoryPage -Uri $script:Win11HotpatchHistoryUrl -ErrorAction SilentlyContinue
                if ($hotpatchResponse) {
                    Write-Verbose "Hotpatch page size: $($hotpatchResponse.Content.Length) bytes"
                    $hotpatchResults = ConvertTo-Win11HotpatchEntries -Html $hotpatchResponse.Content `
                                                                      -WindowsVersion $WindowsVersion `
                                                                      -IncludePreview:$IncludePreview
                    foreach ($result in $hotpatchResults) {
                        $allResults.Add($result)
                    }
                    Write-Verbose "Hotpatch entries found: $($hotpatchResults.Count)"
                }
            }
        }
    }

    # --- Warn if -IncludeHotpatch was used but only Win10 was queried ---
    if (10 -notin $versionsToQuery -and $IncludeHotpatch) {
        Write-Verbose '-IncludeHotpatch is only applicable to Windows 11 results; no hotpatch data exists for Windows 10.'
    }

    if ($allResults.Count -eq 0) {
        Write-Warning 'No update entries were found. The page structure may have changed.'
    }
    else {
        Write-Verbose "Returning $($allResults.Count) update entries"
    }

    return $allResults
}
