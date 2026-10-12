function ConvertTo-WinServerUpdateEntries {
    <#
    .SYNOPSIS
        Parses Windows Server update entries from the server update history page.

    .DESCRIPTION
        Thin wrapper over ConvertTo-WindowsUpdateEntriesCore. Handles all server
        versions on the page (Windows Server 2022, Windows Server version 23H2,
        Windows Server 2025): OSType is 'Server' and MajorVersion derives from the
        product year. The Annual Channel release "Windows Server, version 23H2" is
        treated as MajorVersion 2022.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Html,

        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter()]
        [string]$WindowsVersion
    )

    $sectionResolver = {
        param($text)
        # "Windows Server, version 23H2" — Annual Channel (Server 2022)
        $m = [regex]::Match($text, '(?i)Windows\s+Server,\s+version\s+(\w+)')
        if ($m.Success) {
            return @{ Version = $m.Groups[1].Value.ToUpper(); MajorVersion = 2022 }
        }
        # "Windows Server 2022" or "Windows Server 2025"
        $m = [regex]::Match($text, '(?i)Windows\s+Server\s+(\d{4})\b')
        if ($m.Success) {
            return @{ Version = $m.Groups[1].Value; MajorVersion = [int]$m.Groups[1].Value }
        }
        return $null
    }

    return ConvertTo-WindowsUpdateEntriesCore -Html $Html -BaseUri $BaseUri `
        -SectionResolver $sectionResolver -OSType 'Server' `
        -WindowsVersion $WindowsVersion -Label 'WinServer'
}
