#Requires -Version 7

function Get-LastModified {
    param(
        $NewData,
        [string]$CurrentFile,
        [string]$Now
    )
    if (Test-Path $CurrentFile) {
        $current     = Get-Content $CurrentFile -Raw | ConvertFrom-Json
        $newDataJson = $NewData      | ConvertTo-Json -Depth 10 -Compress
        $oldDataJson = $current.data | ConvertTo-Json -Depth 10 -Compress
        if ($newDataJson -ne $oldDataJson) { return $Now }
        $lm = $current.metadata.lastModified
        if ($lm -is [DateTime]) { return $lm.ToUniversalTime().ToString('o') }
        return [string]$lm
    }
    return $Now
}

function Compare-DataRecords {
    param(
        [array]$OldData,
        [array]$NewData,
        [string[]]$KeyFields
    )

    # Null filter: @($null) is a one-element array, which would otherwise become a
    # phantom '' key and a "removed": null changelog entry on first publish.
    $oldMap = @{}
    foreach ($record in @($OldData) | Where-Object { $null -ne $_ }) {
        $key = ($KeyFields | ForEach-Object { $record.$_ }) -join '|'
        if ($oldMap.ContainsKey($key)) {
            Write-Warning "Compare-DataRecords: duplicate key '$key' in old data; last record wins in the diff basis"
        }
        $oldMap[$key] = $record
    }

    $newMap = @{}
    foreach ($record in @($NewData) | Where-Object { $null -ne $_ }) {
        $key = ($KeyFields | ForEach-Object { $record.$_ }) -join '|'
        if ($newMap.ContainsKey($key)) {
            Write-Warning "Compare-DataRecords: duplicate key '$key' in new data; last record wins in the diff basis"
        }
        $newMap[$key] = $record
    }

    $added    = @()
    $removed  = @()
    $modified = @()

    foreach ($key in $newMap.Keys) {
        if (-not $oldMap.ContainsKey($key)) {
            $added += $newMap[$key]
        } else {
            $oldRec = $oldMap[$key]
            $newRec = $newMap[$key]
            $fieldChanges = [ordered]@{}
            foreach ($prop in $newRec.PSObject.Properties.Name) {
                if ($prop -in $KeyFields) { continue }
                if ("$($oldRec.$prop)" -ne "$($newRec.$prop)") {
                    $fieldChanges[$prop] = [PSCustomObject]@{ from = $oldRec.$prop; to = $newRec.$prop }
                }
            }
            if ($fieldChanges.Count -gt 0) {
                $keyObj = [ordered]@{}
                foreach ($kf in $KeyFields) { $keyObj[$kf] = $newRec.$kf }
                $modified += [PSCustomObject]@{
                    key    = [PSCustomObject]$keyObj
                    fields = [PSCustomObject]$fieldChanges
                }
            }
        }
    }

    foreach ($key in $oldMap.Keys) {
        if (-not $newMap.ContainsKey($key)) {
            $removed += $oldMap[$key]
        }
    }

    [PSCustomObject]@{
        added    = $added
        removed  = $removed
        modified = $modified
    }
}

function New-ChangelogEntry {
    param(
        [PSCustomObject]$Changes,
        [string]$Timestamp
    )

    $changeList = @()
    foreach ($r in @($Changes.added))    { $changeList += [PSCustomObject]@{ type = 'added';    record = $r } }
    foreach ($r in @($Changes.removed))  { $changeList += [PSCustomObject]@{ type = 'removed';  record = $r } }
    foreach ($m in @($Changes.modified)) { $changeList += [PSCustomObject]@{ type = 'modified'; key = $m.key; fields = $m.fields } }

    [PSCustomObject]@{
        timestamp = $Timestamp
        summary   = [PSCustomObject]@{
            added    = @($Changes.added).Count
            removed  = @($Changes.removed).Count
            modified = @($Changes.modified).Count
        }
        changes   = $changeList
    }
}

function Update-Changelog {
    param(
        $ExistingChangelog,
        [PSCustomObject]$NewEntry,
        [string]$Dataset
    )

    if ($null -ne $ExistingChangelog) {
        $entries = @($NewEntry) + @($ExistingChangelog.entries | Where-Object { $null -ne $_ })
    } else {
        $entries = @($NewEntry)
    }

    # Cap growth: entries are newest-first, so keep the 10 most recent
    # unconditionally plus anything newer than 90 days. Entries with an
    # unparseable timestamp are kept (safe side).
    $cutoff = [DateTime]::UtcNow.AddDays(-90)
    $kept   = [System.Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $entries.Count; $i++) {
        $keep = $i -lt 10
        if (-not $keep) {
            $tsRaw = $entries[$i].timestamp
            $ts    = $null
            if ($tsRaw -is [DateTime]) {
                $ts = $tsRaw.ToUniversalTime()
            } else {
                $parsed = [DateTime]::MinValue
                if ([DateTime]::TryParse([string]$tsRaw,
                        [System.Globalization.CultureInfo]::InvariantCulture,
                        [System.Globalization.DateTimeStyles]::RoundtripKind,
                        [ref]$parsed)) {
                    $ts = $parsed.ToUniversalTime()
                }
            }
            $keep = ($null -eq $ts) -or ($ts -ge $cutoff)
        }
        if ($keep) { $kept.Add($entries[$i]) }
    }
    if ($kept.Count -lt $entries.Count) {
        Write-Host "Changelog capped: dropped $($entries.Count - $kept.Count) entrie(s) older than 90 days."
    }
    $entries = @($kept)

    [PSCustomObject]@{
        metadata = [PSCustomObject]@{
            provider   = 'DataForNerds'
            apiVersion = 'v2'
            dataset    = "$Dataset.changelog"
            entryCount = $entries.Count
        }
        entries = $entries
    }
}

function New-Envelope {
    param(
        [string]   $Dataset,
        [string[]] $SourceUrls,
                   $Data,
        [string]   $LastModified,
        [string]   $Now
    )
    [PSCustomObject]@{
        metadata = [PSCustomObject]@{
            provider      = 'DataForNerds'
            apiVersion    = 'v2'
            dataset       = $Dataset
            recordCount   = @($Data).Count
            sourceUrls    = $SourceUrls
            lastModified  = $LastModified
            lastCollected = $Now
        }
        # Array-wrap: exactly one record must serialize as [ {...} ], not {...}
        data = @($Data)
    }
}
