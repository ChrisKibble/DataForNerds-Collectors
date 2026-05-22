function ConvertTo-Win10UpdateEntries {
    <#
    .SYNOPSIS
        Parses Windows 10 update entries from the page HTML.

    .DESCRIPTION
        Walks the supLeftNavLink anchors and produces update objects. Handles the RTM
        initial-version header (which uses &#xA0; entities), normalizes KB numbers with
        embedded spaces, and parses 1-3 simultaneous OS builds per entry.
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
    $initialVersionPattern = '(?i)Windows[\s &#;xA0]+10[\s &#;xA0]+\(initial\s+version'
    $versionHeaderPattern  = '(?i)Windows\s+10,\s+version\s+(\w+)'

    $updateEntryPattern = (
        '(?i)' +
        '(?<date>(?:January|February|March|April|May|June|July|August|September|October|November|December)' +
        '\s+\d{1,2},\s+\d{4})' +
        '\s*(?:&#x2014;|&#8212;|&mdash;|[—–\-])+\s*' +
        '(?<kb>KB\s*\d+)' +
        '(?:\s*:[^(]*)?' +
        '\s*\(OS Builds?\s*' +
        '(?<allbuilds>[^)]+)' +
        '\)' +
        '(?:\s*(?<reltype>Preview|Out-of-band))?'
    )

    Write-Verbose "Found $($anchors.Count) supLeftNavLink anchors (Win10)"

    foreach ($anchor in $anchors) {
        $attrs      = $anchor.Groups[1].Value
        $text       = $anchor.Groups[2].Value.Trim()
        $articleUrl = Resolve-ArticleUrl -TagAttributes $attrs

        # --- Detect initial-version (RTM) header first ---
        if ([regex]::IsMatch($text, $initialVersionPattern)) {
            $currentVersion = 'RTM'
            Write-Verbose "Version section (Win10): RTM (initial version)"
            continue
        }

        # --- Detect numbered-version section header ---
        $versionMatch = [regex]::Match($text, $versionHeaderPattern)
        if ($versionMatch.Success) {
            $currentVersion = $versionMatch.Groups[1].Value.ToUpper()
            Write-Verbose "Version section (Win10): $currentVersion"
            continue
        }

        # --- Try to parse as an update entry ---
        $entryMatch = [regex]::Match($text, $updateEntryPattern)
        if (-not $entryMatch.Success) { continue }
        if ($null -eq $currentVersion)  { continue }

        # Apply version filter
        if ($WindowsVersion -and $currentVersion -ne $WindowsVersion.ToUpper()) { continue }

        $releaseType = if ($entryMatch.Groups['reltype'].Success -and $entryMatch.Groups['reltype'].Value.Trim()) {
            $entryMatch.Groups['reltype'].Value.Trim()
        }
        else {
            'Standard'
        }

        # Normalize KB number: remove any space between "KB" and the digits
        $kbNumber = $entryMatch.Groups['kb'].Value -replace '\s+', ''

        # Deduplicate
        $dedupeKey = "$currentVersion|$kbNumber"
        if (-not $seen.Add($dedupeKey)) { continue }

        # Parse individual build numbers
        $buildStr = $entryMatch.Groups['allbuilds'].Value
        $osBuilds = ($buildStr -split '(?:,\s*(?:and\s+)?|\s+and\s+)') |
                    ForEach-Object { $_.Trim() } |
                    Where-Object   { $_ -match '^\d' }

        foreach ($build in $osBuilds) {
            $results.Add([PSCustomObject]@{
                OSType         = 'Client'
                MajorVersion   = 10
                WindowsVersion = $currentVersion
                KBNumber       = $kbNumber
                OSBuild        = $build
                FullVersion    = "10.0.$build"
                ReleaseDate    = $entryMatch.Groups['date'].Value.Trim()
                ReleaseType    = $releaseType
                ArticleUrl     = $articleUrl
            })
        }
    }

    return $results
}
