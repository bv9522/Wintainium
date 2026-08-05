Set-StrictMode -Version Latest

$script:WintainiumProjectRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:WintainiumSchemaRoot = Join-Path -Path $script:WintainiumProjectRoot -ChildPath 'schemas'
$script:WintainiumDefaultPluginRoot = Join-Path -Path $script:WintainiumProjectRoot -ChildPath 'plugins'

Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private') -Filter '*.ps1' -Recurse |
    Sort-Object FullName |
    ForEach-Object { . $_.FullName }

Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public') -Filter '*.ps1' -Recurse |
    Sort-Object FullName |
    ForEach-Object { . $_.FullName }

Export-ModuleMember -Function 'Test-WintainiumApplicationDefinition'
