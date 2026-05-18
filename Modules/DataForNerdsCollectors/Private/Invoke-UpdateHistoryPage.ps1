function Invoke-UpdateHistoryPage {
    <#
    .SYNOPSIS
        Fetches a web page with standard headers and error handling.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Uri
    )

    try {
        $response = Invoke-WebRequest -Uri $Uri `
                                      -Headers $script:DefaultHeaders `
                                      -UseBasicParsing `
                                      -MaximumRedirection 10 `
                                      -ErrorAction Stop
        return $response
    }
    catch {
        Write-Error "Failed to fetch update history page: $_"
        return $null
    }
}
