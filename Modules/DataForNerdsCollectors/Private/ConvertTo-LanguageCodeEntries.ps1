function ConvertTo-LanguageCodeEntries {
    <#
    .SYNOPSIS
        Parses the language codes HTML table and returns structured objects.

    .DESCRIPTION
        Scoped to the language-codes table itself (located by its header cells) rather
        than tag-stripping the whole page — digits-only text anywhere else on the page
        (nav, footer, revision numbers) must never fabricate records.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Html
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Find the table whose header row carries the expected columns.
    $tableHtml = $null
    foreach ($table in [regex]::Matches($Html, '(?s)<table[^>]*>.*?</table>')) {
        if ($table.Value -match '(?s)Language\s+Code' -and $table.Value -match '(?s)BCP\s*47') {
            $tableHtml = $table.Value
            break
        }
    }
    if (-not $tableHtml) {
        Write-Warning 'Could not locate the language-codes table; page structure may have changed.'
        return $results
    }

    foreach ($row in [regex]::Matches($tableHtml, '(?s)<tr[^>]*>(.*?)</tr>')) {
        $cells = @([regex]::Matches($row.Groups[1].Value, '(?s)<t[dh][^>]*>(.*?)</t[dh]>') | ForEach-Object {
            ($_.Groups[1].Value -replace '(?s)<[^>]*>', '').Trim()
        })
        if ($cells.Count -lt 3) { continue }

        $langCode = $cells[0]
        # Digits-only filter also skips the header row and the 'Any other value' row.
        if ($langCode -notmatch '^\d+$') { continue }

        $results.Add([PSCustomObject]@{
            LanguageCode = $langCode
            Description  = $cells[1]
            BCP47        = $cells[2]
        })
    }

    return $results
}
