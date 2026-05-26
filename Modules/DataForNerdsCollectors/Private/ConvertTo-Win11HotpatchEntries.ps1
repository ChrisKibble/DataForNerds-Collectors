function ConvertTo-Win11HotpatchEntries {
    <#
    .SYNOPSIS
        Parses Windows 11 hotpatch entries from the hotpatch release notes page.

    .DESCRIPTION
        Skips non-Windows-11 sections (e.g., Windows Server) and baseline entries,
        returning only hotpatch KB entries.
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

    $anchorPattern          = '<a\s([^>]*class="supLeftNavLink"[^>]*)>([^<]+)</a>'
    $anchors                = [regex]::Matches($Html, $anchorPattern)
    $anySectionHeaderPattern = '(?i)Hotpatch on Windows'
    $win11HeaderPattern      = '(?i)Hotpatch on Windows\s+11\s+Enterprise[,\s]+version\s+(\w+)'

    $hotpatchEntryPattern = (
        '(?i)' +
        '(?<date>(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4})' +
        '\s*(?:&#x2014;|&#8212;|&mdash;|[—–\-]+)\s*' +
        'Hotpatch\s+' +
        '(?<kb>KB\d+)' +
        '\s*\(OS Builds?\s*' +
        '(?<build1>[\d.]+)' +
        '(?:\s+and\s+(?<build2>[\d.]+))?' +
        '\)' +
        '(?:\s*(?<reltype>Out-of-band))?' +
        '(?:\s*-?\s*(?<expired>EXPIRED))?'
    )

    Write-Verbose "Found $($anchors.Count) supLeftNavLink anchors (Win11 hotpatch)"

    foreach ($anchor in $anchors) {
        $attrs      = $anchor.Groups[1].Value
        $text       = $anchor.Groups[2].Value.Trim()
        $articleUrl = Resolve-ArticleUrl -TagAttributes $attrs

        # --- Check for any hotpatch section header (Win11 or Server) ---
        if ([regex]::IsMatch($text, $anySectionHeaderPattern)) {
            $win11Match = [regex]::Match($text, $win11HeaderPattern)
            if ($win11Match.Success) {
                $currentVersion = $win11Match.Groups[1].Value.ToUpper()
                Write-Verbose "Hotpatch version section: $currentVersion"
            }
            else {
                # Windows Server or other non-Windows-11 section
                $currentVersion = $null
                Write-Verbose "Non-Windows-11 hotpatch section encountered; skipping entries"
            }
            continue
        }

        # --- Check for hotpatch update entry ---
        $entryMatch = [regex]::Match($text, $hotpatchEntryPattern)
        if (-not $entryMatch.Success) { continue }
        if ($null -eq $currentVersion)  { continue }

        # Apply version filter if requested
        if ($WindowsVersion -and $currentVersion -ne $WindowsVersion.ToUpper()) { continue }

        $releaseType = if ($entryMatch.Groups['reltype'].Success -and $entryMatch.Groups['reltype'].Value.Trim()) {
            'Hotpatch-OOB'
        }
        else {
            'Hotpatch'
        }

        $isExpired = $entryMatch.Groups['expired'].Success

        # Deduplicate
        $dedupeKey = "$currentVersion|$($entryMatch.Groups['kb'].Value)"
        if (-not $seen.Add($dedupeKey)) { continue }

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
