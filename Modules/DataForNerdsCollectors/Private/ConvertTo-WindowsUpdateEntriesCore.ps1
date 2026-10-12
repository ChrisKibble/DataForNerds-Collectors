function ConvertTo-WindowsUpdateEntriesCore {
    <#
    .SYNOPSIS
        Shared parser core for the Windows update-history pages.

    .DESCRIPTION
        All four update-history sources (Win10, Win11, Win11 hotpatch, Windows Server)
        render the same left-nav anchor structure; only the section headers and the
        release-type vocabulary differ. Those differences come in as parameters so a
        parsing fix lands once instead of four times (the per-parser copies had already
        drifted — e.g. only Win10 tolerated "KB 5031234" with an embedded space).

    .PARAMETER SectionResolver
        Scriptblock receiving each anchor's text. Returns $null when the text is not a
        section header; otherwise a hashtable @{ Version = <string or $null to clear>;
        MajorVersion = <int or $null> } that becomes the context for following entries.

    .PARAMETER EntryPrefixPattern
        Regex fragment required between the date dash and the KB number
        (e.g. 'Hotpatch\s+' on the hotpatch page).

    .PARAMETER ReleaseTypeAlternatives
        The release-type words that may trail an entry (joined into the entry regex).

    .PARAMETER ReleaseTypeMap
        Lowercased trailing word -> emitted ReleaseType. Anything absent (including no
        trailing word) emits DefaultReleaseType.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Html,

        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter(Mandatory)]
        [scriptblock]$SectionResolver,

        [Parameter(Mandatory)]
        [ValidateSet('Client', 'Server')]
        [string]$OSType,

        [Parameter()]
        [string]$EntryPrefixPattern = '',

        [Parameter()]
        [string[]]$ReleaseTypeAlternatives = @('Preview', 'Out-of-band'),

        [Parameter()]
        [string]$DefaultReleaseType = 'Standard',

        [Parameter()]
        [hashtable]$ReleaseTypeMap = @{ 'preview' = 'Preview'; 'out-of-band' = 'Out-of-band' },

        [Parameter()]
        [string]$WindowsVersion,

        [Parameter()]
        [hashtable]$VersionBuildMap,

        [Parameter()]
        [string]$Label = 'updates'
    )

    $results        = [System.Collections.Generic.List[PSCustomObject]]::new()
    $currentVersion = $null
    $currentMajor   = $null
    $seen           = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $anchorPattern = '<a\s([^>]*class="learnRenderLeftNavLink"[^>]*)>([^<]+)</a>'
    $anchors       = [regex]::Matches($Html, $anchorPattern)

    # The KB group tolerates an embedded space ("KB 5031234" has appeared on the
    # Win10 page); it is normalized before use. The optional ":<title>" segment
    # between the KB and "(OS Builds" also appears only occasionally.
    $updateEntryPattern = (
        '(?i)' +
        '(?<date>(?:January|February|March|April|May|June|July|August|September|October|November|December)' +
        '\s+\d{1,2},\s+\d{4})' +
        '\s*(?:&#x2014;|&#8212;|&mdash;|[—–\-])+\s*' +
        $EntryPrefixPattern +
        '(?<kb>KB\s*\d+)' +
        '(?:\s*:[^(]*)?' +
        '\s*\(OS Builds?\s*' +
        '(?<allbuilds>[^)]+)' +
        '\)' +
        "(?:\s*(?<reltype>$($ReleaseTypeAlternatives -join '|')))?" +
        '(?:\s*-?\s*(?<expired>EXPIRED))?'
    )

    Write-Verbose "Found $($anchors.Count) learnRenderLeftNavLink anchors ($Label)"

    $unmappedVersionsWarned = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($anchor in $anchors) {
        $attrs = $anchor.Groups[1].Value
        $text  = $anchor.Groups[2].Value.Trim()

        # --- Section header? ---
        $section = & $SectionResolver $text
        if ($null -ne $section) {
            $currentVersion = $section.Version
            $currentMajor   = $section.MajorVersion
            if ($null -ne $currentVersion) {
                Write-Verbose "Version section ($Label): $currentVersion"
            } else {
                Write-Verbose "Out-of-scope section ($Label); skipping entries"
            }
            continue
        }

        # --- Update entry? ---
        $entryMatch = [regex]::Match($text, $updateEntryPattern)
        if (-not $entryMatch.Success) { continue }
        if ($null -eq $currentVersion)  { continue }

        # Apply version filter if requested
        if ($WindowsVersion -and $currentVersion -ne $WindowsVersion.ToUpper()) { continue }

        $rawRelType  = if ($entryMatch.Groups['reltype'].Success) { $entryMatch.Groups['reltype'].Value.Trim().ToLower() } else { '' }
        $releaseType = if ($ReleaseTypeMap.ContainsKey($rawRelType)) { $ReleaseTypeMap[$rawRelType] } else { $DefaultReleaseType }

        $isExpired = $entryMatch.Groups['expired'].Success

        # Normalize KB number: remove any space between "KB" and the digits
        $kbNumber = $entryMatch.Groups['kb'].Value -replace '\s+', ''

        # Deduplicate
        $dedupeKey = "$currentVersion|$kbNumber"
        if (-not $seen.Add($dedupeKey)) { continue }

        # Parse individual build numbers (entries can carry 1-N simultaneous builds)
        $buildStr = $entryMatch.Groups['allbuilds'].Value
        $osBuilds = ($buildStr -split '(?:,\s*(?:and\s+)?|\s+and\s+)') |
                    ForEach-Object { $_.Trim() } |
                    Where-Object   { $_ -match '^\d' }

        # Filter to only the build belonging to this version section
        if ($VersionBuildMap -and $VersionBuildMap.Count -gt 0) {
            if ($VersionBuildMap.ContainsKey($currentVersion)) {
                $expectedBase = $VersionBuildMap[$currentVersion]
                $matched = @($osBuilds | Where-Object { ($_ -split '\.')[0] -eq $expectedBase })
                if ($matched.Count -gt 0) {
                    foreach ($b in $osBuilds) {
                        if (($b -split '\.')[0] -ne $expectedBase) {
                            Write-Verbose "Filtered build $b from $kbNumber in section $currentVersion (expected base $expectedBase)"
                        }
                    }
                    $osBuilds = $matched
                }
                else {
                    Write-Warning "DFN data quality ($Label): no builds in $kbNumber matched base $expectedBase for $currentVersion; keeping all builds"
                }
            }
            elseif ($unmappedVersionsWarned.Add($currentVersion)) {
                # Likely a brand-new version label the release-information page
                # doesn't list yet — builds for it cannot be cross-filtered.
                Write-Warning "DFN data quality ($Label): version label '$currentVersion' is not in the release-information map; builds not filtered"
            }
        }

        $releaseDate = [DateTime]::ParseExact(
            $entryMatch.Groups['date'].Value.Trim(),
            'MMMM d, yyyy',
            [System.Globalization.CultureInfo]::InvariantCulture
        ).ToString('yyyy-MM-dd')

        $articleUrl = Resolve-ArticleUrl -TagAttributes $attrs -BaseUri $BaseUri

        foreach ($build in $osBuilds) {
            $results.Add([PSCustomObject]@{
                OSType         = $OSType
                MajorVersion   = $currentMajor
                WindowsVersion = $currentVersion
                KBNumber       = $kbNumber
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
