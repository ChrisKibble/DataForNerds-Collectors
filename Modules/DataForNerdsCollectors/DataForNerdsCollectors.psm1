#Requires -Version 7.4

Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Module-scoped constants
# ---------------------------------------------------------------------------

# Headers that prevent Microsoft's CDN from returning a captcha or reduced-content page.
# Optional bot identification headers are added when DFN_BOT_NAME / DFN_BOT_INFO
# environment variables are set (configured via GitHub Secrets in CI).
$script:DefaultHeaders = @{
    'User-Agent'      = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
    'Accept'          = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    'Accept-Language' = 'en-US,en;q=0.9'
}

if ($env:DFN_BOT_NAME) { $script:DefaultHeaders['X-Bot-Name'] = $env:DFN_BOT_NAME }
if ($env:DFN_BOT_INFO) { $script:DefaultHeaders['X-Bot-Info'] = $env:DFN_BOT_INFO }

# ---------------------------------------------------------------------------
# Dot-source private helpers (must load before public functions)
# ---------------------------------------------------------------------------

Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    . $_.FullName
}

# ---------------------------------------------------------------------------
# Dot-source public functions
# ---------------------------------------------------------------------------

Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    . $_.FullName
}

# ---------------------------------------------------------------------------
# Export public functions
# ---------------------------------------------------------------------------

Export-ModuleMember -Function 'Get-WindowsUpdateHistory', 'Get-LanguageCodes', 'Get-Microsoft365AppsUpdateHistory', 'Get-WindowsReleaseHistory'
