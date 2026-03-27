@{
    RootModule = 'ALFileLinker.psm1'
    ModuleVersion = '1.3.0'
    GUID = 'b3eaf151-59a9-4cb0-8998-9fbf40bd004f'
    Author = 'soren.bogelund'
    CompanyName = ''
    Copyright = ''
    Description = 'Links central AL coding guidelines and PS scripts into repos (hardlink/symlink) and configures local git excludes.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Set-ALFileLinks','Set-ALFileLinksForRepos','Clone-RepoWithFileLinks')
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('AL','BusinessCentral','Guidelines','Git')
            ReleaseNotes = 'Added fallback: when no .code-workspace file is found, scans repo root and immediate subdirectories for app.json to determine target folder. Ensures linked folders are always placed alongside app.json.'
        }
    }
}
