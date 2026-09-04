function Invoke-WintainiumInstallerOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]$Invocation,
        [Parameter(Mandatory)] [ValidateRange(1, 2147483647)] [int]$TimeoutMilliseconds,
        [System.Threading.CancellationToken]$CancellationToken = [System.Threading.CancellationToken]::None
    )

    $operationId = if ($null -ne $Invocation -and $Invocation.PSObject.Properties.Name -contains 'OperationId') { $Invocation.OperationId } else { $null }
    $downloadOperationId = if ($null -ne $Invocation -and $Invocation.PSObject.Properties.Name -contains 'DownloadOperationId') { $Invocation.DownloadOperationId } else { $null }
    $pluginId = if ($null -ne $Invocation -and $Invocation.PSObject.Properties.Name -contains 'PluginId') { $Invocation.PluginId } else { $null }

    $failure = {
        param([string]$FailureKind,[string]$Message)
        [pscustomobject][ordered]@{
            Status = 'Failed'
            FailureKind = $FailureKind
            OperationId = $operationId
            DownloadOperationId = $downloadOperationId
            PluginId = $pluginId
            ExitCode = $null
            StandardOutput = ''
            StandardError = ''
            DurationMilliseconds = 0
            ErrorMessage = $Message
        }
    }

    if ($null -eq $Invocation) {
        return & $failure 'InvalidInput' 'Installer operation requires an installer invocation.'
    }

    foreach ($requiredProperty in @('OperationId','DownloadOperationId','PluginId','PluginModulePath','ArtifactPath','ArtifactFormat','Settings')) {
        if (-not ($Invocation.PSObject.Properties.Name -contains $requiredProperty)) {
            return & $failure 'InvalidInvocation' "Installer invocation is missing required property '$requiredProperty'."
        }
    }

    $modulePath = [string]$Invocation.PluginModulePath
    if ([string]::IsNullOrWhiteSpace($modulePath) -or -not [System.IO.Path]::IsPathFullyQualified($modulePath) -or -not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
        return & $failure 'InvalidInvocation' 'Installer invocation must identify an existing absolute plugin module path.'
    }

    $modulePath = [System.IO.Path]::GetFullPath($modulePath)
    try {
        $module = Get-Module | Where-Object {
            $_.Path -and ((Resolve-Path -LiteralPath $_.Path -ErrorAction SilentlyContinue).Path -eq $modulePath)
        } | Select-Object -First 1
        if ($null -eq $module) {
            $module = Import-Module -Name $modulePath -PassThru -ErrorAction Stop
        }

        $command = Get-Command -Module $module.Name -Name 'Invoke-WintainiumInstaller' -CommandType Function -ErrorAction SilentlyContinue
        if ($null -eq $command) {
            return & $failure 'InstallerOperationNotFound' "Installer '$pluginId' does not export Invoke-WintainiumInstaller."
        }

        $processSpecification = & $command -Invocation $Invocation
    }
    catch {
        return & $failure 'InstallerInternalError' 'Installer plugin execution failed.'
    }

    if ($null -eq $processSpecification -or @($processSpecification).Count -ne 1) {
        return & $failure 'InstallerResultInvalid' 'Installer plugin must return exactly one structured process specification.'
    }

    $spec = $processSpecification
    if (-not ($spec.PSObject.Properties.Name -contains 'ExecutablePath')) {
        return & $failure 'InstallerProcessSpecificationInvalid' "Installer process specification is missing required property 'ExecutablePath'."
    }

    $executablePath = [string]$spec.ExecutablePath
    if ([string]::IsNullOrWhiteSpace($executablePath) -or -not [System.IO.Path]::IsPathFullyQualified($executablePath) -or -not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
        return & $failure 'InstallerProcessSpecificationInvalid' 'Installer process specification requires an existing absolute executable path.'
    }
    $executablePath = [System.IO.Path]::GetFullPath($executablePath)

    $arguments = @()
    if ($spec.PSObject.Properties.Name -contains 'Arguments') {
        $rawArguments = $spec.Arguments
        if ($rawArguments -is [string] -or $rawArguments -is [System.Collections.IDictionary] -or $null -eq $rawArguments) {
            return & $failure 'InstallerProcessSpecificationInvalid' 'Installer process specification Arguments must be an array of strings.'
        }
        $arguments = @($rawArguments)
        if (@($arguments | Where-Object { $_ -isnot [string] }).Count -gt 0) {
            return & $failure 'InstallerProcessSpecificationInvalid' 'Installer process specification Arguments must contain only strings.'
        }
    }

    $workingDirectory = $null
    if ($spec.PSObject.Properties.Name -contains 'WorkingDirectory' -and $null -ne $spec.WorkingDirectory) {
        $workingDirectory = [string]$spec.WorkingDirectory
        if (-not [string]::IsNullOrWhiteSpace($workingDirectory)) {
            if (-not [System.IO.Path]::IsPathFullyQualified($workingDirectory) -or -not (Test-Path -LiteralPath $workingDirectory -PathType Container)) {
                return & $failure 'InstallerProcessSpecificationInvalid' 'Installer process specification WorkingDirectory must be an existing absolute directory.'
            }
            $workingDirectory = [System.IO.Path]::GetFullPath($workingDirectory)
        }
        else {
            $workingDirectory = $null
        }
    }

    $environmentVariables = $null
    if ($spec.PSObject.Properties.Name -contains 'EnvironmentVariables' -and $null -ne $spec.EnvironmentVariables) {
        if ($spec.EnvironmentVariables -isnot [System.Collections.IDictionary]) {
            return & $failure 'InstallerProcessSpecificationInvalid' 'Installer process specification EnvironmentVariables must be a dictionary.'
        }
        $environmentVariables = @{}
        foreach ($entry in $spec.EnvironmentVariables.GetEnumerator()) {
            $name = [string]$entry.Key
            if ([string]::IsNullOrWhiteSpace($name) -or $name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
                return & $failure 'InstallerProcessSpecificationInvalid' "Installer process specification contains invalid environment variable name '$name'."
            }
            if ($null -eq $entry.Value) {
                return & $failure 'InstallerProcessSpecificationInvalid' "Installer process specification environment variable '$name' has a null value."
            }
            $environmentVariables[$name] = [string]$entry.Value
        }
    }

    $processParameters = @{
        ExecutablePath = $executablePath
        Arguments = [string[]]$arguments
        TimeoutMilliseconds = $TimeoutMilliseconds
        CancellationToken = $CancellationToken
    }
    if ($null -ne $workingDirectory) { $processParameters.WorkingDirectory = $workingDirectory }
    if ($null -ne $environmentVariables) { $processParameters.EnvironmentVariables = $environmentVariables }

    try {
        $processResult = Invoke-WintainiumInstallerProcess @processParameters
        return New-WintainiumInstallationResult -Invocation $Invocation -ProcessResult $processResult
    }
    catch {
        return & $failure 'InstallerProcessBoundaryError' 'The controlled installer process boundary failed unexpectedly.'
    }
}
