function Get-WindowsUpdateHistory {
    <#
    .SYNOPSIS
        Returns Windows 10, Windows 11, and Windows Server update entries from Microsoft's update history pages.

    .DESCRIPTION
        Fetches the Windows 10, Windows 11, and Windows Server update history pages and parses
        the left-side navigation menus. Returns every discovered update — Standard, Preview,
        Out-of-band, Hotpatch, and Hotpatch-OOB — with the following fields:

            OSType         - 'Client' or 'Server'
            MajorVersion   - 10, 11, 2022, or 2025
            WindowsVersion - e.g. '22H2' (Win10), '24H2' (Win11), '2022' (Server 2022), '23H2' (Server 23H2)
            KBNumber       - e.g. 'KB5089544'
            OSBuild        - OS build string, e.g. '19045.7291' or '20348.5139'
            FullVersion    - Full Windows version in 10.0.{Build} format
            ReleaseDate    - ISO 8601 date, e.g. '2026-05-12'
            ReleaseType    - 'Standard', 'Preview', 'Out-of-band', 'Hotpatch', or 'Hotpatch-OOB'
            IsExpired      - $true if Microsoft marked the update as EXPIRED
            ArticleUrl     - Full URL of the KB article on support.microsoft.com

        When a KB targets multiple simultaneous OS builds, one object is returned per build.

    .PARAMETER MajorVersion
        Filters results to specific Windows major version(s).
        Client versions: 10, 11. Server versions: 2022, 2025.
        Accepts an array; default is all versions.

    .PARAMETER WindowsVersion
        Filters results to a single version label, e.g. '22H2' (Win10) or '24H2' (Win11).
        When omitted, updates for all discovered versions are returned.

    .EXAMPLE
        Get-WindowsUpdateHistory | ConvertTo-Json -Depth 3

        Returns every update (all client and server versions) as JSON.

    .EXAMPLE
        Get-WindowsUpdateHistory -MajorVersion 11 -WindowsVersion '24H2' | ConvertTo-Json -Depth 3

        Returns all Windows 11 24H2 updates as JSON.

    .EXAMPLE
        Get-WindowsUpdateHistory -MajorVersion 2022

        Returns all Windows Server 2022 updates.

    .OUTPUTS
        PSCustomObject[]
        Each object has: OSType (String), MajorVersion (Int), WindowsVersion (String),
        KBNumber (String), OSBuild (String), FullVersion (String), ReleaseDate (String),
        ReleaseType (String), IsExpired (Boolean), ArticleUrl (String).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(HelpMessage = "Filter to specific major version(s): 10, 11 (client) or 2022, 2025 (server)")]
        [ValidateScript({ $_ -in @(10, 11, 2022, 2025) }, ErrorMessage = "MajorVersion must be 10, 11, 2022, or 2025")]
        [int[]]$MajorVersion,

        [Parameter(HelpMessage = "Filter to a specific version label, e.g. '22H2' (Win10) or '24H2' (Win11)")]
        [string]$WindowsVersion
    )

    $versionsToQuery = if ($MajorVersion) { $MajorVersion | Select-Object -Unique } else { @(10, 11, 2022, 2025) }
    $allResults      = [System.Collections.Generic.List[PSCustomObject]]::new()

    # --- Build version-to-base-build maps for filtering cross-version builds ---
    $win10BuildMap = @{}
    $win11BuildMap = @{}

    if (10 -in $versionsToQuery) {
        Write-Verbose "Fetching Windows 10 release information for version-to-build mapping"
        $win10ReleaseResponse = Invoke-ModuleWebRequest -Uri $script:Windows10ReleaseHistoryUrl -ErrorAction SilentlyContinue
        if ($win10ReleaseResponse) {
            $win10Releases = ConvertTo-WindowsReleaseHistoryEntries -Html $win10ReleaseResponse.Content -MajorVersion 10
            foreach ($r in $win10Releases) {
                $win10BuildMap[$r.WindowsVersion.ToUpper()] = $r.OSBuild
            }
            if ($win10BuildMap.ContainsKey('1507') -and -not $win10BuildMap.ContainsKey('RTM')) {
                $win10BuildMap['RTM'] = $win10BuildMap['1507']
            }
            Write-Verbose "Win10 build map: $($win10BuildMap.Count) version(s)"
        }
        else {
            Write-Warning 'Could not fetch Windows 10 release info; build filtering disabled for Win10'
        }
    }

    if (11 -in $versionsToQuery) {
        Write-Verbose "Fetching Windows 11 release information for version-to-build mapping"
        $win11ReleaseResponse = Invoke-ModuleWebRequest -Uri $script:Windows11ReleaseHistoryUrl -ErrorAction SilentlyContinue
        if ($win11ReleaseResponse) {
            $win11Releases = ConvertTo-WindowsReleaseHistoryEntries -Html $win11ReleaseResponse.Content -MajorVersion 11
            foreach ($r in $win11Releases) {
                $win11BuildMap[$r.WindowsVersion.ToUpper()] = $r.OSBuild
            }
            Write-Verbose "Win11 build map: $($win11BuildMap.Count) version(s)"
        }
        else {
            Write-Warning 'Could not fetch Windows 11 release info; build filtering disabled for Win11'
        }
    }

    # --- Fetch Windows 10 updates if requested ---
    if (10 -in $versionsToQuery) {
        Write-Verbose "Fetching Windows 10 update history"
        $win10Response = Invoke-ModuleWebRequest -Uri $script:Win10UpdateHistoryUrl -ErrorAction SilentlyContinue
        if ($win10Response) {
            Write-Verbose "Windows 10 page size: $($win10Response.Content.Length) bytes"
            $win10Results = ConvertTo-Win10UpdateEntries -Html $win10Response.Content `
                                                        -WindowsVersion $WindowsVersion `
                                                        -VersionBuildMap $win10BuildMap
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
                                                        -WindowsVersion $WindowsVersion `
                                                        -VersionBuildMap $win11BuildMap
            foreach ($result in $win11Results) {
                $allResults.Add($result)
            }

            # --- Fetch and merge Windows 11 hotpatch entries ---
            Write-Verbose "Fetching Windows 11 hotpatch history"
            $hotpatchResponse = Invoke-ModuleWebRequest -Uri $script:Win11HotpatchHistoryUrl -ErrorAction SilentlyContinue
            if ($hotpatchResponse) {
                Write-Verbose "Hotpatch page size: $($hotpatchResponse.Content.Length) bytes"
                $hotpatchResults = ConvertTo-Win11HotpatchEntries -Html $hotpatchResponse.Content `
                                                                  -WindowsVersion $WindowsVersion `
                                                                  -VersionBuildMap $win11BuildMap
                foreach ($result in $hotpatchResults) {
                    $allResults.Add($result)
                }
                Write-Verbose "Hotpatch entries found: $($hotpatchResults.Count)"
            }
        }
    }

    # --- Fetch Windows Server updates if requested (2022 and/or 2025 share one page) ---
    $serverVersionsRequested = $versionsToQuery | Where-Object { $_ -in @(2022, 2025) }
    if ($serverVersionsRequested) {
        Write-Verbose "Fetching Windows Server update history"
        $serverResponse = Invoke-ModuleWebRequest -Uri $script:WinServerUpdateHistoryUrl -ErrorAction SilentlyContinue
        if ($serverResponse) {
            Write-Verbose "Windows Server page size: $($serverResponse.Content.Length) bytes"
            $serverResults = ConvertTo-WinServerUpdateEntries -Html $serverResponse.Content `
                                                              -WindowsVersion $WindowsVersion
            foreach ($result in $serverResults) {
                if ($result.MajorVersion -in $serverVersionsRequested) {
                    $allResults.Add($result)
                }
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
