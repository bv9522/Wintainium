[35mtests/Integration/ApplicationDefinitionValidation.Tests.ps1[m[36m:[m[32m10[m[36m:[m        $result = Test-[1;31mWintanium[mApplicationDefinition -ManifestPath (Join-Path -Path $manifestRoot -ChildPath 'valid-portable-zip.json') -PluginRoot $pluginRoot
[35mtests/Integration/ApplicationDefinitionValidation.Tests.ps1[m[36m:[m[32m19[m[36m:[m        $result = Test-[1;31mWintanium[mApplicationDefinition -ManifestPath (Join-Path -Path $manifestRoot -ChildPath 'missing-provider.json') -PluginRoot $pluginRoot
[35mtests/Integration/ApplicationDefinitionValidation.Tests.ps1[m[36m:[m[32m26[m[36m:[m        $result = Test-[1;31mWintanium[mApplicationDefinition -ManifestPath (Join-Path -Path $manifestRoot -ChildPath 'incompatible-installer.json') -PluginRoot $pluginRoot
[35mtests/Unit/Logging.Tests.ps1[m[36m:[m[32m10[m[36m:[m            New-[1;31mWintanium[mLogEvent -Severity Information -OperationId 'operation-123' -Component Core -EventName ValidationStarted -Message 'Started.' -Context @{ ManifestId = 'org.example.app' }
[35mtests/Unit/ManifestLoading.Tests.ps1[m[36m:[m[32m12[m[36m:[m            Import-[1;31mWintanium[mManifest -Path $path
[35mtests/Unit/ManifestLoading.Tests.ps1[m[36m:[m[32m24[m[36m:[m            Import-[1;31mWintanium[mManifest -Path $path
[35mtests/Unit/ManifestLoading.Tests.ps1[m[36m:[m[32m41[m[36m:[m            Import-[1;31mWintanium[mManifest -Path $path
[35mtests/Unit/ManifestLoading.Tests.ps1[m[36m:[m[32m54[m[36m:[m            Import-[1;31mWintanium[mManifest -Path $path
[35mtests/Unit/ManifestLoading.Tests.ps1[m[36m:[m[32m67[m[36m:[m            @(Find-[1;31mWintanium[mManifestFile -ManifestRoot $path)
[35mtests/Unit/ManifestLoading.Tests.ps1[m[36m:[m[32m81[m[36m:[m            @(Find-[1;31mWintanium[mManifestFile -ManifestRoot $path)
[35mtests/Unit/ManifestValidation.Tests.ps1[m[36m:[m[32m14[m[36m:[m            Test-[1;31mWintanium[mManifestSchema -ManifestPath $path -SchemaPath $schema
[35mtests/Unit/ManifestValidation.Tests.ps1[m[36m:[m[32m24[m[36m:[m            Test-[1;31mWintanium[mManifestSchema -ManifestPath $path -SchemaPath $schema
[35mtests/Unit/ManifestValidation.Tests.ps1[m[36m:[m[32m34[m[36m:[m            $loadResult = Import-[1;31mWintanium[mManifest -Path $path
[35mtests/Unit/PluginRegistry.Tests.ps1[m[36m:[m[32m12[m[36m:[m            Get-[1;31mWintanium[mPluginRegistry -PluginRoot $path
[35mtests/Unit/PluginRegistry.Tests.ps1[m[36m:[m[32m22[m[36m:[m            Get-[1;31mWintanium[mPluginRegistry -PluginRoot $path
[35mtests/Unit/PluginRegistry.Tests.ps1[m[36m:[m[32m26[m[36m:[m            Resolve-[1;31mWintanium[mPlugin -Plugins $plugins -PluginId 'Wintainium.installer.portable-zip' -PluginType Installer -RequiredContractVersion '1'
[35mtests/Unit/PluginRegistry.Tests.ps1[m[36m:[m[32m37[m[36m:[m            Get-[1;31mWintanium[mPluginRegistry -PluginRoot $path
[35mtests/Unit/PluginRegistry.Tests.ps1[m[36m:[m[32m41[m[36m:[m            $manifest = (Import-[1;31mWintanium[mManifest -Path $path).Manifest
[35mtests/Unit/PluginRegistry.Tests.ps1[m[36m:[m[32m42[m[36m:[m            $installer = Resolve-[1;31mWintanium[mPlugin -Plugins $plugins -PluginId $manifest.installer.pluginId -PluginType Installer -RequiredContractVersion $manifest.installer.requiredContractVersion
[35mtests/Unit/PluginRegistry.Tests.ps1[m[36m:[m[32m43[m[36m:[m            Test-[1;31mWintanium[mInstallerCompatibility -Manifest $manifest -InstallerPlugin $installer.Plugin
