function ConvertTo-Microsoft365AppsUpdateEntries {
    <#
    .SYNOPSIS
        Parses the Microsoft 365 Apps "update history by date" HTML table.

    .DESCRIPTION
        Locates the Version History table, reads column headers to map each channel
        column dynamically, then walks each body row. Cells may hold multiple
        "Version NNNN (Build NNNNN.NNNNN)" entries concatenated together; each is
        emitted as its own record. The Year and Release Date columns are combined
        into an ISO yyyy-MM-dd ReleaseDate.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Html
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Find the Version History table.
    $tableMatch = [regex]::Match(
        $Html,
        '(?s)<h2[^>]*id="version-history"[^>]*>.*?(<table[^>]*>.*?</table>)'
    )
    if (-not $tableMatch.Success) {
        Write-Warning 'Could not locate the Version History table; page structure may have changed.'
        return $results
    }
    $tableHtml = $tableMatch.Groups[1].Value

    # Extract column headers in order so channel column positions are not hard-coded.
    $headers = @()
    $headerRowMatch = [regex]::Match($tableHtml, '(?s)<thead.*?</thead>')
    if ($headerRowMatch.Success) {
        $headers = [regex]::Matches($headerRowMatch.Value, '(?s)<th[^>]*>(.*?)</th>') |
            ForEach-Object {
                ($_.Groups[1].Value -replace '<[^>]+>', '' -replace '&amp;', '&').Trim()
            }
    }

    if ($headers.Count -lt 3) {
        Write-Warning 'Version History table has unexpected header structure.'
        return $results
    }

    $yearIdx = [array]::IndexOf($headers, 'Year')
    $dateIdx = [array]::IndexOf($headers, 'Release Date')
    if ($yearIdx -lt 0 -or $dateIdx -lt 0) {
        Write-Warning "Expected 'Year' and 'Release Date' columns; found: $($headers -join ', ')"
        return $results
    }

    # Every header that isn't Year/Release Date is a channel column.
    $channelIdxs = [ordered]@{}
    for ($i = 0; $i -lt $headers.Count; $i++) {
        if ($i -ne $yearIdx -and $i -ne $dateIdx) {
            $channelIdxs[$headers[$i]] = $i
        }
    }

    Write-Verbose "Channels detected: $($channelIdxs.Keys -join ' | ')"

    $bodyMatch = [regex]::Match($tableHtml, '(?s)<tbody.*?</tbody>')
    $bodyHtml  = if ($bodyMatch.Success) { $bodyMatch.Value } else { $tableHtml }
    $rows      = [regex]::Matches($bodyHtml, '(?s)<tr[^>]*>(.*?)</tr>')

    Write-Verbose "Parsing $($rows.Count) body rows"

    $lastYear = ''
    foreach ($row in $rows) {
        $cells = [regex]::Matches($row.Groups[1].Value, '(?s)<td[^>]*>(.*?)</td>')
        if ($cells.Count -lt $headers.Count) { continue }

        $year     = ($cells[$yearIdx].Groups[1].Value -replace '<[^>]+>', '').Trim()
        $monthDay = ($cells[$dateIdx].Groups[1].Value -replace '<[^>]+>', '').Trim()
        if ($year) { $lastYear = $year } else { $year = $lastYear }
        if (-not $year -or -not $monthDay) { continue }

        $releaseDate = [datetime]::MinValue
        if (-not [datetime]::TryParse(
                "$monthDay $year",
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::None,
                [ref]$releaseDate)) {
            Write-Verbose "Skipping row with unparseable date: '$monthDay $year'"
            continue
        }
        $isoDate = $releaseDate.ToString('yyyy-MM-dd')

        foreach ($channelName in $channelIdxs.Keys) {
            $cellText  = $cells[$channelIdxs[$channelName]].Groups[1].Value -replace '<[^>]+>', ''
            $vbMatches = [regex]::Matches($cellText, 'Version\s+(\d+)\s+\(Build\s+([\d.]+)\)')
            foreach ($m in $vbMatches) {
                $build = $m.Groups[2].Value
                $results.Add([PSCustomObject]@{
                    ReleaseDate = $isoDate
                    ChannelName = $channelName
                    Version     = $m.Groups[1].Value
                    Build       = $build
                    FullBuild   = "16.0.$build"
                })
            }
        }
    }

    return $results
}
