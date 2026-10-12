function ConvertTo-Win10UpdateEntries {
    <#
    .SYNOPSIS
        Parses Windows 10 update entries from the page HTML.

    .DESCRIPTION
        Thin wrapper over ConvertTo-WindowsUpdateEntriesCore: supplies the Windows 10
        section-header rules (including the RTM initial-version header, which uses
        &#xA0; entities).
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
        if ([regex]::IsMatch($text, '(?i)Windows[\s &#;xA0]+10[\s &#;xA0]+\(initial\s+version')) {
            return @{ Version = 'RTM'; MajorVersion = 10 }
        }
        $m = [regex]::Match($text, '(?i)Windows\s+10,\s+version\s+(\w+)')
        if ($m.Success) {
            return @{ Version = $m.Groups[1].Value.ToUpper(); MajorVersion = 10 }
        }
        return $null
    }

    return ConvertTo-WindowsUpdateEntriesCore -Html $Html -BaseUri $BaseUri `
        -SectionResolver $sectionResolver -OSType 'Client' `
        -WindowsVersion $WindowsVersion -VersionBuildMap $VersionBuildMap -Label 'Win10'
}
