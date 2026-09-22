$testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$modulePath = Join-Path -Path $testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
$schemaPath = Join-Path -Path $testRoot -ChildPath 'schemas/application-manifest.schema.json'

Import-Module $modulePath -Force

function New-TestApplicationDefinition {
    [pscustomobject][ordered]@{
        manifestVersion = '1.1'
        id = 'org.example.app'
        name = 'Example Application'
        homepage = 'https://example.org/'
        publisher = 'Example'
        source = [pscustomobject][ordered]@{
            pluginId = 'Wintainium.provider.example'
            requiredContractVersion = '1'
            settings = [pscustomobject][ordered]@{}
        }
        installer = [pscustomobject][ordered]@{
            pluginId = 'Wintainium.installer.example'
            requiredContractVersion = '1'
            settings = [pscustomobject][ordered]@{}
        }
        reconciliation = [pscustomobject][ordered]@{
            pluginId = 'Wintainium.reconciliation.example'
            requiredContractVersion = '1'
            settings = [pscustomobject][ordered]@{}
        }
        release = [pscustomobject][ordered]@{
            channel = 'stable'
        }
        artifact = [pscustomobject][ordered]@{
            formats = @('msi')
            architectures = @('x64')
        }
    }
}

Describe 'Wintainium application definition persistence' {
    BeforeEach {
        $script:manifestRoot = Join-Path $TestDrive ("manifests-{0}" -f ([guid]::NewGuid().Guid))
    }

    It 'persists a normalized application definition using the manifest convention' {
        $definition = New-TestApplicationDefinition

        $path = InModuleScope Wintainium.Core -Parameters @{
            ApplicationDefinition = $definition
            ManifestRoot = $script:manifestRoot
            SchemaPath = $schemaPath
        } {
            param($ApplicationDefinition, $ManifestRoot, $SchemaPath)
            Set-WintainiumApplicationDefinition -ApplicationDefinition $ApplicationDefinition -ManifestRoot $ManifestRoot -SchemaPath $SchemaPath
        }

        $path | Should -Be (Join-Path $script:manifestRoot 'org.example.app.wintainium.json')
        Test-Path -LiteralPath $path | Should -BeTrue

        $document = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $document.manifestVersion | Should -Be '1.1'
        $document.id | Should -Be 'org.example.app'
        $document.source.pluginId | Should -Be 'Wintainium.provider.example'
    }

    It 'creates the manifest root when it does not exist' {
        $definition = New-TestApplicationDefinition

        InModuleScope Wintainium.Core -Parameters @{
            ApplicationDefinition = $definition
            ManifestRoot = $script:manifestRoot
            SchemaPath = $schemaPath
        } {
            param($ApplicationDefinition, $ManifestRoot, $SchemaPath)
            Set-WintainiumApplicationDefinition -ApplicationDefinition $ApplicationDefinition -ManifestRoot $ManifestRoot -SchemaPath $SchemaPath | Out-Null
        }

        Test-Path -LiteralPath $script:manifestRoot -PathType Container | Should -BeTrue
    }

    It 'replaces an existing definition by application identity' {
        $first = New-TestApplicationDefinition
        $second = New-TestApplicationDefinition
        $second.name = 'Updated Example'

        foreach ($definition in @($first, $second)) {
            InModuleScope Wintainium.Core -Parameters @{
                ApplicationDefinition = $definition
                ManifestRoot = $script:manifestRoot
                SchemaPath = $schemaPath
            } {
                param($ApplicationDefinition, $ManifestRoot, $SchemaPath)
                Set-WintainiumApplicationDefinition -ApplicationDefinition $ApplicationDefinition -ManifestRoot $ManifestRoot -SchemaPath $SchemaPath | Out-Null
            }
        }

        $files = @(Get-ChildItem -LiteralPath $script:manifestRoot -Filter '*.wintainium.json' -File)
        $files | Should -HaveCount 1
        (Get-Content -LiteralPath $files[0].FullName -Raw | ConvertFrom-Json).name | Should -Be 'Updated Example'
    }

    It 'rejects a schema-invalid definition before replacing an existing file' {
        $valid = New-TestApplicationDefinition

        InModuleScope Wintainium.Core -Parameters @{
            ApplicationDefinition = $valid
            ManifestRoot = $script:manifestRoot
            SchemaPath = $schemaPath
        } {
            param($ApplicationDefinition, $ManifestRoot, $SchemaPath)
            Set-WintainiumApplicationDefinition -ApplicationDefinition $ApplicationDefinition -ManifestRoot $ManifestRoot -SchemaPath $SchemaPath | Out-Null
        }

        $invalid = New-TestApplicationDefinition
        $invalid.name = $null

        {
            InModuleScope Wintainium.Core -Parameters @{
                ApplicationDefinition = $invalid
                ManifestRoot = $script:manifestRoot
                SchemaPath = $schemaPath
            } {
                param($ApplicationDefinition, $ManifestRoot, $SchemaPath)
                Set-WintainiumApplicationDefinition -ApplicationDefinition $ApplicationDefinition -ManifestRoot $ManifestRoot -SchemaPath $SchemaPath
            }
        } | Should -Throw

        $document = Get-Content -LiteralPath (Join-Path $script:manifestRoot 'org.example.app.wintainium.json') -Raw | ConvertFrom-Json
        $document.name | Should -Be 'Example Application'
    }

    It 'does not persist installed state alongside the application definition' {
        $definition = New-TestApplicationDefinition

        InModuleScope Wintainium.Core -Parameters @{
            ApplicationDefinition = $definition
            ManifestRoot = $script:manifestRoot
            SchemaPath = $schemaPath
        } {
            param($ApplicationDefinition, $ManifestRoot, $SchemaPath)
            Set-WintainiumApplicationDefinition -ApplicationDefinition $ApplicationDefinition -ManifestRoot $ManifestRoot -SchemaPath $SchemaPath | Out-Null
        }

        Test-Path -LiteralPath (Join-Path $script:manifestRoot 'installed-state.json') | Should -BeFalse
    }

    It 'rejects an invalid application identifier before deriving a destination path' {
        $definition = New-TestApplicationDefinition
        $definition.id = '../outside'

        {
            InModuleScope Wintainium.Core -Parameters @{
                ApplicationDefinition = $definition
                ManifestRoot = $script:manifestRoot
                SchemaPath = $schemaPath
            } {
                param($ApplicationDefinition, $ManifestRoot, $SchemaPath)
                Set-WintainiumApplicationDefinition -ApplicationDefinition $ApplicationDefinition -ManifestRoot $ManifestRoot -SchemaPath $SchemaPath
            }
        } | Should -Throw

        @(Get-ChildItem -LiteralPath $script:manifestRoot -Force -File) | Should -HaveCount 0
    }
}
