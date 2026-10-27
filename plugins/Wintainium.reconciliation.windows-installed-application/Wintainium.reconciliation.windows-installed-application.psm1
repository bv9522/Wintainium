function Get-WintainiumWindowsExecutableVersion {
    [CmdletBinding()]
    param(
        [AllowNull()] [string]$InstallationLocation,
        [AllowNull()] [string]$DisplayName
    )

    if ([string]::IsNullOrWhiteSpace($InstallationLocation) -or
        -not [System.IO.Path]::IsPathFullyQualified($InstallationLocation) -or
        -not (Test-Path -LiteralPath $InstallationLocation -PathType Container) -or
        [string]::IsNullOrWhiteSpace($DisplayName)) {
        return $null
    }

    # Portable ZIP updates often replace an application's executable without
    # updating its uninstall-registry DisplayVersion. Use executable metadata
    # only when its filename unambiguously matches the registered display name
    # after removing a conventional trailing numeric version suffix.
    $baseName = [regex]::Replace($DisplayName.Trim(), '\s+\d+(?:\.\d+)*(?:[a-z])?$', '').Trim()
    if ([string]::IsNullOrWhiteSpace($baseName) -or $baseName -match '[\\/:*?"<>|]') {
        return $null
    }

    $executablePath = Join-Path -Path ([System.IO.Path]::GetFullPath($InstallationLocation)) -ChildPath ($baseName + '.exe')
    if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
        return $null
    }

    try {
        $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($executablePath)
        $version = [string]$versionInfo.ProductVersion
        if ([string]::IsNullOrWhiteSpace($version)) { $version = [string]$versionInfo.FileVersion }
        if ([string]::IsNullOrWhiteSpace($version)) { return $null }
        [pscustomobject][ordered]@{ Version=$version; Path=$executablePath }
    }
    catch {
        return $null
    }
}

function Invoke-WintainiumReconciliation {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Request)
    $operationId = [string]$Request.OperationId
    $applicationId = [string]$Request.ApplicationId
    $base = {
        param([bool]$successful,[string]$status,[object]$evidence,[object[]]$errors,[object[]]$warnings)
        [pscustomobject][ordered]@{ OperationId=$operationId; IsSuccessful=$successful; Status=$status; Evidence=$evidence; Errors=@($errors); Warnings=@($warnings); LogEvents=@() }
    }
    try {
        if ($null -eq $Request.Manifest) { return & $base $false 'InvalidSettings' $null @([pscustomobject]@{Code='WindowsReconciliationSettingsMissing';Message='The manifest must provide reconciliation.settings for the Windows installed-application reconciler.'}) @() }
        $reconciliation = $Request.Manifest.Reconciliation
        $settings = if ($reconciliation -is [System.Collections.IDictionary]) { $reconciliation['settings'] } elseif ($null -ne $reconciliation.PSObject.Properties['settings']) { $reconciliation.settings } else { $null }
        if ($null -eq $settings) { return & $base $false 'InvalidSettings' $null @([pscustomobject]@{Code='WindowsReconciliationSettingsMissing';Message='The manifest must provide reconciliation.settings for the Windows installed-application reconciler.'}) @() }
        $observation = Get-WintainiumWindowsInstalledApplicationCandidates -Settings $settings
        $warnings = @($observation.Errors | ForEach-Object {
            [pscustomobject]@{
                Code = [string]$_.Code
                Message = [string]$_.Message
                OperationId = $operationId
                Scope = if ($_.PSObject.Properties['Scope']) { [string]$_.Scope } else { $null }
                View = if ($_.PSObject.Properties['View']) { [string]$_.View } else { $null }
            }
        })
        $candidateCount = @($observation.Candidates).Count
        $registry = Get-WintainiumWindowsSettingValue -Object $settings -Name 'registry'
        $matchMode = [string](Get-WintainiumWindowsSettingValue -Object $registry -Name 'matchMode')
        if ([string]::IsNullOrWhiteSpace($matchMode)) { $matchMode = 'all' }
        $locationCount = @(Get-WintainiumWindowsSettingValue -Object $registry -Name 'locations').Count
        $readFailureCount = @($observation.Errors | Where-Object Code -eq 'WindowsRegistryLocationReadFailed').Count
        if ($candidateCount -eq 0) {
            $installationState = if ($observation.IsSuccessful) { 'NotInstalled' } else { 'Unknown' }
            $status = if ($observation.IsSuccessful) { 'Reconciled' } else { 'Unknown' }
            if (-not $observation.IsSuccessful) {
                $warnings += [pscustomobject]@{
                    Code = 'WindowsReconciliationEvidenceIncomplete'
                    Message = 'No matching uninstall registration was found, and one or more registry observations failed. Wintainium cannot safely conclude that the application is not installed.'
                    OperationId = $operationId
                    CandidateCount = $candidateCount
                    MatchMode = $matchMode
                    RegistryLocationCount = $locationCount
                    RegistryReadFailureCount = $readFailureCount
                }
            }
            $evidence=[pscustomobject][ordered]@{ApplicationId=$applicationId;InstallationState=$installationState;EvidenceSource='WindowsUninstallRegistry'}
            return & $base $true $status $evidence @() $warnings
        }
        if ($candidateCount -gt 1) {
            $evidence=[pscustomobject][ordered]@{ApplicationId=$applicationId;InstallationState='Unknown';EvidenceSource='WindowsUninstallRegistry'}
            $ambiguity=[pscustomobject]@{
                Code = 'WindowsReconciliationAmbiguous'
                Message = 'Multiple uninstall registrations matched the configured application identity; Wintainium did not choose one.'
                OperationId = $operationId
                CandidateCount = $candidateCount
                MatchMode = $matchMode
                RegistryLocationCount = $locationCount
                RegistryReadFailureCount = $readFailureCount
            }
            return & $base $true 'Unknown' $evidence @() (@($warnings)+$ambiguity)
        }
        $candidate=@($observation.Candidates)[0]
        $evidence=[ordered]@{ApplicationId=$applicationId;InstallationState='Installed';EvidenceSource='WindowsUninstallRegistry'}
        $version = if (-not [string]::IsNullOrWhiteSpace([string]$candidate.DisplayVersion)) { [string]$candidate.DisplayVersion } else { $null }
        $versionSource = if ($null -ne $version) { 'Registry' } else { $null }
        $executableVersion = Get-WintainiumWindowsExecutableVersion -InstallationLocation ([string]$candidate.InstallLocation) -DisplayName ([string]$candidate.DisplayName)
        if ($null -ne $executableVersion -and -not [string]::IsNullOrWhiteSpace([string]$executableVersion.Version)) {
            $version = [string]$executableVersion.Version
            $versionSource = 'ExecutableFileVersion'
        }
        if ($null -ne $version) { $evidence.Version=$version; $evidence.VersionSource=$versionSource }
        if($candidate.InstallLocation){$evidence.InstallationLocation=$candidate.InstallLocation}
        return & $base $true 'Reconciled' ([pscustomobject]$evidence) @() $warnings
    } catch {
        return & $base $false 'InvalidSettings' $null @([pscustomobject]@{Code='WindowsReconciliationSettingsInvalid';Message=$_.Exception.Message}) @()
    }
}

Export-ModuleMember -Function Invoke-WintainiumReconciliation
