function Get-WintainiumApplicationRegistryIdentityCandidates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApplicationName,
        [AllowNull()][string]$Publisher,
        [string]$OperationId,
        [Parameter(DontShow)][AllowNull()][object[]]$RegistryEntries
    )

    # This command is discovery-only. Scores rank candidates for human review;
    # they are never consumed as installed-state matches and never change a manifest.
    $resolvedOperationId = if ([string]::IsNullOrWhiteSpace($OperationId)) { [guid]::NewGuid().ToString() } else { $OperationId }
    $errors = [System.Collections.Generic.List[object]]::new()
    $entries = [System.Collections.Generic.List[object]]::new()

    if ($null -ne $RegistryEntries) {
        foreach ($entry in @($RegistryEntries)) { if ($null -ne $entry) { $entries.Add($entry) } }
    }
    else {
        foreach ($location in @(
            [pscustomobject]@{ Scope='machine'; View='64'; Hive=[Microsoft.Win32.RegistryHive]::LocalMachine; RegistryView=[Microsoft.Win32.RegistryView]::Registry64 },
            [pscustomobject]@{ Scope='machine'; View='32'; Hive=[Microsoft.Win32.RegistryHive]::LocalMachine; RegistryView=[Microsoft.Win32.RegistryView]::Registry32 },
            [pscustomobject]@{ Scope='user'; View='native'; Hive=[Microsoft.Win32.RegistryHive]::CurrentUser; RegistryView=[Microsoft.Win32.RegistryView]::Default }
        )) {
            $baseKey = $null
            $uninstallKey = $null
            try {
                $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($location.Hive, $location.RegistryView)
                $uninstallKey = $baseKey.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Uninstall', $false)
                if ($null -eq $uninstallKey) { continue }
                foreach ($subKeyName in $uninstallKey.GetSubKeyNames()) {
                    $entryKey = $null
                    try {
                        $entryKey = $uninstallKey.OpenSubKey($subKeyName, $false)
                        if ($null -eq $entryKey) { continue }
                        $displayName = [string]$entryKey.GetValue('DisplayName', $null)
                        if ([string]::IsNullOrWhiteSpace($displayName)) { continue }
                        $entries.Add([pscustomobject]@{
                            Scope=$location.Scope
                            View=$location.View
                            SubKey=$subKeyName
                            DisplayName=$displayName
                            DisplayVersion=[string]$entryKey.GetValue('DisplayVersion', $null)
                            Publisher=[string]$entryKey.GetValue('Publisher', $null)
                            InstallLocation=[string]$entryKey.GetValue('InstallLocation', $null)
                        })
                    }
                    catch {
                        $errors.Add([pscustomobject]@{ Code='RegistryIdentityEntryReadFailed'; Scope=$location.Scope; View=$location.View; SubKey=$subKeyName; Message=$_.Exception.Message })
                    }
                    finally { if ($null -ne $entryKey) { $entryKey.Dispose() } }
                }
            }
            catch {
                $errors.Add([pscustomobject]@{ Code='RegistryIdentityLocationReadFailed'; Scope=$location.Scope; View=$location.View; Message=$_.Exception.Message })
            }
            finally {
                if ($null -ne $uninstallKey) { $uninstallKey.Dispose() }
                if ($null -ne $baseKey) { $baseKey.Dispose() }
            }
        }
    }

    $normalizedName = $ApplicationName.Trim()
    $genericTokens = @('microsoft','windows','application','software','setup','installer','desktop','program','utility','suite','version','for','the','and','interface','media','player','app')
    $nameTokens = @([regex]::Matches($normalizedName.ToLowerInvariant(), '[a-z0-9]+') | ForEach-Object Value | Where-Object { $_.Length -gt 1 -and $_ -notin $genericTokens } | Select-Object -Unique)
    $candidates = foreach ($entry in $entries) {
        $displayName = [string]$entry.DisplayName
        $subKey = [string]$entry.SubKey
        $entryPublisher = [string]$entry.Publisher
        $score = 0
        $reason = 'ReviewOnlyNameSimilarity'
        $confidence = 'ReviewOnly'

        if ($displayName -ieq $normalizedName) {
            $score = 100; $reason = 'ExactDisplayName'; $confidence = 'Strong'
        }
        elseif ($subKey -ieq $normalizedName) {
            $score = 95; $reason = 'ExactRegistrySubKey'; $confidence = 'Strong'
        }
        elseif ($displayName -match ('(?i)^' + [regex]::Escape($normalizedName) + '\s+\d+(?:\.\d+)*(?:[a-z])?$')) {
            $score = 90; $reason = 'CompleteNumericVersionSuffix'; $confidence = 'Strong'
        }
        elseif ($subKey -match ('(?i)^' + [regex]::Escape($normalizedName) + '\s+\d+(?:\.\d+)*(?:[a-z])?$')) {
            $score = 85; $reason = 'SubKeyVersionSuffix'; $confidence = 'Strong'
        }
        else {
            $displayTokens = @([regex]::Matches($displayName.ToLowerInvariant(), '[a-z0-9]+') | ForEach-Object Value | Where-Object { $_.Length -gt 1 -and $_ -notin $genericTokens } | Select-Object -Unique)
            $overlap = @($nameTokens | Where-Object { $_ -in $displayTokens }).Count
            if ($overlap -gt 0) {
                $score = [Math]::Min(35, 10 + ($overlap * 10))
                $reason = 'TokenOverlapRequiresConfirmation'
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($Publisher) -and
            -not [string]::IsNullOrWhiteSpace($entryPublisher) -and
            $Publisher.Trim() -ieq $entryPublisher.Trim()) {
            $score = [Math]::Min(100, $score + 15)
            if ($confidence -eq 'ReviewOnly') { $reason = 'PublisherAndNameSimilarityRequiresConfirmation' }
            elseif ($confidence -eq 'Strong') { $reason += '+PublisherCorroborated' }
        }

        if ($score -gt 0) {
            [pscustomobject][ordered]@{
                Scope=if ($entry.PSObject.Properties['Scope']) { [string]$entry.Scope } else { $null }
                View=if ($entry.PSObject.Properties['View']) { [string]$entry.View } else { $null }
                DisplayName=$displayName
                DisplayVersion=if ($entry.PSObject.Properties['DisplayVersion']) { [string]$entry.DisplayVersion } else { $null }
                Publisher=$entryPublisher
                InstallLocation=if ($entry.PSObject.Properties['InstallLocation']) { [string]$entry.InstallLocation } else { $null }
                RegistrySubKey=$subKey
                Score=$score
                Confidence=$confidence
                Reason=$reason
                RequiresUserConfirmation=$true
            }
        }
    }

    $orderedCandidates = @($candidates | Sort-Object -Property @{Expression='Score';Descending=$true}, @{Expression='DisplayName';Descending=$false})
    [pscustomobject][ordered]@{
        OperationId=$resolvedOperationId
        IsSuccessful=($errors.Count -eq 0)
        Status=if ($orderedCandidates.Count -gt 0) { 'CandidatesFound' } elseif ($errors.Count -gt 0) { 'Incomplete' } else { 'NoCandidates' }
        ApplicationName=$normalizedName
        CandidateCount=$orderedCandidates.Count
        Candidates=@($orderedCandidates | Select-Object -First 25)
        Errors=$errors.ToArray()
        Warnings=@([pscustomobject]@{
            Code='RegistryIdentityDiscoveryIsNonAuthoritative'
            Message='These ranked candidates are suggestions for explicit user confirmation only. They do not alter manifests or installed-state matching.'
        })
    }
}
