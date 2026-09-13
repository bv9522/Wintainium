@{
    RootModule = 'Wintainium.Core.psm1'
    ModuleVersion = '0.1.0'
    GUID = '44450f8f-15fc-4d6a-83f6-5f30b0bc3a54'
    Author = 'Wintainium Contributors'
    CompanyName = 'Wintainium'
    Copyright = '(c) Wintainium Contributors.'
    Description = 'Core validation and provider-backed release discovery foundation for Wintainium application definitions.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @(
        'Get-WintainiumManifest'
        'Test-WintainiumApplicationDefinition'
        'Get-WintainiumApplicationRelease'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
