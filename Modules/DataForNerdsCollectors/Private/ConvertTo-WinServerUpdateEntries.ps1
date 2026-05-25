function ConvertTo-WinServerUpdateEntries {
    <#
    .SYNOPSIS
        Parses Windows Server update entries from the server update history page.

    .DESCRIPTION
        Walks the supLeftNavLink anchors and produces update objects for all server
        versions on the page (Windows Server 2022, Windows Server version 23H2,
        Windows Server 2025). Sets OSType to 'Server' and derives MajorVersion from
        the product year (2022 or 2025). The Annual Channel release
        "Windows Server, version 23H2" is treated as MajorVersion 2022.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Html,

        [Parameter()]
        [string]$WindowsVersion
    )

    $results        = [System.Collections.Generic.List[PSCustomObject]]::new()
    $currentVersion = $null
    $currentMajor   = $null
    $seen           = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $anchorPattern = '<a\s([^>]*class="supLeftNavLink"[^>]*)>([^<]+)</a>'
    $anchors       = [regex]::Matches($Html, $anchorPattern)

    # "Windows Server, version 23H2" — Annual Channel; treated as Server 2022
    $serverVersionPattern = '(?i)Windows\s+Server,\s+version\s+(\w+)'
    # "Windows Server 2022" or "Windows Server 2025"
    $serverYearPattern    = '(?i)Windows\s+Server\s+(\d{4})\b'

    $updateEntryPattern = (
        '(?i)' +
        '(?<date>(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4})' +
        '\s*(?:&#x2014;|&#8212;|&mdash;|[—–\-]+)\s*' +
        '(?<kb>KB\d+)' +
        '\s*\(OS Builds?\s*' +
        '(?<build1>[\d.]+)' +
        '(?:\s+and\s+(?<build2>[\d.]+))?' +
        '\)' +
        '(?:\s*(?<reltype>Preview|Out-of-band))?'
    )

    Write-Verbose "Found $($anchors.Count) supLeftNavLink anchors (WinServer)"

    foreach ($anchor in $anchors) {
        $attrs      = $anchor.Groups[1].Value
        $text       = $anchor.Groups[2].Value.Trim()
        $articleUrl = Resolve-ArticleUrl -TagAttributes $attrs

        # "Windows Server, version 23H2" — Annual Channel (Server 2022)
        $versionMatch = [regex]::Match($text, $serverVersionPattern)
        if ($versionMatch.Success) {
            $currentVersion = $versionMatch.Groups[1].Value.ToUpper()
            $currentMajor   = 2022
            Write-Verbose "Server version section: $currentVersion (MajorVersion=2022)"
            continue
        }

        # "Windows Server 2022" or "Windows Server 2025"
        $yearMatch = [regex]::Match($text, $serverYearPattern)
        if ($yearMatch.Success) {
            $year           = [int]$yearMatch.Groups[1].Value
            $currentVersion = $yearMatch.Groups[1].Value
            $currentMajor   = $year
            Write-Verbose "Server year section: $currentVersion (MajorVersion=$year)"
            continue
        }

        $entryMatch = [regex]::Match($text, $updateEntryPattern)
        if (-not $entryMatch.Success) { continue }
        if ($null -eq $currentVersion)  { continue }

        if ($WindowsVersion -and $currentVersion -ne $WindowsVersion.ToUpper()) { continue }

        $releaseType = if ($entryMatch.Groups['reltype'].Success -and $entryMatch.Groups['reltype'].Value.Trim()) {
            $entryMatch.Groups['reltype'].Value.Trim()
        }
        else {
            'Standard'
        }

        $kbNumber  = $entryMatch.Groups['kb'].Value
        $dedupeKey = "$currentVersion|$kbNumber"
        if (-not $seen.Add($dedupeKey)) { continue }

        $osBuilds = [System.Collections.Generic.List[string]]::new()
        $osBuilds.Add($entryMatch.Groups['build1'].Value)
        if ($entryMatch.Groups['build2'].Success -and $entryMatch.Groups['build2'].Value.Trim()) {
            $osBuilds.Add($entryMatch.Groups['build2'].Value.Trim())
        }

        $releaseDate = [DateTime]::ParseExact(
            $entryMatch.Groups['date'].Value.Trim(),
            'MMMM d, yyyy',
            [System.Globalization.CultureInfo]::InvariantCulture
        ).ToString('yyyy-MM-dd')

        foreach ($build in $osBuilds) {
            $results.Add([PSCustomObject]@{
                OSType         = 'Server'
                MajorVersion   = $currentMajor
                WindowsVersion = $currentVersion
                KBNumber       = $kbNumber
                OSBuild        = $build
                FullVersion    = "10.0.$build"
                ReleaseDate    = $releaseDate
                ReleaseType    = $releaseType
                ArticleUrl     = $articleUrl
            })
        }
    }

    return $results
}
