function ConvertTo-LanguageCodeEntries {
    <#
    .SYNOPSIS
        Parses the language codes HTML table and returns structured objects.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Html
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    $html = $Html -replace '(?s)<[^>]*>', ''
    $lines = $html -split "`n" | Where-Object { $_.Trim() }

    $langCode = $null
    $description = $null
    $bcp47 = $null
    $fieldIndex = 0

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if (-not $trimmed) { continue }

        if ($trimmed -eq 'Language Code' -or $trimmed -eq 'Description (informative)' -or $trimmed -eq 'BCP 47 Code') {
            continue
        }

        if ($fieldIndex -eq 0) {
            if ($trimmed -match '^\d+$' -or $trimmed -eq 'Any other value') {
                $langCode = $trimmed
                $fieldIndex = 1
            }
        }
        elseif ($fieldIndex -eq 1) {
            $description = $trimmed
            $fieldIndex = 2
        }
        elseif ($fieldIndex -eq 2) {
            $bcp47 = $trimmed
            $fieldIndex = 0

            if ($langCode -and $langCode -ne 'Any other value') {
                $entry = [PSCustomObject]@{
                    LanguageCode = $langCode
                    Description  = $description
                    BCP47        = $bcp47
                }
                $results.Add($entry)
            }

            $langCode = $null
            $description = $null
            $bcp47 = $null
        }
    }

    return $results
}
