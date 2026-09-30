BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:schemaPath = Join-Path -Path $script:testRoot -ChildPath 'schemas/application-manifest.schema.json'
    Import-Module $script:modulePath -Force
}

Describe 'Wintainium application icon override' {
    BeforeEach {
        $script:tempRoot = Join-Path $env:TEMP ("Wintainium-IconOverride-" + [guid]::NewGuid().Guid)
        New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
        $script:manifestPath = Join-Path $script:tempRoot 'example.wintainium.json'

        $manifest = [ordered]@{
            manifestVersion='1.1'
            id='example.application'
            name='Example'
            source=[ordered]@{ pluginId='Wintainium.provider.github-releases'; requiredContractVersion='1'; settings=@{} }
            installer=[ordered]@{ pluginId='Wintainium.installer.example'; requiredContractVersion='1'; settings=@{} }
            reconciliation=[ordered]@{ pluginId='Wintainium.reconciliation.example'; requiredContractVersion='1'; settings=@{} }
            release=[ordered]@{ channel='stable' }
            artifact=[ordered]@{ formats=@('exe'); architectures=@('x64') }
        }

        $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $script:manifestPath -Encoding utf8
    }

    AfterEach {
        Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'persists a user icon override without replacing the application manifest' {
        $result = Set-WintainiumApplicationIconOverride -ManifestPath $script:manifestPath -IconUri 'https://example.com/icon.png' -SchemaPath $script:schemaPath
        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'IconOverrideUpdated'
        $saved = Get-Content -LiteralPath $script:manifestPath -Raw | ConvertFrom-Json
        $saved.icon.overrideUri | Should -Be 'https://example.com/icon.png'
        $saved.name | Should -Be 'Example'
    }

    It 'clears only the user override when resetting to automatic behavior' {
        $result = Set-WintainiumApplicationIconOverride -ManifestPath $script:manifestPath -IconUri 'https://example.com/icon.png' -SchemaPath $script:schemaPath
        $result.IsSuccessful | Should -Be $true
        $result = Set-WintainiumApplicationIconOverride -ManifestPath $script:manifestPath -IconUri '' -SchemaPath $script:schemaPath
        $result.IsSuccessful | Should -Be $true
        $saved = Get-Content -LiteralPath $script:manifestPath -Raw | ConvertFrom-Json
        $saved.PSObject.Properties.Name | Should -Not -Contain 'icon'
    }

    It 'rejects unsupported icon URI schemes' {
        $result = Set-WintainiumApplicationIconOverride -ManifestPath $script:manifestPath -IconUri 'javascript:alert(1)' -SchemaPath $script:schemaPath
        $result.IsSuccessful | Should -Be $false
        @($result.Errors.Code) | Should -Contain 'ApplicationIconUriInvalid'
    }
}
