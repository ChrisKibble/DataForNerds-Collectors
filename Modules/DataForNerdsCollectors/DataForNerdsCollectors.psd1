#
# Module manifest for DataForNerdsCollectors
#

@{
    RootModule        = 'DataForNerdsCollectors.psm1'
    ModuleVersion     = '1.0.6'
    GUID              = 'a9c3f5e7-2d6b-4a8f-c1e9-7f3b5d8a1c6e'

    Author            = 'Data For Nerds'
    CompanyName       = 'Data For Nerds'
    Copyright         = '(c) Data For Nerds. All rights reserved.'
    Description       = 'Collects and normalizes data from public sources for IT professionals. Returns JSON-ready objects.'

    PowerShellVersion = '7.4'

    FunctionsToExport = @('Get-WindowsUpdateHistory', 'Get-LanguageCodes', 'Get-Microsoft365AppsUpdateHistory')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('Windows10', 'Windows11', 'WindowsUpdate', 'KBArticle', 'Patch', 'Hotpatch', 'IT', 'SysAdmin', 'Scraper')
            LicenseUri   = ''
            ProjectUri   = ''
            ReleaseNotes = '
1.0.0 - Initial release.
  - Renamed from WindowsUpdateHistory to DataForNerdsCollectors for broader scope.
  - Reorganized into Public/Private folder structure with one file per function.
  - Single public function: Get-WindowsUpdateHistory with -MajorVersion filtering.
  - Returns both Windows 10 and Windows 11 updates by default.
  - Cross-platform: Windows and Linux PowerShell 7.4+.
'
        }
    }
}
