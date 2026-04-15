@{
    RootModule = 'ALFileLinker.psm1'
    ModuleVersion = '1.10.0'
    GUID = 'b3eaf151-59a9-4cb0-8998-9fbf40bd004f'
    Author = 'soren.bogelund'
    CompanyName = ''
    Copyright = ''
    Description = 'Copies central PS scripts into AL repos.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Set-ALFileLinks','Set-ALFileLinksForRepos','Copy-RepoWithFileLinks','Set-ALFileLinkerDefaults','Get-ALFileLinkerDefaults')
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('AL','BusinessCentral','Guidelines','Git')
            ReleaseNotes = 'PS_Scripts folder is now always placed in the repo root instead of in the app.json sub-folder(s).'
        }
    }
}
