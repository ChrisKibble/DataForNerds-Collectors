function Get-LanguageCodes {
    <#
    .SYNOPSIS
        Returns Office language locale IDs and their corresponding BCP 47 codes.

    .DESCRIPTION
        Fetches the Microsoft Office language codes table from the MS-OE376 specification
        and parses the Language Code, Description, and BCP 47 Code values. Returns structured
        objects for each language with:

            LanguageCode - LCID (Locale ID) e.g. '1025' (Arabic - Saudi Arabia)
            Description  - Human-readable language and region e.g. 'Arabic - Saudi Arabia'
            BCP47        - BCP 47 language tag e.g. 'ar-SA'

        All entries from the specification table are included.

    .EXAMPLE
        Get-LanguageCodes | ConvertTo-Json -Depth 3

        Returns all language codes as a JSON array.

    .EXAMPLE
        Get-LanguageCodes | Where-Object { $_.BCP47 -like 'en-*' }

        Returns all English language variants (all en-* BCP 47 codes).

    .EXAMPLE
        Get-LanguageCodes | Where-Object { $_.LanguageCode -eq '1033' }

        Returns the entry for US English (LanguageCode 1033).

    .OUTPUTS
        PSCustomObject[]
        Each object has: LanguageCode (String), Description (String), BCP47 (String).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param ()

    Write-Verbose "Fetching language codes from Microsoft Learn"
    $response = Invoke-UpdateHistoryPage -Uri $script:LanguageCodesUrl -ErrorAction SilentlyContinue

    if (-not $response) {
        Write-Warning 'Failed to fetch language codes page.'
        return @()
    }

    Write-Verbose "Page size: $($response.Content.Length) bytes"
    $languageCodes = ConvertTo-LanguageCodeEntries -Html $response.Content

    if ($languageCodes.Count -eq 0) {
        Write-Warning 'No language code entries were found. The page structure may have changed.'
    }
    else {
        Write-Verbose "Returning $($languageCodes.Count) language code entries"
    }

    return $languageCodes
}
