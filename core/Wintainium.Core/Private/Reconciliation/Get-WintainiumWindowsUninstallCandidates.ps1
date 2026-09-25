function Get-WintainiumWindowsUninstallCandidates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [psobject]$Settings,

        [Parameter()]
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

            $subKeyPath = 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
            $hive = if ([string]$location.scope -eq 'machine') {
                [Microsoft.Win32.RegistryHive]::LocalMachine
            }
            elseif ([string]$location.scope -eq 'user') {
                [Microsoft.Win32.RegistryHive]::CurrentUser
            }
            else {
                throw [System.ArgumentException]::new("Unsupported Windows registry scope '$($location.scope)'.")
            }

            $view = if ([string]$location.scope -eq 'user') {
                [Microsoft.Win32.RegistryView]::Default
            }
            elseif ([string]$location.view -eq '64') {
                [Microsoft.Win32.RegistryView]::Registry64
            }
            elseif ([string]$location.view -eq '32') {
                [Microsoft.Win32.RegistryView]::Registry32
            }
            else {
                throw [System.ArgumentException]::new("Unsupported machine registry view '$($location.view)'.")
            }

            $baseKey = $null
            $uninstallKey = $null
            try {
                $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, $view)
                $uninstallKey = $baseKey.OpenSubKey($subKeyPath, $false)
                if ($null -eq $uninstallKey) {
                    return @()
                }

                foreach ($subKeyName in $uninstallKey.GetSubKeyNames()) {
                    $entryKey = $null
                    try {
                        $entryKey = $uninstallKey.OpenSubKey($subKeyName, $false)
                        if ($null -eq $entryKey) {
                            continue
                        }

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
                        if ($null -ne $entryKey) {
                            $entryKey.Dispose()
                        }
                    }
                }
            }
            finally {
                if ($null -ne $uninstallKey) {
                    $uninstallKey.Dispose()
                }
                if ($null -ne $baseKey) {
                    $baseKey.Dispose()
                }
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

        try {
            $entries = @(& $reader $location)
        }
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
                    'subkey' { $entry.SubKey }
                    'DisplayName' { $entry.DisplayName }
                    'Publisher' { $entry.Publisher }
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
                    DisplayName = if ($null -ne $entry.DisplayName) { [string]$entry.DisplayName } else { $null }
                    DisplayVersion = if ($null -ne $entry.DisplayVersion) { [string]$entry.DisplayVersion } else { $null }
                    Publisher = if ($null -ne $entry.Publisher) { [string]$entry.Publisher } else { $null }
                    InstallLocation = if ($null -ne $entry.InstallLocation) { [string]$entry.InstallLocation } else { $null }
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
