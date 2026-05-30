function ConvertTo-ChassisTypeEntries {
    <#
    .SYNOPSIS
        Parses the ChassisTypes enumeration from the Win32_SystemEnclosure page and returns structured objects.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Html
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    # The page documents several uint16 value tables (ChassisTypes, SecurityBreach,
    # SecurityStatus, ServiceDescriptions), all using the same "<strong>Name</strong> (N)"
    # markup. Scope to the ChassisTypes enumeration only:
    #   start - the description text that immediately follows the ChassisTypes property header
    #   end   - the next property's "Data type:" marker (the following property, CreationClassName)
    $start = $Html.IndexOf('Array of chassis types')
    if ($start -lt 0) { return $results }

    $end = $Html.IndexOf('Data type:', $start)
    if ($end -lt 0) { return $results }

    $section = $Html.Substring($start, $end - $start)

    $seen = [System.Collections.Generic.HashSet[int]]::new()

    foreach ($match in [regex]::Matches($section, '<strong>([^<]+)</strong>\s*\((\d+)\)')) {
        $id = [int]$match.Groups[2].Value

        if (-not $seen.Add($id)) { continue }

        $results.Add([PSCustomObject]@{
            ID   = $id
            Type = $match.Groups[1].Value.Trim()
        })
    }

    return $results
}
