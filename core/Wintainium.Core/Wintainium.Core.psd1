@{
    RootModule = 'Wintainium.Core.psm1'
    ModuleVersion = '0.1.0'
    GUID = '44450f8f-15fc-4d6a-83f6-5f30b0bc3a54'
    Author = 'Wintainium Contributors'
    CompanyName = 'Wintainium'
    Copyright = '(c) Wintainium Contributors.'
    Description = 'PowerShell engine for manifest validation, provider-backed release discovery, downloads, installation, and lifecycle orchestration for Wintainium.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @(
        'Get-WintainiumManifest'
        'Get-WintainiumApplicationInstalledState'
        'Test-WintainiumApplicationDefinition'
        'Get-WintainiumApplicationRelease'
        'Invoke-WintainiumApplicationUpdate'
        'Invoke-WintainiumApplicationOnboarding'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
