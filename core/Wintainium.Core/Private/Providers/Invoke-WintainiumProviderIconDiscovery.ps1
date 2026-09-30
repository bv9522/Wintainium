function Invoke-WintainiumCoreProviderIconDiscovery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Provider,
        [Parameter(Mandatory)][object]$Request
    )

    $operationId = [string]$Request.OperationId
    $base = {
        param([bool]$IsSuccessful,[string]$Status,[string]$IconUri=$null,[object[]]$Errors=@(),[object[]]$Warnings=@())
        [pscustomobject][ordered]@{
            OperationId=$operationId
            IsSuccessful=$IsSuccessful
            Status=$Status
            IconUri=$IconUri
            Errors=@($Errors)
            Warnings=@()
        }
    }

    if ($Provider.PluginType -ne 'Provider') {
        return & $base $false 'IconDiscoveryUnsupported' $null @([pscustomobject]@{Code='IconDiscoveryInvalidPluginType';Message='The supplied plugin is not a provider.'})
    }

    if ($null -eq $Provider.Capabilities -or
        -not ($Provider.Capabilities -is [System.Collections.IDictionary]) -or
        -not $Provider.Capabilities.ContainsKey('iconDiscovery') -or
        $Provider.Capabilities.iconDiscovery -ne $true) {
        return & $base $false 'IconDiscoveryUnsupported'
    }

    if ($null -eq $Request.Source) {
        return & $base $false 'IconDiscoveryInvalidRequest' $null @([pscustomobject]@{Code='IconDiscoverySourceMissing';Message='Resolved source facts are required.'})
    }

    $providerDirectory=Split-Path -Path $Provider.DescriptorPath -Parent
    $modulePath=Join-Path -Path $providerDirectory -ChildPath ([IO.Path]::GetFileName([string]$Provider.EntryPoint))
    try { $resolvedModulePath=(Resolve-Path -LiteralPath $modulePath -ErrorAction Stop).Path }
    catch {
        return & $base $false 'IconDiscoveryInternalError' $null @([pscustomobject]@{Code='IconDiscoveryEntryPointNotFound';Message="Provider entry point '$($Provider.EntryPoint)' was not found."})
    }

    try {
        $module=Import-Module -Name $resolvedModulePath -Force -PassThru -ErrorAction Stop
        $command=Get-Command -Name "$($module.Name)\Invoke-WintainiumProviderIconDiscovery" -CommandType Function -ErrorAction SilentlyContinue
        if ($null -eq $command) {
            return & $base $false 'IconDiscoveryUnsupported'
        }
        $result=& $command -Request $Request
    }
    catch {
        return & $base $false 'IconDiscoveryInternalError' $null @([pscustomobject]@{Code='IconDiscoveryInternalError';Message=$_.Exception.Message})
    }

    if ($null -eq $result -or @($result).Count -ne 1) {
        return & $base $false 'IconDiscoveryResultInvalid' $null @([pscustomobject]@{Code='IconDiscoveryResultInvalid';Message='Icon discovery must return exactly one structured result object.'})
    }

    foreach ($property in @('OperationId','IsSuccessful','Status','IconUri','Errors','Warnings')) {
        if (-not $result.PSObject.Properties[$property]) {
            return & $base $false 'IconDiscoveryResultInvalid' $null @([pscustomobject]@{Code='IconDiscoveryResultInvalid';Message="Icon discovery result is missing required property '$property'."})
        }
    }

    if ([string]$result.OperationId -ne $operationId) {
        return & $base $false 'IconDiscoveryResultInvalid' $null @([pscustomobject]@{Code='IconDiscoveryOperationIdMismatch';Message='Icon discovery result OperationId does not match the Core request OperationId.'})
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$result.IconUri)) {
        try { $uri=[Uri]([string]$result.IconUri) }
        catch { return & $base $false 'IconDiscoveryResultInvalid' $null @([pscustomobject]@{Code='IconDiscoveryUriInvalid';Message='Discovered icon URI is not a valid URI.'}) }
        if (-not $uri.IsAbsoluteUri -or $uri.Scheme -notin @('http','https','file')) {
            return & $base $false 'IconDiscoveryResultInvalid' $null @([pscustomobject]@{Code='IconDiscoveryUriInvalid';Message='Discovered icon URI must use HTTP, HTTPS, or file scheme.'})
        }
        return & $base ([bool]$result.IsSuccessful) ([string]$result.Status) ([string]$result.IconUri) @($result.Errors) @($result.Warnings)
    }

    & $base ([bool]$result.IsSuccessful) ([string]$result.Status) $null @($result.Errors) @($result.Warnings)
}
