function ConvertTo-Win11UpdateEntries {
    <#
    .SYNOPSIS
        Parses Windows 11 update entries from the page HTML.

    .DESCRIPTION
        Walks the supLeftNavLink anchors and produces update objects. Handles version
        filtering and 1-2 simultaneous OS builds per entry.
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
    $seen           = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $anchorPattern       = '<a\s([^>]*class="supLeftNavLink"[^>]*)>([^<]+)</a>'
    $anchors             = [regex]::Matches($Html, $anchorPattern)
    $versionHeaderPattern = '(?i)Windows\s+11[,\s]+version\s+(\w+)'

    $updateEntryPattern = (
        '(?i)' +
        '(?<date>(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4})' +
        '\s*(?:&#x2014;|&#8212;|&mdash;|[—–\-]+)\s*' +
        '(?<kb>KB\d+)' +
        '\s*\(OS Builds?\s*' +
        '(?<build1>[\d.]+)' +
        '(?:\s+and\s+(?<build2>[\d.]+))?' +
        '\)' +
        '(?:\s*(?<reltype>Preview|Out-of-band))?' +
        '(?:\s*-?\s*(?<expired>EXPIRED))?'
    )

    Write-Verbose "Found $($anchors.Count) supLeftNavLink anchors (Win11)"

    foreach ($anchor in $anchors) {
        $attrs      = $anchor.Groups[1].Value
        $text       = $anchor.Groups[2].Value.Trim()
        $articleUrl = Resolve-ArticleUrl -TagAttributes $attrs

        # --- Check for version section header ---
        $versionMatch = [regex]::Match($text, $versionHeaderPattern)
        if ($versionMatch.Success) {
            $currentVersion = $versionMatch.Groups[1].Value.ToUpper()
            Write-Verbose "Version section (Win11): $currentVersion"
            continue
        }

        # --- Check for update entry ---
        $entryMatch = [regex]::Match($text, $updateEntryPattern)
        if (-not $entryMatch.Success) { continue }
        if ($null -eq $currentVersion)  { continue }

        # Apply version filter if requested
        if ($WindowsVersion -and $currentVersion -ne $WindowsVersion.ToUpper()) { continue }

        $releaseType = if ($entryMatch.Groups['reltype'].Success -and $entryMatch.Groups['reltype'].Value) {
            $entryMatch.Groups['reltype'].Value
        }
        else {
            'Standard'
        }

        $isExpired = $entryMatch.Groups['expired'].Success

        # Deduplicate
        $dedupeKey = "$currentVersion|$($entryMatch.Groups['kb'].Value)"
        if (-not $seen.Add($dedupeKey)) { continue }

        # Build the OS build array (one or two entries)
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
                OSType         = 'Client'
                MajorVersion   = 11
                WindowsVersion = $currentVersion
                KBNumber       = $entryMatch.Groups['kb'].Value
                OSBuild        = $build
                FullVersion    = "11.0.$build"
                ReleaseDate    = $releaseDate
                ReleaseType    = $releaseType
                IsExpired      = $isExpired
                ArticleUrl     = $articleUrl
            })
        }
    }

    return $results
}
