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

function ConvertTo-WintainiumIdentityName {
    [CmdletBinding()]
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $normalized = $Value.Trim().ToLowerInvariant()
    $normalized = [regex]::Replace($normalized, '\s+\d+(?:\.\d+)*(?:[a-z])?$', '')
    $normalized = [regex]::Replace($normalized, '\b(?:x64|x86|x32|arm64|64[- ]bit|32[- ]bit)\b', ' ')
    $normalized = [regex]::Replace($normalized, '[^a-z0-9]+', ' ')
    return [regex]::Replace($normalized.Trim(), '\s+', ' ')
}

function Get-WintainiumIdentityTokens {
    param([AllowNull()][string]$Value)
    $ignored = @('microsoft','windows','application','software','setup','installer','desktop','program','utility','suite','version','ver','for','the','and','interface','official','download','files','app')
    return @(([string](ConvertTo-WintainiumIdentityName -Value $Value) -split ' ') | Where-Object { $_.Length -gt 1 -and $_ -notin $ignored } | Select-Object -Unique)
}

function Get-WintainiumWindowsInstalledApplicationCandidates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]$Settings,
        [AllowNull()][string]$ApplicationName,
        [AllowNull()][string]$ApplicationPublisher,
        [AllowNull()][string]$ApplicationHomepage,
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
        if ([string]::IsNullOrWhiteSpace($matchType)) {
            # Older manifests predate the explicit matchType field. Apply only
            # the conservative, anchored version-suffix rule to name-bearing fields.
            $matchType = if ([string]$value -in @('DisplayName','subkey')) { 'nameOrVersionSuffix' } else { 'exact' }
        }
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
                            UninstallString = $entryKey.GetValue('UninstallString', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                            QuietUninstallString = $entryKey.GetValue('QuietUninstallString', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                            URLInfoAbout = $entryKey.GetValue('URLInfoAbout', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                            HelpLink = $entryKey.GetValue('HelpLink', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                            InstallSource = $entryKey.GetValue('InstallSource', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                            WindowsInstaller = $entryKey.GetValue('WindowsInstaller', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
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
    $allEntries = [System.Collections.Generic.List[object]]::new()
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
            $allEntries.Add($entry)
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
                        [string]$actual -match ('(?i)^' + [regex]::Escape([string]$identityName) + '\s+\d+(?:\.\d+)*(?:[a-z])?$')) {
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
    # Explicit manifest predicates remain authoritative. Only when they find no
    # candidate do we evaluate the canonical manifest name against the registry
    # inventory. Weak/ambiguous results remain non-authoritative.
    if ($candidates.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($ApplicationName)) {
        $fullName = ConvertTo-WintaniumIdentityName -Value $ApplicationName
        $primaryName = ([regex]::Split($ApplicationName.Trim(), '[,;|:]', 2)[0]).Trim()
        $primaryNormalized = ConvertTo-WintaniumIdentityName -Value $primaryName
        $primaryTokens = @(Get-WintaniumIdentityTokens -Value $primaryName)
        $fullTokens = @(Get-WintaniumIdentityTokens -Value $ApplicationName)
        $publisherNormalized = ConvertTo-WintaniumIdentityName -Value $ApplicationPublisher
        if ($publisherNormalized -match 'sourceforge|github|browse files|download page|website') { $publisherNormalized = '' }

        $scored = foreach ($entry in $allEntries) {
            $displayName = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'DisplayName')
            $subKey = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'SubKey')
            $entryPublisher = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'Publisher')
            $displayNormalized = ConvertTo-WintaniumIdentityName -Value $displayName
            $subKeyNormalized = ConvertTo-WintaniumIdentityName -Value $subKey
            $displayTokens = @(Get-WintaniumIdentityTokens -Value $displayName)
            $subKeyTokens = @(Get-WintaniumIdentityTokens -Value $subKey)
            $score = 0
            $evidence = [System.Collections.Generic.List[string]]::new()

            if ($displayNormalized -eq $fullName -and $fullName) {
                $score = 100; $evidence.Add('NormalizedDisplayNameExact')
            }
            elseif ($subKeyNormalized -eq $fullName -and $fullName) {
                $score = 95; $evidence.Add('NormalizedRegistrySubKeyExact')
            }
            elseif ($primaryNormalized -and $displayNormalized -eq $primaryNormalized) {
                $score = 90; $evidence.Add('PrimaryProductPhraseExact')
            }
            elseif ($primaryNormalized -and $subKeyNormalized -eq $primaryNormalized) {
                $score = 88; $evidence.Add('PrimaryProductSubKeyExact')
            }
            else {
                # The leading product phrase carries more weight than comma-delimited
                # descriptors such as "interface Equalizer APO". Arbitrary substrings
                # never qualify as a confirmed match.
                $displaySubset = $displayTokens.Count -gt 0 -and @($displayTokens | Where-Object { $_ -notin $primaryTokens }).Count -eq 0
                $subKeySubset = $subKeyTokens.Count -gt 0 -and @($subKeyTokens | Where-Object { $_ -notin $primaryTokens }).Count -eq 0
                if ($displaySubset) {
                    $coverage = [double]$displayTokens.Count / [Math]::Max(1, $primaryTokens.Count)
                    $score = [Math]::Max($score, [int](48 + (22 * $coverage)))
                    $evidence.Add('MeaningfulDisplayNameTokensContainedInPrimaryPhrase')
                }
                if ($subKeySubset) {
                    $coverage = [double]$subKeyTokens.Count / [Math]::Max(1, $primaryTokens.Count)
                    $score = [Math]::Max($score, [int](45 + (20 * $coverage)))
                    $evidence.Add('MeaningfulSubKeyTokensContainedInPrimaryPhrase')
                }
                $overlap = @($fullTokens | Where-Object { $_ -in $displayTokens }).Count
                if ($overlap -gt 0) {
                    $score = [Math]::Max($score, [Math]::Min(42, 18 + (8 * $overlap)))
                    $evidence.Add('SharedMeaningfulNameTokens')
                }
            }

            if ($publisherNormalized -and (ConvertTo-WintaniumIdentityName -Value $entryPublisher) -eq $publisherNormalized) {
                $score = [Math]::Min(100, $score + 18)
                $evidence.Add('PublisherCorroborated')
            }
            $installLocation = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'InstallLocation')
            if (-not [string]::IsNullOrWhiteSpace($installLocation)) {
                $folderName = [System.IO.Path]::GetFileName($installLocation.TrimEnd('\','/'))
                $folderNormalized = ConvertTo-WintaniumIdentityName -Value $folderName
                if ($folderNormalized -and ($folderNormalized -eq $displayNormalized -or $folderNormalized -eq $subKeyNormalized)) {
                    $score = [Math]::Min(100, $score + 8)
                    $evidence.Add('InstallLocationNameCorroborated')
                }
            }
            if ($displayNormalized -and $displayNormalized -eq $subKeyNormalized) {
                $score = [Math]::Min(100, $score + 5)
                $evidence.Add('DisplayNameAndSubKeyConsistent')
            }
            $uninstallString = [string](Get-WintaniumWindowsSettingValue -Object $entry -Name 'UninstallString')
            if ($displayTokens.Count -gt 0 -and $uninstallString) {
                $commandTokens = @(Get-WintaniumIdentityTokens -Value $uninstallString)
                if (@($displayTokens | Where-Object { $_ -in $commandTokens }).Count -gt 0) {
                    $score = [Math]::Min(100, $score + 5)
                    $evidence.Add('UninstallCommandNameCorroborated')
                }
            }
            if ($score -gt 0) {
                [pscustomobject][ordered]@{
                    Scope = [string](Get-WintaniumWindowsSettingValue -Object $entry -Name 'Scope')
                    View = [string](Get-WintaniumWindowsSettingValue -Object $entry -Name 'View')
                    SubKey = $subKey
                    DisplayName = $displayName
                    DisplayVersion = [string](Get-WintaniumWindowsSettingValue -Object $entry -Name 'DisplayVersion')
                    Publisher = $entryPublisher
                    InstallLocation = $installLocation
                    UninstallString = $uninstallString
                    QuietUninstallString = [string](Get-WintaniumWindowsSettingValue -Object $entry -Name 'QuietUninstallString')
                    URLInfoAbout = [string](Get-WintaniumWindowsSettingValue -Object $entry -Name 'URLInfoAbout')
                    HelpLink = [string](Get-WintaniumWindowsSettingValue -Object $entry -Name 'HelpLink')
                    InstallSource = [string](Get-WintaniumWindowsSettingValue -Object $entry -Name 'InstallSource')
                    WindowsInstaller = [string](Get-WintaniumWindowsSettingValue -Object $entry -Name 'WindowsInstaller')
                    EvidenceSource = 'WindowsUninstallRegistry'
                    IdentityScore = $score
                    IdentityConfidence = if ($score -ge 70) { 'Strong' } else { 'ReviewOnly' }
                    IdentityEvidence = @($evidence)
                }
            }
        }
        $orderedScored = @($scored | Sort-Object -Property @{Expression='IdentityScore';Descending=$true}, @{Expression='DisplayName';Descending=$false})
        if ($orderedScored.Count -gt 0) {
            $topScore = [int]$orderedScored[0].IdentityScore
            $secondScore = if ($orderedScored.Count -gt 1) { [int]$orderedScored[1].IdentityScore } else { 0 }
            if ($topScore -ge 70 -and ($orderedScored.Count -eq 1 -or ($topScore - $secondScore) -ge 15)) {
                $winner = $orderedScored[0]
                $winner.IdentityConfidence = 'Strong'
                $candidates.Add($winner)
            }
            else {
                foreach ($candidate in @($orderedScored | Where-Object { $_.IdentityScore -ge 30 } | Select-Object -First 10)) {
                    $candidate.IdentityConfidence = 'ReviewOnly'
                    $candidates.Add($candidate)
                }
            }
        }
    }

    [pscustomobject]@{ IsSuccessful=($errors.Count -eq 0); Candidates=@($candidates); Errors=@($errors) }
}

function ConvertTo-WintainiumComparableExecutableVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$Version,
        [AllowNull()] [string]$RegistryVersion
    )

    # Windows file resources sometimes append a fourth build/revision component
    # while the publisher's release feed uses three components (for example,
    # file 1.21.0.207 vs release 1.21.0). When the executable has exactly one
    # more numeric component than the stale registry version, discard only that
    # extra component so the values remain comparable.
    if ($Version -match '^\d+(?:\.\d+){3}$' -and
        $RegistryVersion -match '^\d+(?:\.\d+){2}$') {
        return ($Version -split '\.')[0..2] -join '.'
    }

    return $Version
}

function Get-WintainiumWindowsExecutableVersion {
    [CmdletBinding()]
    param(
        [AllowNull()] [string]$InstallationLocation,
        [AllowNull()] [string]$DisplayName,
        [AllowNull()] [string]$RegistryVersion
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

        $version = ConvertTo-WintainiumComparableExecutableVersion -Version $version -RegistryVersion $RegistryVersion
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
        $applicationName = [string](Get-WintainiumWindowsSettingValue -Object $Request.Manifest -Name 'name')
        $applicationPublisher = [string](Get-WintainiumWindowsSettingValue -Object $Request.Manifest -Name 'publisher')
        $applicationHomepage = [string](Get-WintaniumWindowsSettingValue -Object $Request.Manifest -Name 'homepage')
        $observation = Get-WintainiumWindowsInstalledApplicationCandidates -Settings $settings -ApplicationName $applicationName -ApplicationPublisher $applicationPublisher -ApplicationHomepage $applicationHomepage
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
        if ($candidateCount -eq 1 -and [string]$observation.Candidates[0].IdentityConfidence -eq 'ReviewOnly') {
            $candidate = @($observation.Candidates)[0]
            $evidence=[pscustomobject][ordered]@{ApplicationId=$applicationId;InstallationState='Unknown';EvidenceSource='WindowsUninstallRegistry'}
            $warnings += [pscustomobject]@{
                Code = 'WindowsReconciliationIdentityRequiresConfirmation'
                Message = 'Registry identity evidence is suggestive but does not meet the confidence and separation thresholds required to confirm the installed application.'
                OperationId = $operationId
                CandidateCount = 1
                CandidateDisplayName = [string]$candidate.DisplayName
                CandidateRegistrySubKey = [string]$candidate.SubKey
                IdentityScore = [int]$candidate.IdentityScore
                IdentityEvidence = @($candidate.IdentityEvidence)
            }
            return & $base $true 'Unknown' $evidence @() $warnings
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
        $executableVersion = Get-WintainiumWindowsExecutableVersion -InstallationLocation ([string]$candidate.InstallLocation) -DisplayName ([string]$candidate.DisplayName) -RegistryVersion ([string]$candidate.DisplayVersion)
        if ($null -ne $executableVersion -and -not [string]::IsNullOrWhiteSpace([string]$executableVersion.Version)) {
            $version = [string]$executableVersion.Version
            $versionSource = 'ExecutableFileVersion'
        }
        if ($null -ne $version) { $evidence.Version=$version; $evidence.VersionSource=$versionSource }
        if($candidate.InstallLocation){$evidence.InstallationLocation=$candidate.InstallLocation}
        $installedArchitecture = Get-WintainiumWindowsExecutableArchitecture -InstallationLocation ([string]$candidate.InstallLocation) -DisplayName ([string]$candidate.DisplayName)
        if (-not [string]::IsNullOrWhiteSpace([string]$installedArchitecture)) {
            $evidence.Architecture = [string]$installedArchitecture
        }
        return & $base $true 'Reconciled' ([pscustomobject]$evidence) @() $warnings
    } catch {
        return & $base $false 'InvalidSettings' $null @([pscustomobject]@{Code='WindowsReconciliationSettingsInvalid';Message=$_.Exception.Message}) @()
    }
}

function Get-WintainiumWindowsExecutableArchitecture {
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

    # Only inspect an executable whose basename is an exact derivation of the
    # registered display name. Registry view is not architecture evidence.
    $baseName = [regex]::Replace($DisplayName.Trim(), '\s+\d+(?:\.\d+)*(?:[a-z])?$', '').Trim()
    if ([string]::IsNullOrWhiteSpace($baseName) -or $baseName -match '[\\/:*?"<>|]') {
        return $null
    }

    $executablePath = Join-Path -Path ([System.IO.Path]::GetFullPath($InstallationLocation)) -ChildPath ($baseName + '.exe')
    if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
        return $null
    }

    $stream = $null
    $reader = $null
    try {
        $stream = [System.IO.File]::Open($executablePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $reader = [System.IO.BinaryReader]::new($stream)
        if ($stream.Length -lt 64) { return $null }
        if ($reader.ReadUInt16() -ne 0x5A4D) { return $null }
        $stream.Position = 0x3C
        $peOffset = $reader.ReadInt32()
        if ($peOffset -lt 64 -or $peOffset -gt ($stream.Length - 6)) { return $null }
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x00004550) { return $null }
        switch ($reader.ReadUInt16()) {
            0x014c { return 'x86' }
            0x8664 { return 'x64' }
            0xAA64 { return 'arm64' }
            default { return $null }
        }
    }
    catch {
        return $null
    }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }
        elseif ($null -ne $stream) { $stream.Dispose() }
    }
}

Export-ModuleMember -Function Invoke-WintainiumReconciliation
