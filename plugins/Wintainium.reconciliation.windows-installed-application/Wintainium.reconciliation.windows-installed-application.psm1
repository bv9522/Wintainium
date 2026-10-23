Set-StrictMode -Version Latest

function Get-WintainiumWindowsSettingValue {
    param(
        [Parameter(Mandatory)] [object]$Object,
        [Parameter(Mandatory)] [string]$Name
    )
    if ($Object -is [System.Collections.IDictionary]) { return $Object[$Name] }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -ne $property) { return $property.Value }
    return $null
}

function Get-WintainiumWindowsInstalledApplicationCandidates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]$Settings,
        [scriptblock]$RegistryReader
    )

    $registry = Get-WintainiumWindowsSettingValue -Object $Settings -Name 'registry'
    if ($null -eq $registry) { throw [System.ArgumentException]::new("Windows reconciliation settings must contain a 'registry' object.") }
    $locations = Get-WintainiumWindowsSettingValue -Object $registry -Name 'locations'
    if (@($locations).Count -eq 0) { throw [System.ArgumentException]::new("Windows reconciliation settings must contain at least one registry location.") }
    $matchMode = [string](Get-WintainiumWindowsSettingValue -Object $registry -Name 'matchMode')
    if ([string]::IsNullOrWhiteSpace($matchMode)) { $matchMode = 'all' }
    if ($matchMode -notin @('all','any')) { throw [System.ArgumentException]::new("Unsupported Windows registry match mode '$matchMode'.") }
    $match = Get-WintainiumWindowsSettingValue -Object $registry -Name 'match'
    if (@($match).Count -eq 0) { throw [System.ArgumentException]::new("Windows reconciliation settings must contain at least one registry match predicate.") }

    $matchableValues = @('subkey', 'DisplayName', 'Publisher')
    $predicates = foreach ($predicate in @($match)) {
        if ($null -eq $predicate) { throw [System.ArgumentException]::new('Registry match predicates must not be null.') }
        $value = Get-WintainiumWindowsSettingValue -Object $predicate -Name 'value'
        $equals = Get-WintainiumWindowsSettingValue -Object $predicate -Name 'equals'
        $matchType = [string](Get-WintainiumWindowsSettingValue -Object $predicate -Name 'matchType')
        if ([string]::IsNullOrWhiteSpace($matchType)) { $matchType = 'exact' }
        $aliases = @(Get-WintainiumWindowsSettingValue -Object $predicate -Name 'aliases' | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
        if ([string]::IsNullOrWhiteSpace([string]$value)) { throw [System.ArgumentException]::new("Each registry match predicate requires a non-empty 'value'.") }
        if ($matchableValues -notcontains [string]$value) { throw [System.ArgumentException]::new("Unsupported Windows uninstall registry match value '$value'.") }
        if ($null -eq $equals -or [string]::IsNullOrWhiteSpace([string]$equals)) { throw [System.ArgumentException]::new("Registry match predicate '$value' requires an 'equals' value.") }
        if ($matchType -notin @('exact', 'nameOrVersionSuffix')) { throw [System.ArgumentException]::new("Unsupported Windows registry match type '$matchType'.") }
        [pscustomobject]@{ Value = [string]$value; Equals = [string]$equals; MatchType = $matchType; Aliases = $aliases }
    }

    $reader = $RegistryReader
    if ($null -eq $reader) {
        $reader = {
            param($location)
            $subKeyPath = 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
            $scope = if ($location -is [System.Collections.IDictionary]) { [string]$location['scope'] } else { [string]$location.PSObject.Properties['scope'].Value }
            $locationView = if ($location -is [System.Collections.IDictionary]) { [string]$location['view'] } else { [string]$location.PSObject.Properties['view'].Value }
            $hive = switch ($scope) {
                'machine' { [Microsoft.Win32.RegistryHive]::LocalMachine; break }
                'user' { [Microsoft.Win32.RegistryHive]::CurrentUser; break }
                default { throw [System.ArgumentException]::new("Unsupported Windows registry scope '$scope'.") }
            }
            $view = switch ($scope) {
                'user' { [Microsoft.Win32.RegistryView]::Default; break }
                'machine' {
                    switch ($locationView) {
                        '64' { [Microsoft.Win32.RegistryView]::Registry64; break }
                        '32' { [Microsoft.Win32.RegistryView]::Registry32; break }
                        default { throw [System.ArgumentException]::new("Unsupported machine registry view '$locationView'.") }
                    }
                    break
                }
            }
            $baseKey = $null; $uninstallKey = $null
            try {
                $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, $view)
                $uninstallKey = $baseKey.OpenSubKey($subKeyPath, $false)
                if ($null -eq $uninstallKey) { return @() }
                foreach ($subKeyName in $uninstallKey.GetSubKeyNames()) {
                    $entryKey = $null
                    try {
                        $entryKey = $uninstallKey.OpenSubKey($subKeyName, $false)
                        if ($null -eq $entryKey) { continue }
                        [pscustomobject]@{
                            Scope = $scope; View = $locationView; SubKey = $subKeyName
                            DisplayName = $entryKey.GetValue('DisplayName', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                            DisplayVersion = $entryKey.GetValue('DisplayVersion', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                            Publisher = $entryKey.GetValue('Publisher', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                            InstallLocation = $entryKey.GetValue('InstallLocation', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                        }
                    } finally { if ($null -ne $entryKey) { $entryKey.Dispose() } }
                }
            } finally {
                if ($null -ne $uninstallKey) { $uninstallKey.Dispose() }
                if ($null -ne $baseKey) { $baseKey.Dispose() }
            }
        }.GetNewClosure()
    }

    $candidates = [System.Collections.Generic.List[object]]::new()
    $errors = [System.Collections.Generic.List[object]]::new()
    foreach ($location in @($locations)) {
        if ($null -eq $location) { throw [System.ArgumentException]::new('Registry locations must not be null.') }
        $scope = [string](Get-WintainiumWindowsSettingValue -Object $location -Name 'scope')
        $locationView = [string](Get-WintainiumWindowsSettingValue -Object $location -Name 'view')
        if ($scope -notin @('machine', 'user')) { throw [System.ArgumentException]::new("Unsupported Windows registry scope '$scope'.") }
        if ($scope -eq 'machine' -and $locationView -notin @('64', '32')) { throw [System.ArgumentException]::new("Machine registry location requires view '64' or '32'.") }
        if ($scope -eq 'user' -and $locationView -ne 'native') { throw [System.ArgumentException]::new("Current-user registry location requires view 'native'.") }
        try { $entries = @(& $reader $location) }
        catch {
            $errors.Add([pscustomobject]@{ Code='WindowsRegistryLocationReadFailed'; Message=$_.Exception.Message; Scope=$scope; View=$locationView }); continue
        }
        foreach ($entry in $entries) {
            $matches = if ($matchMode -eq 'any') { $false } else { $true }
            foreach ($predicate in $predicates) {
                $actual = switch ($predicate.Value) {
                    'subkey' { Get-WintainiumWindowsSettingValue -Object $entry -Name 'SubKey' }
                    'DisplayName' { Get-WintainiumWindowsSettingValue -Object $entry -Name 'DisplayName' }
                    'Publisher' { Get-WintainiumWindowsSettingValue -Object $entry -Name 'Publisher' }
                }
                if ($actual -is [System.Array]) {
                    $matches = $false
                    $errors.Add([pscustomobject]@{ Code='WindowsRegistryValueMalformed'; Message="Registry value '$($predicate.Value)' for uninstall entry '$($entry.SubKey)' is not a scalar value."; Scope=$scope; View=$locationView; SubKey=[string]$entry.SubKey })
                    break
                }
                $identityNames = @($predicate.Equals) + @($predicate.Aliases)
                $predicateMatches = $false
                foreach ($identityName in $identityNames) {
                    if ([string]$actual -ieq [string]$identityName) {
                        $predicateMatches = $true
                        break
                    }
                    # Controlled normalization only accepts a complete, whitespace-delimited
                    # numeric version suffix (optionally followed by one release letter).
                    # It does not accept arbitrary substrings, architecture tags, or extra words.
                    if ($predicate.MatchType -eq 'nameOrVersionSuffix' -and
                        [string]$actual -match ('(?i)^' + [regex]::Escape([string]$identityName) + '\\s+\\d+(?:\\.\\d+)*(?:[a-z])?
                    if ($predicateMatches) { $matches = $true; break }
                }
                elseif (-not $predicateMatches) { $matches = $false; break }
            }
            if ($matches) {
                $candidates.Add([pscustomobject]@{
                    Scope = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'Scope')
                    View = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'View')
                    SubKey = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'SubKey')
                    DisplayName = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'DisplayName')
                    DisplayVersion = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'DisplayVersion')
                    Publisher = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'Publisher')
                    InstallLocation = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'InstallLocation')
                    EvidenceSource = 'WindowsUninstallRegistry'
                })
            }
        }
    }
    [pscustomobject]@{ IsSuccessful=($errors.Count -eq 0); Candidates=@($candidates); Errors=@($errors) }
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
        if($candidate.DisplayVersion){$evidence.Version=$candidate.DisplayVersion;$evidence.VersionSource='Registry'}
        if($candidate.InstallLocation){$evidence.InstallationLocation=$candidate.InstallLocation}
        return & $base $true 'Reconciled' ([pscustomobject]$evidence) @() $warnings
    } catch {
        return & $base $false 'InvalidSettings' $null @([pscustomobject]@{Code='WindowsReconciliationSettingsInvalid';Message=$_.Exception.Message}) @()
    }
}

Export-ModuleMember -Function Invoke-WintainiumReconciliation
)) {
                        $predicateMatches = $true
                        break
                    }
                }
                if ($matchMode -eq 'any') {
                    if ($predicateMatches) { $matches = $true; break }
                }
                elseif (-not $predicateMatches) { $matches = $false; break }
            }
            if ($matches) {
                $candidates.Add([pscustomobject]@{
                    Scope = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'Scope')
                    View = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'View')
                    SubKey = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'SubKey')
                    DisplayName = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'DisplayName')
                    DisplayVersion = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'DisplayVersion')
                    Publisher = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'Publisher')
                    InstallLocation = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'InstallLocation')
                    EvidenceSource = 'WindowsUninstallRegistry'
                })
            }
        }
    }
    [pscustomobject]@{ IsSuccessful=($errors.Count -eq 0); Candidates=@($candidates); Errors=@($errors) }
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
        if($candidate.DisplayVersion){$evidence.Version=$candidate.DisplayVersion;$evidence.VersionSource='Registry'}
        if($candidate.InstallLocation){$evidence.InstallationLocation=$candidate.InstallLocation}
        return & $base $true 'Reconciled' ([pscustomobject]$evidence) @() $warnings
    } catch {
        return & $base $false 'InvalidSettings' $null @([pscustomobject]@{Code='WindowsReconciliationSettingsInvalid';Message=$_.Exception.Message}) @()
    }
}

Export-ModuleMember -Function Invoke-WintainiumReconciliation
