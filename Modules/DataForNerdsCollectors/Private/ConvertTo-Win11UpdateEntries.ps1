function ConvertTo-Win11UpdateEntries {
    <#
    .SYNOPSIS
        Parses Windows 11 update entries from the page HTML.

    .DESCRIPTION
        Thin wrapper over ConvertTo-WindowsUpdateEntriesCore: supplies the Windows 11
        section-header rule.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Html,

        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter()]
        [string]$WindowsVersion,

        [Parameter()]
        [hashtable]$VersionBuildMap
    )

    $sectionResolver = {
        param($text)
        $m = [regex]::Match($text, '(?i)Windows\s+11[,\s]+version\s+(\w+)')
        if ($m.Success) {
            return @{ Version = $m.Groups[1].Value.ToUpper(); MajorVersion = 11 }
        }
        return $null
    }

    return ConvertTo-WindowsUpdateEntriesCore -Html $Html -BaseUri $BaseUri `
        -SectionResolver $sectionResolver -OSType 'Client' `
        -WindowsVersion $WindowsVersion -VersionBuildMap $VersionBuildMap -Label 'Win11'
}
