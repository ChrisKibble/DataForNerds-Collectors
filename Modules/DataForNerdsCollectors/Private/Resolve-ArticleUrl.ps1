function Resolve-ArticleUrl {
    <#
    .SYNOPSIS
        Extracts and normalizes the href from an anchor element's tag attributes.

    .DESCRIPTION
        If the href is relative, prepends https://support.microsoft.com; if absolute, returns as-is.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]$TagAttributes
    )

    $hrefMatch = [regex]::Match($TagAttributes, 'href="([^"]*)"')
    if ($hrefMatch.Success) {
        $h = $hrefMatch.Groups[1].Value
        if ($h -notmatch '^https?://') {
            return 'https://support.microsoft.com' + $h
        }
        return $h
    }
    return $null
}
