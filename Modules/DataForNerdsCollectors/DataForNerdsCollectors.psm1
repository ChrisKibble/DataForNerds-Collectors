#Requires -Version 7.4

Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Module-scoped constants
# ---------------------------------------------------------------------------

# Windows 10 update history page - does not redirect, URL is stable
$script:Win10UpdateHistoryUrl = 'https://support.microsoft.com/en-us/topic/windows-10-update-history-e6058e7c-4116-38f1-b984-4fcacfba5e5d'

# Windows 11 entry point - Microsoft keeps this alias pointed at the current version's update page
# The left-nav on that page lists ALL Windows 11 versions, so one fetch is sufficient
$script:Win11UpdateHistoryUrl = 'https://aka.ms/Windows11UpdateHistory'

# Windows 11 hotpatch release notes page - covers 24H2, 25H2, and Windows Server versions
# Windows Server sections are detected and skipped automatically
$script:Win11HotpatchHistoryUrl = 'https://support.microsoft.com/en-us/topic/release-notes-for-hotpatch-on-windows-11-enterprise-version-25h2-0bbaa1c7-5070-41ca-a7c9-4ead79602dbf'

# Windows Server update history page - covers Server 2022 (20348.x), Server version 23H2 (25398.x), and Server 2025 (26100.x)
$script:WinServerUpdateHistoryUrl = 'https://support.microsoft.com/en-us/topic/windows-server-2022-update-history-e1caa597-00c5-4ab9-9f3e-8212fe80b2ee'

# Office language codes and BCP 47 mappings (MS-OE376 specification)
$script:LanguageCodesUrl = 'https://learn.microsoft.com/en-us/openspecs/office_standards/ms-oe376/6c085406-a698-4e12-9d4d-c3b0ee3dbc4a'

# Microsoft 365 Apps update history listed by date (all channels in one table)
$script:Microsoft365AppsUpdateHistoryUrl = 'https://learn.microsoft.com/en-us/officeupdates/update-history-microsoft365-apps-by-date'

# Windows 10 client release information - version-to-base-build mapping
$script:Windows10ReleaseHistoryUrl = 'https://learn.microsoft.com/en-us/windows/release-health/release-information'

# Windows 11 client release information - version-to-base-build mapping
$script:Windows11ReleaseHistoryUrl = 'https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information'

# Headers that prevent Microsoft's CDN from returning a captcha or reduced-content page
$script:DefaultHeaders = @{
    'User-Agent'      = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
    'Accept'          = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    'Accept-Language' = 'en-US,en;q=0.9'
}

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
