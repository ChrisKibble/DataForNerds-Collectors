function ConvertTo-WindowsReleaseHistoryEntries {
    <#
    .SYNOPSIS
        Parses a Windows client release information page and returns version-to-base-build entries.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Html,

        [Parameter(Mandatory)]
        [ValidateScript({ $_ -in @(10, 11) })]
        [int]$MajorVersion
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Each version section on the page is introduced by a heading of the form:
    #   "Version 22H2 (OS build 19045)"           - modern XXHY naming
    #   "Version 1909 (OS build 18363)"           - older year-based naming (Win10)
    #   "Version 1507 (RTM) (OS build 10240)"     - original release, parenthesized RTM marker (Win10)
    # An optional parenthesized annotation (e.g. "(RTM)") may appear between the version
    # and the "(OS build ...)" segment; it is skipped over without altering the captured version.
    $pattern = '(?i)Version\s+(?<version>\d{4}|\d{2}H\d)(?:\s+\([^)]+\))?\s*\(OS\s+build\s+(?<build>\d{5})'

    $seen = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($match in [regex]::Matches($Html, $pattern)) {
        $version = $match.Groups['version'].Value

        if (-not $seen.Add($version)) { continue }

        $build = $match.Groups['build'].Value

        $results.Add([PSCustomObject]@{
            OSType         = 'Client'
            MajorVersion   = $MajorVersion
            WindowsVersion = $version
            OSBuild        = $build
            FullVersion    = "$MajorVersion.0.$build"
        })
    }

    return $results
}
