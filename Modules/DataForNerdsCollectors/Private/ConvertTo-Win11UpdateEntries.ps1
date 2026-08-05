function ConvertTo-Win11UpdateEntries {
    <#
    .SYNOPSIS
        Parses Windows 11 update entries from the page HTML.

    .DESCRIPTION
        Walks the learnRenderLeftNavLink anchors and produces update objects. Handles version
        filtering and 1-2 simultaneous OS builds per entry.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Html,

        [Parameter()]
        [string]$WindowsVersion,

        [Parameter()]
        [hashtable]$VersionBuildMap
    )

    $results        = [System.Collections.Generic.List[PSCustomObject]]::new()
    $currentVersion = $null
    $seen           = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $anchorPattern       = '<a\s([^>]*class="learnRenderLeftNavLink"[^>]*)>([^<]+)</a>'
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

    Write-Verbose "Found $($anchors.Count) learnRenderLeftNavLink anchors (Win11)"

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

        $rawRelType = if ($entryMatch.Groups['reltype'].Success) { $entryMatch.Groups['reltype'].Value.Trim() } else { '' }
        $releaseType = switch -Wildcard ($rawRelType.ToLower()) {
            'preview'      { 'Preview' }
            'out-of-band'  { 'Out-of-band' }
            default        { 'Standard' }
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

        # Filter to only the build belonging to this version section
        if ($VersionBuildMap -and $VersionBuildMap.ContainsKey($currentVersion)) {
            $expectedBase = $VersionBuildMap[$currentVersion]
            $matched = [System.Collections.Generic.List[string]]::new()
            foreach ($b in $osBuilds) {
                if (($b -split '\.')[0] -eq $expectedBase) {
                    $matched.Add($b)
                }
                else {
                    Write-Verbose "Filtered build $b from $($entryMatch.Groups['kb'].Value) in section $currentVersion (expected base $expectedBase)"
                }
            }
            if ($matched.Count -gt 0) {
                $osBuilds = $matched
            }
            else {
                Write-Verbose "No builds in $($entryMatch.Groups['kb'].Value) matched base $expectedBase for $currentVersion; keeping all builds"
            }
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
                FullVersion    = "10.0.$build"
                ReleaseDate    = $releaseDate
                ReleaseType    = $releaseType
                IsExpired      = $isExpired
                ArticleUrl     = $articleUrl
            })
        }
    }

    return $results
}
