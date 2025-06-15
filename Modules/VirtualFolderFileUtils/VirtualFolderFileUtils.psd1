@{
    RootModule = 'VirtualFolderFileUtils.psm1'
    ModuleVersion = '1.0.0'
    GUID = '60b152d3-d171-4041-b042-c9c529e6fabc'
    Author = 'Shawn Hillis'
    CompanyName = 'Hillis.info'
    Description = 'Provides VirtualFolder and VirtualItem classes to generate, read, and verify hierarchal structures for testing or operations.'
    PowerShellVersion = '5.1'
    FunctionsToExport = 'New-VirtualFolder', 'New-VirtualItem', 'Write-FolderHierarchy', 'Read-FolderHierarchy', 'Format-Path', 'Resolve-ToAbsPath'
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{}
}
