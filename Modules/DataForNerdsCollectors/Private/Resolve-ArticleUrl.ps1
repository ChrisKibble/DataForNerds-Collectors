function Resolve-ArticleUrl {
    <#
    .SYNOPSIS
        Extracts and normalizes the href from an anchor element's tag attributes.

    .DESCRIPTION
        Resolves the href against the page's own (post-redirect) URL using standard
        relative-URL rules, so absolute hrefs, root-relative hrefs ("/en-us/..."),
        dot-relative hrefs ("../../2026/...") and bare sibling hrefs ("kb123-...")
        all resolve to a correct absolute URL.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]$TagAttributes,

        [Parameter(Mandatory)]
        [string]$BaseUri
    )

    $hrefMatch = [regex]::Match($TagAttributes, 'href="([^"]*)"')
    if (-not $hrefMatch.Success) {
        return $null
    }

    $href = $hrefMatch.Groups[1].Value
    try {
        return [Uri]::new([Uri]$BaseUri, $href).AbsoluteUri
    }
    catch {
        Write-Verbose "Failed to resolve href '$href' against base '$BaseUri': $_"
        return $href
    }
}
