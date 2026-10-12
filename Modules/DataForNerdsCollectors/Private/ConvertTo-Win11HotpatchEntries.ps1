function ConvertTo-Win11HotpatchEntries {
    <#
    .SYNOPSIS
        Parses Windows 11 hotpatch entries from the hotpatch release notes page.

    .DESCRIPTION
        Thin wrapper over ConvertTo-WindowsUpdateEntriesCore. Skips non-Windows-11
        sections (e.g. Windows Server) by clearing the section context, requires the
        "Hotpatch " prefix before the KB, and maps the trailing release-type word to
        Hotpatch / Hotpatch-OOB.
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
        if (-not [regex]::IsMatch($text, '(?i)Hotpatch on Windows')) {
            return $null
        }
        $m = [regex]::Match($text, '(?i)Hotpatch on Windows\s+11\s+Enterprise[,\s]+version\s+(\w+)')
        if ($m.Success) {
            return @{ Version = $m.Groups[1].Value.ToUpper(); MajorVersion = 11 }
        }
        # Windows Server or other non-Windows-11 hotpatch section: clear context
        return @{ Version = $null; MajorVersion = $null }
    }

    return ConvertTo-WindowsUpdateEntriesCore -Html $Html -BaseUri $BaseUri `
        -SectionResolver $sectionResolver -OSType 'Client' `
        -EntryPrefixPattern 'Hotpatch\s+' `
        -ReleaseTypeAlternatives @('Out-of-band') `
        -DefaultReleaseType 'Hotpatch' `
        -ReleaseTypeMap @{ 'out-of-band' = 'Hotpatch-OOB' } `
        -WindowsVersion $WindowsVersion -VersionBuildMap $VersionBuildMap -Label 'Win11 hotpatch'
}
