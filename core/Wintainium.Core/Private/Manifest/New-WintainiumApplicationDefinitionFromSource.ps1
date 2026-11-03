function New-WintainiumApplicationDefinitionFromSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Source,
        [Parameter(Mandatory)][AllowNull()][object]$Policy,
        [string]$OperationId,
        [string]$AutomaticIconUri,
        [string]$SubmittedUri
    )

    $operationId = if ([string]::IsNullOrWhiteSpace($OperationId)) { [guid]::NewGuid().ToString() } else { $OperationId }
    $errors = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[object]]::new()
    $logEvents = [System.Collections.Generic.List[object]]::new()
    $sourceAliases = [System.Collections.Generic.List[string]]::new()
    $sourceContext = $null

    if ($null -eq $Source) {
        $errors.Add([pscustomobject][ordered]@{ Code='ApplicationSourceMissing'; Path='$.Source'; Message='Resolved source facts are required.' })
    } else {
        foreach ($property in @('ApplicationId','Name','CanonicalUri','ProviderId','ProviderContractVersion','ProviderSettings')) {
            if (-not $Source.PSObject.Properties[$property] -or [string]::IsNullOrWhiteSpace([string]$Source.$property)) {
                $errors.Add([pscustomobject][ordered]@{ Code='ApplicationSourceIncomplete'; Path="$.Source.$property"; Message="Resolved source fact '$property' is required." })
            }
        }

        if ($Source.PSObject.Properties['SourceContext'] -and $null -ne $Source.SourceContext) {
            # Providers commonly return JSON objects as PSCustomObject instances.
            # Normalize those objects (including nested objects in arrays) into
            # dictionaries before applying the manifest's JSON-safety rules.
            $convertSourceContextValue = $null
            $convertSourceContextValue = {
                param([AllowNull()][object]$Value, [int]$Depth = 0)

                if ($Depth -gt 8) { return ,$Value }

                if ($Value -is [System.Collections.IDictionary]) {
                    $converted = [ordered]@{}
                    foreach ($key in $Value.Keys) {
                        $converted[[string]$key] = & $convertSourceContextValue $Value[$key] ($Depth + 1)
                    }
                    return ,$converted
                }

                if ($Value -is [System.Management.Automation.PSCustomObject]) {
                    $converted = [ordered]@{}
                    foreach ($property in $Value.PSObject.Properties) {
                        if ($property.MemberType -in @('NoteProperty','Property')) {
                            $converted[[string]$property.Name] = & $convertSourceContextValue $property.Value ($Depth + 1)
                        }
                    }
                    return ,$converted
                }

                if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
                    $items = [System.Collections.Generic.List[object]]::new()
                    foreach ($item in $Value) {
                        $items.Add((& $convertSourceContextValue $item ($Depth + 1)))
                    }
                    return ,$items.ToArray()
                }

                return ,$Value
            }

            if ($Source.SourceContext -is [System.Collections.IDictionary] -or
                $Source.SourceContext -is [System.Management.Automation.PSCustomObject]) {
                $sourceContext = & $convertSourceContextValue $Source.SourceContext
            }
            else {
                $errors.Add([pscustomobject][ordered]@{ Code='ApplicationSourceContextInvalid'; Path='$.Source.SourceContext'; Message='Resolved source context must be a JSON object (dictionary or PSCustomObject).' })
            }
        }

        if ($Source.PSObject.Properties['Aliases'] -and $null -ne $Source.Aliases) {
            if ($Source.Aliases -is [string] -or $Source.Aliases -isnot [System.Collections.IEnumerable]) {
                $errors.Add([pscustomobject][ordered]@{ Code='ApplicationSourceAliasesInvalid'; Path='$.Source.Aliases'; Message='Resolved source aliases must be a collection of non-empty strings.' })
            }
            else {
                foreach ($alias in @($Source.Aliases)) {
                    if ($alias -isnot [string] -or [string]::IsNullOrWhiteSpace($alias)) {
                        $errors.Add([pscustomobject][ordered]@{ Code='ApplicationSourceAliasesInvalid'; Path='$.Source.Aliases'; Message='Each resolved source alias must be a non-empty string.' })
                        continue
                    }

                    $normalizedAlias = $alias.Trim()
                    if ($normalizedAlias -ieq [string]$Source.Name) { continue }
                    $isDuplicateAlias = $false
                    foreach ($existingAlias in $sourceAliases) {
                        if ($existingAlias -ieq $normalizedAlias) {
                            $isDuplicateAlias = $true
                            break
                        }
                    }
                    if (-not $isDuplicateAlias) {
                        $sourceAliases.Add($normalizedAlias)
                    }
                }
            }
        }
    }

    if ($null -ne $sourceContext) {
        foreach ($contextError in @(Test-WintainiumManifestSemantics -Manifest @{ source = @{ context = $sourceContext } })) {
            $errors.Add([pscustomobject][ordered]@{
                Code = [string]$contextError.Code
                Path = [string]$contextError.Path
                Message = [string]$contextError.Message
            })
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

        if ($Policy.PSObject.Properties['Installer'] -and $null -ne $Policy.Installer -and $Policy.Installer.PSObject.Properties['Fallbacks']) {
            $fallbackIndex = 0
            foreach ($fallback in @($Policy.Installer.Fallbacks)) {
                foreach ($property in @('PluginId','RequiredContractVersion')) {
                    if (-not $fallback.PSObject.Properties[$property] -or [string]::IsNullOrWhiteSpace([string]$fallback.$property)) {
                        $errors.Add([pscustomobject][ordered]@{ Code='ApplicationPolicyIncomplete'; Path="$.Policy.Installer.Fallbacks[$fallbackIndex].$property"; Message="Installer fallback policy must provide '$property'." })
                    }
                }
                $fallbackIndex++
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
            $invalidFormats = @($formats | Where-Object { $_ -notin @('zip','msi','msix','exe') })
            $invalidArchitectures = @($architectures | Where-Object { $_ -notin @('x64','x86','neutral') })
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
        manifestVersion='1.2'
        id=[string]$Source.ApplicationId
        name=[string]$Source.Name
        aliases=$sourceAliases.ToArray()
        description=if ($Source.PSObject.Properties['Description'] -and -not [string]::IsNullOrWhiteSpace([string]$Source.Description)) {[string]$Source.Description} else {$null}
        icon=if (-not [string]::IsNullOrWhiteSpace($AutomaticIconUri)) { [ordered]@{ automaticUri=[string]$AutomaticIconUri } } else { $null }
        homepage=if ($Source.PSObject.Properties['Homepage']) {[string]$Source.Homepage} else {$null}
        publisher=if ($Source.PSObject.Properties['Publisher']) {[string]$Source.Publisher} else {$null}
        source=[ordered]@{
            submittedUri=if (-not [string]::IsNullOrWhiteSpace($SubmittedUri)) { $SubmittedUri } else { $null }
            canonicalUri=[string]$Source.CanonicalUri
            pluginId=[string]$Source.ProviderId
            requiredContractVersion=[string]$Source.ProviderContractVersion
            settings=$sourceSettings
            context=$sourceContext
        }
        installer=[ordered]@{
            pluginId=[string]$Policy.Installer.PluginId
            requiredContractVersion=[string]$Policy.Installer.RequiredContractVersion
            settings=if ($Policy.Installer.PSObject.Properties['Settings'] -and $null -ne $Policy.Installer.Settings) {$Policy.Installer.Settings} else { @{} }
            fallbacks=@(
                if ($Policy.Installer.PSObject.Properties['Fallbacks'] -and $null -ne $Policy.Installer.Fallbacks) {
                    $Policy.Installer.Fallbacks | ForEach-Object {
                        [ordered]@{
                            pluginId=[string]$_.PluginId
                            requiredContractVersion=[string]$_.RequiredContractVersion
                            settings=if ($_.PSObject.Properties['Settings'] -and $null -ne $_.Settings) {$_.Settings} else { @{} }
                        }
                    }
                }
            )
        }
        reconciliation=[ordered]@{
            pluginId=[string]$Policy.Reconciliation.PluginId
            requiredContractVersion=[string]$Policy.Reconciliation.RequiredContractVersion
            settings=if ($Policy.Reconciliation.PSObject.Properties['Settings'] -and $null -ne $Policy.Reconciliation.Settings) {$Policy.Reconciliation.Settings} else {@{}}
        }
        release=[ordered]@{ channel=[string]$Policy.Release.Channel }
        artifact=[ordered]@{
            formats=@($Policy.Artifact.Formats)
            architectures=@($Policy.Artifact.Architectures)
            allowUnknownArchitecture=if ($Policy.Artifact.PSObject.Properties['AllowUnknownArchitecture']) {[bool]$Policy.Artifact.AllowUnknownArchitecture} else {$false}
        }
    }

    if ($sourceAliases.Count -eq 0) { $application.Remove('aliases') }
    if ($null -ne $sourceContext) {
        $logEvents.Add((New-WintainiumLogEvent -Severity Information -OperationId $operationId -Component 'Core' -EventName 'SourceContextPreserved' -Message 'Core validated and preserved provider-established source context in the application definition.' -Context @{ProviderId=[string]$Source.ProviderId;PropertyCount=$sourceContext.Count}))
    }
    if ($null -eq $sourceContext) { $application.source.Remove('context') }
    if ($application.source.submittedUri -eq $null) { $application.source.Remove('submittedUri') }
    if ($application.icon -eq $null) { $application.Remove('icon') }
    if ([string]::IsNullOrWhiteSpace([string]$application.description)) { $application.Remove('description') }
    if ([string]::IsNullOrWhiteSpace([string]$application.homepage)) { $application.Remove('homepage') }
    if ([string]::IsNullOrWhiteSpace([string]$application.publisher)) { $application.Remove('publisher') }

    [pscustomobject][ordered]@{
        OperationId=$operationId; IsSuccessful=$true; Status='Resolved'
        ApplicationDefinition=[pscustomobject]$application
        Errors=@(); Warnings=$warnings.ToArray(); LogEvents=$logEvents.ToArray()
    }
}