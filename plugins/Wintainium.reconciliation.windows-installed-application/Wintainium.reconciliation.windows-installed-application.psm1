Set-StrictMode -Version Latest

function Get-WintainiumWindowsInstalledApplicationCandidates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Settings,

        [scriptblock]$RegistryReader
    )

    if ($null -eq $Settings.PSObject.Properties['registry'] -or $null -eq $Settings.registry) {
        throw [System.ArgumentException]::new("Windows reconciliation settings must contain a 'registry' object.")
    }

    if ($null -eq $Settings.registry.PSObject.Properties['locations'] -or @($Settings.registry.locations).Count -eq 0) {
        throw [System.ArgumentException]::new("Windows reconciliation settings must contain at least one registry location.")
    }

    if ($null -eq $Settings.registry.PSObject.Properties['match'] -or @($Settings.registry.match).Count -eq 0) {
        throw [System.ArgumentException]::new("Windows reconciliation settings must contain at least one registry match predicate.")
    }

    $matchableValues = @('subkey', 'DisplayName', 'Publisher')
    $predicates = foreach ($predicate in @($Settings.registry.match)) {
        if ($null -eq $predicate) {
            throw [System.ArgumentException]::new('Registry match predicates must not be null.')
        }
        if ($null -eq $predicate.PSObject.Properties['value'] -or [string]::IsNullOrWhiteSpace([string]$predicate.value)) {
            throw [System.ArgumentException]::new("Each registry match predicate requires a non-empty 'value'.")
        }
        if ($matchableValues -notcontains [string]$predicate.value) {
            throw [System.ArgumentException]::new("Unsupported Windows uninstall registry match value '$($predicate.value)'.")
        }
        if ($null -eq $predicate.PSObject.Properties['equals']) {
            throw [System.ArgumentException]::new("Registry match predicate '$($predicate.value)' requires an 'equals' value.")
        }
        [pscustomobject]@{
            Value = [string]$predicate.value
            Equals = [string]$predicate.equals
        }
    }

    $reader = $RegistryReader
    if ($null -eq $reader) {
        $reader = {
            param($location)

            $subKeyPath = 'SoftwareMicrosoftWindowsCurrentVersionUninstall'
            $hive = switch ([string]$location.scope) {
                'machine' { [Microsoft.Win32.RegistryHive]::LocalMachine; break }
                'user' { [Microsoft.Win32.RegistryHive]::CurrentUser; break }
                default { throw [System.ArgumentException]::new("Unsupported Windows registry scope '$($location.scope)'.") }
            }

            $view = switch ([string]$location.scope) {
                'user' { [Microsoft.Win32.RegistryView]::Default; break }
                'machine' {
                    switch ([string]$location.view) {
                        '64' { [Microsoft.Win32.RegistryView]::Registry64; break }
                        '32' { [Microsoft.Win32.RegistryView]::Registry32; break }
                        default { throw [System.ArgumentException]::new("Unsupported machine registry view '$($location.view)'.") }
                    }
                    break
                }
            }

            $baseKey = $null
            $uninstallKey = $null
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
                            Scope = [string]$location.scope
                            View = [string]$location.view
                            SubKey = $subKeyName
                            DisplayName = $entryKey.GetValue('DisplayName', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                            DisplayVersion = $entryKey.GetValue('DisplayVersion', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                            Publisher = $entryKey.GetValue('Publisher', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                            InstallLocation = $entryKey.GetValue('InstallLocation', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                        }
                    }
                    finally {
                        if ($null -ne $entryKey) { $entryKey.Dispose() }
                    }
                }
            }
            finally {
                if ($null -ne $uninstallKey) { $uninstallKey.Dispose() }
                if ($null -ne $baseKey) { $baseKey.Dispose() }
            }
        }.GetNewClosure()
    }

    $candidates = [System.Collections.Generic.List[object]]::new()
    $errors = [System.Collections.Generic.List[object]]::new()

    foreach ($location in @($Settings.registry.locations)) {
        if ($null -eq $location) {
            throw [System.ArgumentException]::new('Registry locations must not be null.')
        }
        if ([string]$location.scope -notin @('machine', 'user')) {
            throw [System.ArgumentException]::new("Unsupported Windows registry scope '$($location.scope)'.")
        }
        if ([string]$location.scope -eq 'machine' -and [string]$location.view -notin @('64', '32')) {
            throw [System.ArgumentException]::new("Machine registry location requires view '64' or '32'.")
        }
        if ([string]$location.scope -eq 'user' -and [string]$location.view -ne 'native') {
            throw [System.ArgumentException]::new("Current-user registry location requires view 'native'.")
        }

        try { $entries = @(& $reader $location) }
        catch {
            $errors.Add([pscustomobject]@{
                Code = 'WindowsRegistryLocationReadFailed'
                Message = $_.Exception.Message
                Scope = [string]$location.scope
                View = [string]$location.view
            })
            continue
        }

        foreach ($entry in $entries) {
            $matches = $true
            foreach ($predicate in $predicates) {
                $actual = switch ($predicate.Value) {
                    'subkey' { if ($entry.PSObject.Properties['SubKey']) { $entry.SubKey } }
                    'DisplayName' { if ($entry.PSObject.Properties['DisplayName']) { $entry.DisplayName } }
                    'Publisher' { if ($entry.PSObject.Properties['Publisher']) { $entry.Publisher } }
                }

                if ($actual -is [System.Array]) {
                    $matches = $false
                    $errors.Add([pscustomobject]@{
                        Code = 'WindowsRegistryValueMalformed'
                        Message = "Registry value '$($predicate.Value)' for uninstall entry '$($entry.SubKey)' is not a scalar value."
                        Scope = [string]$location.scope
                        View = [string]$location.view
                        SubKey = [string]$entry.SubKey
                    })
                    break
                }

                if ([string]$actual -ine $predicate.Equals) {
                    $matches = $false
                    break
                }
            }

            if ($matches) {
                $candidates.Add([pscustomobject]@{
                    Scope = [string]$entry.Scope
                    View = [string]$entry.View
                    SubKey = [string]$entry.SubKey
                    DisplayName = if ($null -ne $entry.PSObject.Properties['DisplayName'] -and $null -ne $entry.DisplayName) { [string]$entry.DisplayName } else { $null }
                    DisplayVersion = if ($null -ne $entry.PSObject.Properties['DisplayVersion'] -and $null -ne $entry.DisplayVersion) { [string]$entry.DisplayVersion } else { $null }
                    Publisher = if ($null -ne $entry.PSObject.Properties['Publisher'] -and $null -ne $entry.Publisher) { [string]$entry.Publisher } else { $null }
                    InstallLocation = if ($null -ne $entry.PSObject.Properties['InstallLocation'] -and $null -ne $entry.InstallLocation) { [string]$entry.InstallLocation } else { $null }
                    EvidenceSource = 'WindowsUninstallRegistry'
                })
            }
        }
    }

    [pscustomobject]@{
        IsSuccessful = ($errors.Count -eq 0)
        Candidates = @($candidates)
        Errors = @($errors)
    }
}

function Invoke-WintainiumReconciliation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Request
    )

    $operationId = [string]$Request.OperationId
    $applicationId = [string]$Request.ApplicationId
    $base = {
        param([bool]$successful,[string]$status,[object]$evidence,[object[]]$errors,[object[]]$warnings)
        [pscustomobject][ordered]@{
            OperationId = $operationId
            IsSuccessful = $successful
            Status = $status
            Evidence = $evidence
            Errors = @($errors)
            Warnings = @($warnings)
            LogEvents = @()
        }
    }

    try {
        if ($null -eq $Request.Manifest -or $null -eq $Request.Manifest.PSObject.Properties['reconciliation'] -or
            $null -eq $Request.Manifest.reconciliation -or
            $null -eq $Request.Manifest.reconciliation.PSObject.Properties['settings']) {
            return & $base $false 'InvalidSettings' $null @([pscustomobject]@{
                Code = 'WindowsReconciliationSettingsMissing'
                Message = 'The manifest must provide reconciliation.settings for the Windows installed-application reconciler.'
            }) @()
        }

        $settings = $Request.Manifest.reconciliation.settings
        $observation = Get-WintainiumWindowsInstalledApplicationCandidates -Settings $settings

        $warnings = @($observation.Errors | ForEach-Object {
            [pscustomobject]@{
                Code = [string]$_.Code
                Message = [string]$_.Message
                OperationId = $operationId
            }
        })

        if (@($observation.Candidates).Count -eq 0) {
            $evidence = [pscustomobject][ordered]@{
                ApplicationId = $applicationId
                InstallationState = if ($observation.IsSuccessful) { 'NotInstalled' } else { 'Unknown' }
                EvidenceSource = 'WindowsUninstallRegistry'
            }
            return & $base $true (if ($observation.IsSuccessful) { 'Reconciled' } else { 'Unknown' }) $evidence @() $warnings
        }

        if (@($observation.Candidates).Count -gt 1) {
            $evidence = [pscustomobject][ordered]@{
                ApplicationId = $applicationId
                InstallationState = 'Unknown'
                EvidenceSource = 'WindowsUninstallRegistry'
            }
            $ambiguity = [pscustomobject]@{
                Code = 'WindowsReconciliationAmbiguous'
                Message = "Multiple uninstall registrations matched application '$applicationId'."
                OperationId = $operationId
            }
            return & $base $true 'Unknown' $evidence @() (@($warnings) + $ambiguity)
        }

        $candidate = @($observation.Candidates)[0]
        $evidence = [ordered]@{
            ApplicationId = $applicationId
            InstallationState = 'Installed'
            EvidenceSource = 'WindowsUninstallRegistry'
        }
        if ($candidate.DisplayVersion) {
            $evidence.Version = $candidate.DisplayVersion
            $evidence.VersionSource = 'Registry'
        }
        if ($candidate.InstallLocation) { $evidence.InstallationLocation = $candidate.InstallLocation }

        return & $base $true 'Reconciled' ([pscustomobject]$evidence) @() $warnings
    }
    catch {
        return & $base $false 'InvalidSettings' $null @([pscustomobject]@{
            Code = 'WindowsReconciliationSettingsInvalid'
            Message = $_.Exception.Message
        }) @()
    }
}

Export-ModuleMember -Function Invoke-WintainiumReconciliation
