@{
    RootModule = 'ALFileLinker.psm1'
    ModuleVersion = '1.5.0'
    GUID = 'b3eaf151-59a9-4cb0-8998-9fbf40bd004f'
    Author = 'soren.bogelund'
    CompanyName = ''
    Copyright = ''
    Description = 'Links central AL coding guidelines and PS scripts into repos (hardlink/symlink) and configures local git excludes.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Set-ALFileLinks','Set-ALFileLinksForRepos','Clone-RepoWithFileLinks','Set-ALFileLinkerDefaults','Get-ALFileLinkerDefaults')
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('AL','BusinessCentral','Guidelines','Git')
            ReleaseNotes = 'Added Set-ALFileLinkerDefaults / Get-ALFileLinkerDefaults for persistent default values (JSON config). CentralFileLinkFolder and RepoDestinationParentFolder are no longer mandatory when defaults are configured.'
        }
    }
}
