function New-WintainiumApplicationDefinitionFromSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Source,
        [Parameter(Mandatory)][object]$Policy,
        [string]$OperationId
    )

    $operationId = if ([string]::IsNullOrWhiteSpace($OperationId)) { [guid]::NewGuid().ToString() } else { $OperationId }
    $errors = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[object]]::new()

    if ($null -eq $Source) {
        $errors.Add([pscustomobject][ordered]@{ Code='ApplicationSourceMissing'; Path='$.Source'; Message='Resolved source facts are required.' })
    } else {
        foreach ($property in @('ApplicationId','Name','CanonicalUri','ProviderId','ProviderContractVersion','ProviderSettings')) {
            if (-not $Source.PSObject.Properties[$property] -or [string]::IsNullOrWhiteSpace([string]$Source.$property)) {
                $errors.Add([pscustomobject][ordered]@{ Code='ApplicationSourceIncomplete'; Path="$.Source.$property"; Message="Resolved source fact '$property' is required." })
            }
        }
    }

    if ($null -eq $Policy) {
        $errors.Add([pscustomobject][ordered]@{ Code='ApplicationPolicyMissing'; Path='$.Policy'; Message='Core-owned application policy is required.' })
    } else {
        foreach ($section in @('Installer','Reconciliation','Release','Artifact')) {
            if (-not $Policy.PSObject.Properties[$section] -or $null -eq $Policy.$section) {
                $errors.Add([pscustomobject][ordered]@{ Code='ApplicationPolicyIncomplete'; Path="$.Policy.$section"; Message="Core-owned application policy section '$section' is required." })
            }
        }

        foreach ($section in @('Installer','Reconciliation')) {
            if ($Policy.PSObject.Properties[$section] -and $null -ne $Policy.$section) {
                foreach ($property in @('PluginId','RequiredContractVersion')) {
                    if (-not $Policy.$section.PSObject.Properties[$property] -or [string]::IsNullOrWhiteSpace([string]$Policy.$section.$property)) {
                        $errors.Add([pscustomobject][ordered]@{ Code='ApplicationPolicyIncomplete'; Path="$.Policy.$section.$property"; Message="Core-owned $section policy must provide '$property'." })
                    }
                }
            }
        }

        if ($Policy.PSObject.Properties['Release'] -and $null -ne $Policy.Release) {
            if (-not $Policy.Release.PSObject.Properties['Channel'] -or [string]$Policy.Release.Channel -notin @('stable','prerelease','any')) {
                $errors.Add([pscustomobject][ordered]@{ Code='ApplicationPolicyInvalid'; Path='$.Policy.Release.Channel'; Message="Release channel must be 'stable', 'prerelease', or 'any'." })
            }
        }

        if ($Policy.PSObject.Properties['Artifact'] -and $null -ne $Policy.Artifact) {
            $formats = @($Policy.Artifact.Formats)
            $architectures = @($Policy.Artifact.Architectures)
            if ($formats.Count -eq 0) {
                $errors.Add([pscustomobject][ordered]@{ Code='ApplicationPolicyInvalid'; Path='$.Policy.Artifact.Formats'; Message='At least one artifact format is required.' })
            }
            if ($architectures.Count -eq 0) {
                $errors.Add([pscustomobject][ordered]@{ Code='ApplicationPolicyInvalid'; Path='$.Policy.Artifact.Architectures'; Message='At least one artifact architecture is required.' })
            }
            $invalidFormats = @($formats | Where-Object { $_ -notin @('zip','msi','exe') })
            $invalidArchitectures = @($architectures | Where-Object { $_ -notin @('x64','x86','arm64','neutral') })
            if ($invalidFormats.Count -gt 0) {
                $errors.Add([pscustomobject][ordered]@{ Code='ApplicationPolicyInvalid'; Path='$.Policy.Artifact.Formats'; Message="Unsupported artifact format '$($invalidFormats[0])'." })
            }
            if ($invalidArchitectures.Count -gt 0) {
                $errors.Add([pscustomobject][ordered]@{ Code='ApplicationPolicyInvalid'; Path='$.Policy.Artifact.Architectures'; Message="Unsupported artifact architecture '$($invalidArchitectures[0])'." })
            }
        }
    }

    if ($errors.Count -gt 0) {
        return [pscustomobject][ordered]@{
            OperationId=$operationId; IsSuccessful=$false; Status='ApplicationDefinitionInvalid'
            ApplicationDefinition=$null; Errors=$errors.ToArray(); Warnings=$warnings.ToArray(); LogEvents=@()
        }
    }

    $sourceSettings = if ($Source.ProviderSettings -is [System.Collections.IDictionary]) { @{} + $Source.ProviderSettings } else { $Source.ProviderSettings }

    $application = [ordered]@{
        ManifestVersion='1.1'
        Id=[string]$Source.ApplicationId
        Name=[string]$Source.Name
        Homepage=if ($Source.PSObject.Properties['Homepage']) {[string]$Source.Homepage} else {$null}
        Publisher=if ($Source.PSObject.Properties['Publisher']) {[string]$Source.Publisher} else {$null}
        Source=[ordered]@{
            pluginId=[string]$Source.ProviderId
            requiredContractVersion=[string]$Source.ProviderContractVersion
            settings=$sourceSettings
        }
        Installer=[ordered]@{
            pluginId=[string]$Policy.Installer.PluginId
            requiredContractVersion=[string]$Policy.Installer.RequiredContractVersion
            settings=if ($Policy.Installer.PSObject.Properties['Settings'] -and $null -ne $Policy.Installer.Settings) {$Policy.Installer.Settings} else {@{}}
        }
        Reconciliation=[ordered]@{
            pluginId=[string]$Policy.Reconciliation.PluginId
            requiredContractVersion=[string]$Policy.Reconciliation.RequiredContractVersion
            settings=if ($Policy.Reconciliation.PSObject.Properties['Settings'] -and $null -ne $Policy.Reconciliation.Settings) {$Policy.Reconciliation.Settings} else {@{}}
        }
        Release=[ordered]@{ channel=[string]$Policy.Release.Channel }
        Artifact=[ordered]@{
            formats=@($Policy.Artifact.Formats)
            architectures=@($Policy.Artifact.Architectures)
            allowUnknownArchitecture=if ($Policy.Artifact.PSObject.Properties['AllowUnknownArchitecture']) {[bool]$Policy.Artifact.AllowUnknownArchitecture} else {$false}
        }
    }

    if ($application.Homepage -eq $null) { $application.Remove('Homepage') }
    if ($application.Publisher -eq $null) { $application.Remove('Publisher') }

    [pscustomobject][ordered]@{
        OperationId=$operationId; IsSuccessful=$true; Status='Resolved'
        ApplicationDefinition=[pscustomobject]$application
        Errors=@(); Warnings=$warnings.ToArray(); LogEvents=@()
    }
}