@{
    RootModule = 'ALFileLinker.psm1'
    ModuleVersion = '1.2.0'
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
            ReleaseNotes = 'Default PS Scripts folder changed to PS_Scripts. Prompts user to select folder when default Coding Guidelines or PS_Scripts folder is not found.'
        }
    }
}
