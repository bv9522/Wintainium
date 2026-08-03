Set-StrictMode -Version Latest

$script:WintaniumProjectRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:WintaniumSchemaRoot = Join-Path -Path $script:WintaniumProjectRoot -ChildPath 'schemas'
$script:WintaniumDefaultPluginRoot = Join-Path -Path $script:WintaniumProjectRoot -ChildPath 'plugins'

Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private') -Filter '*.ps1' -Recurse |
    Sort-Object FullName |
    ForEach-Object { . $_.FullName }

Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public') -Filter '*.ps1' -Recurse |
    Sort-Object FullName |
    ForEach-Object { . $_.FullName }

Export-ModuleMember -Function 'Test-WintaniumApplicationDefinition'
