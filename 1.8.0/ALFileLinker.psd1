@{
    RootModule = 'ALFileLinker.psm1'
    ModuleVersion = '1.8.0'
    GUID = 'b3eaf151-59a9-4cb0-8998-9fbf40bd004f'
    Author = 'soren.bogelund'
    CompanyName = ''
    Copyright = ''
    Description = 'Copies central AL coding guidelines and PS scripts into repos.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Set-ALFileLinks','Set-ALFileLinksForRepos','Copy-RepoWithFileLinks','Set-ALFileLinkerDefaults','Get-ALFileLinkerDefaults')
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('AL','BusinessCentral','Guidelines','Git')
            ReleaseNotes = 'Replaced hardlinks/symlinks with plain file copies. Removed post-checkout hook and .git/alfilelinker.json config. Old hooks and config are cleaned up automatically on first run.'
        }
    }
}
