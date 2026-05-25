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
        data = $Data
    }
}
