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
    $normalized = [regex]::Replace($normalized, '\s*\((?:x64|x86|x32|arm64|64[- ]bit|32[- ]bit)(?:\s+edition)?\)\s*$', '')
    $normalized = [regex]::Replace($normalized, '\s+(?:x64|x86|x32|arm64|64[- ]bit|32[- ]bit)(?:\s+edition)?$', '')
    $normalized = [regex]::Replace($normalized, '\s+\d+(?:\.\d+)*(?:[a-z])?$', '')
    $normalized = [regex]::Replace($normalized, '\s+edition$', '')
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
                            DisplayIcon = $entryKey.GetValue('DisplayIcon', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                            URLUpdateInfo = $entryKey.GetValue('URLUpdateInfo', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                            Comments = $entryKey.GetValue('Comments', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                            InstallDate = $entryKey.GetValue('InstallDate', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                        }
                    } finally { if ($null -ne $entryKey) { $entryKey.Dispose() } }
                }
            } finally {
                if ($null -ne $uninstallKey) { $uninstallKey.Dispose() }
                if ($null -ne $baseKey) { $baseKey.Dispose() }
            }
        }.GetNewClosure()
    }

    $windowsInstallerSettings = Get-WintainiumWindowsSettingValue -Object $Settings -Name 'windowsInstaller'
    $configuredMsiProductCodes = @()
    if ($null -ne $windowsInstallerSettings) {
        $configuredMsiProductCodes = @(Get-WintainiumWindowsSettingValue -Object $windowsInstallerSettings -Name 'productCodes' | ForEach-Object {
            $code = ([string]$_).Trim().Trim([char[]]@('{','}'))
            if ($code -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                throw [System.ArgumentException]::new("Configured Windows Installer product code '$_' is not a valid GUID.")
            }
            $code.ToUpperInvariant()
        } | Select-Object -Unique)
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
            $entryWindowsInstaller = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'WindowsInstaller')
            $entrySubKey = ([string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'SubKey')).Trim().Trim([char[]]@('{','}'))
            $msiProductCodeMatch = $entryWindowsInstaller -eq '1' -and
                $entrySubKey -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' -and
                $configuredMsiProductCodes -contains $entrySubKey.ToUpperInvariant()
            $matches = if ($msiProductCodeMatch) { $true } elseif ($matchMode -eq 'any') { $false } else { $true }
            if (-not $msiProductCodeMatch) {
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
                    WindowsInstaller = $entryWindowsInstaller
                    MsiProductCode = if ($msiProductCodeMatch) { '{' + $entrySubKey.ToUpperInvariant() + '}' } else { $null }
                    IdentityConfidence = if ($msiProductCodeMatch) { 'Direct' } else { 'Explicit' }
                    IdentityEvidence = if ($msiProductCodeMatch) { @('ConfiguredMsiProductCodeExact') } else { @('ExplicitRegistryPredicateMatch') }
                    EvidenceSource = if ($msiProductCodeMatch) { 'WindowsInstallerProductRegistration' } else { 'WindowsUninstallRegistry' }
                })
            }
        }
    }
    # Explicit manifest predicates remain authoritative. Only when they find no
    # candidate do we evaluate the canonical manifest name against the registry
    # inventory. Weak/ambiguous results remain non-authoritative.
    if ($candidates.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($ApplicationName)) {
        $fullName = ConvertTo-WintainiumIdentityName -Value $ApplicationName
        $primaryName = ([regex]::Split($ApplicationName.Trim(), '[,;|:]', 2)[0]).Trim()
        $primaryNormalized = ConvertTo-WintainiumIdentityName -Value $primaryName
        $primaryTokens = @(Get-WintainiumIdentityTokens -Value $primaryName)
        $fullTokens = @(Get-WintainiumIdentityTokens -Value $ApplicationName)
        $publisherNormalized = ConvertTo-WintainiumIdentityName -Value $ApplicationPublisher
        if ($publisherNormalized -match 'sourceforge|github|browse files|download page|website') { $publisherNormalized = '' }
        $publisherTokens = if ($publisherNormalized) { @(Get-WintainiumIdentityTokens -Value $ApplicationPublisher) } else { @() }
        $homepageHost = ''
        if (-not [string]::IsNullOrWhiteSpace($ApplicationHomepage)) {
            try {
                $parsedHomepage = [uri]$ApplicationHomepage
                if ($parsedHomepage.IsAbsoluteUri -and $parsedHomepage.Host -notmatch 'sourceforge\.net$|github\.com$') {
                    $homepageHost = $parsedHomepage.Host.ToLowerInvariant()
                }
            } catch { $homepageHost = '' }
        }

        $scored = foreach ($entry in $allEntries) {
            $displayName = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'DisplayName')
            $subKey = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'SubKey')
            $entryPublisher = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'Publisher')
            $displayNormalized = ConvertTo-WintainiumIdentityName -Value $displayName
            $subKeyNormalized = ConvertTo-WintainiumIdentityName -Value $subKey
            $displayTokens = @(Get-WintainiumIdentityTokens -Value $displayName)
            $subKeyTokens = @(Get-WintainiumIdentityTokens -Value $subKey)
            $score = 0
            $evidence = [System.Collections.Generic.List[string]]::new()
            $scoreBreakdown = [System.Collections.Generic.List[object]]::new()

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
                    $score = [Math]::Max($score, [int](52 + (26 * $coverage)))
                    $evidence.Add('MeaningfulDisplayNameTokensContainedInPrimaryPhrase')
                }
                if ($subKeySubset) {
                    $coverage = [double]$subKeyTokens.Count / [Math]::Max(1, $primaryTokens.Count)
                    $score = [Math]::Max($score, [int](49 + (24 * $coverage)))
                    $evidence.Add('MeaningfulSubKeyTokensContainedInPrimaryPhrase')
                }
                $overlap = @($fullTokens | Where-Object { $_ -in $displayTokens }).Count
                if ($overlap -gt 0) {
                    $score = [Math]::Max($score, [Math]::Min(42, 18 + (8 * $overlap)))
                    $evidence.Add('SharedMeaningfulNameTokens')
                }
            }

            if ($score -gt 0) { $scoreBreakdown.Add([pscustomobject][ordered]@{ Factor='NameIdentity'; Points=$score }) }
            if ($publisherNormalized -and (ConvertTo-WintainiumIdentityName -Value $entryPublisher) -eq $publisherNormalized) {
                $previousScore = $score
                $score = [Math]::Min(100, $score + 18)
                $evidence.Add('PublisherCorroborated')
                $scoreBreakdown.Add([pscustomobject][ordered]@{ Factor='PublisherCorroborated'; Points=($score - $previousScore) })
            }
            $installLocation = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'InstallLocation')
            if (-not [string]::IsNullOrWhiteSpace($installLocation)) {
                $folderName = [System.IO.Path]::GetFileName($installLocation.TrimEnd('\','/'))
                $folderNormalized = ConvertTo-WintainiumIdentityName -Value $folderName
                if ($folderNormalized -and ($folderNormalized -eq $displayNormalized -or $folderNormalized -eq $subKeyNormalized)) {
                    $previousScore = $score
                    $score = [Math]::Min(100, $score + 8)
                    $evidence.Add('InstallLocationNameCorroborated')
                    $scoreBreakdown.Add([pscustomobject][ordered]@{ Factor='InstallLocationNameCorroborated'; Points=($score - $previousScore) })
                }
            }
            if ($displayNormalized -and $displayNormalized -eq $subKeyNormalized) {
                $previousScore = $score
                $score = [Math]::Min(100, $score + 5)
                $evidence.Add('DisplayNameAndSubKeyConsistent')
                $scoreBreakdown.Add([pscustomobject][ordered]@{ Factor='DisplayNameAndSubKeyConsistent'; Points=($score - $previousScore) })
            }
            if ($homepageHost) {
                foreach ($urlField in @('URLInfoAbout','URLUpdateInfo','HelpLink')) {
                    $urlValue = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name $urlField)
                    if (-not $urlValue) { continue }
                    try {
                        $entryUri = [uri]$urlValue
                        if ($entryUri.IsAbsoluteUri -and $entryUri.Host -ieq $homepageHost) {
                            $previousScore = $score
                            $score = [Math]::Min(100, $score + 12)
                            $evidence.Add('PublisherWebsiteHostCorroborated')
                            $scoreBreakdown.Add([pscustomobject][ordered]@{ Factor='PublisherWebsiteHostCorroborated'; Points=($score - $previousScore) })
                            break
                        }
                    } catch { }
                }
            }
            $displayIcon = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'DisplayIcon')
            if ($displayIcon) {
                $iconPath = ($displayIcon -replace ',\s*-?\d+\s*$', '').Trim('"')
                if ([System.IO.Path]::IsPathRooted($iconPath)) {
                    $iconBase = [System.IO.Path]::GetFileNameWithoutExtension($iconPath)
                    $iconNormalized = ConvertTo-WintainiumIdentityName -Value $iconBase
                    if ($iconNormalized -and ($iconNormalized -eq $displayNormalized -or $iconNormalized -eq $subKeyNormalized)) {
                        $previousScore = $score
                        $score = [Math]::Min(100, $score + 5)
                        $evidence.Add('DisplayIconNameCorroborated')
                        $scoreBreakdown.Add([pscustomobject][ordered]@{ Factor='DisplayIconNameCorroborated'; Points=($score - $previousScore) })
                    }
                }
            }
            $uninstallString = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'UninstallString')
            if ($displayTokens.Count -gt 0 -and $uninstallString) {
                $commandTokens = @(Get-WintainiumIdentityTokens -Value $uninstallString)
                if (@($displayTokens | Where-Object { $_ -in $commandTokens }).Count -gt 0) {
                    $previousScore = $score
                    $score = [Math]::Min(100, $score + 5)
                    $evidence.Add('UninstallCommandNameCorroborated')
                    $scoreBreakdown.Add([pscustomobject][ordered]@{ Factor='UninstallCommandNameCorroborated'; Points=($score - $previousScore) })
                }
            }
            $executableIdentity = Get-WintainiumWindowsExecutableIdentityEvidence -Entry $entry -ApplicationPublisher $ApplicationPublisher
            if ($null -ne $executableIdentity) {
                if ($executableIdentity.ProductMatchesRegistration) {
                    $previousScore = $score
                    $score = [Math]::Min(100, $score + 15)
                    $evidence.Add('ExecutableProductNameMatchesRegisteredName')
                    $scoreBreakdown.Add([pscustomobject][ordered]@{ Factor='ExecutableProductNameMatchesRegisteredName'; Points=($score - $previousScore) })
                }
                if ($executableIdentity.ProductMatchesRegistration -and $executableIdentity.CompanyMatchesPublisher) {
                    $previousScore = $score
                    $score = [Math]::Min(100, $score + 10)
                    $evidence.Add('ExecutableCompanyNameCorroborated')
                    $scoreBreakdown.Add([pscustomobject][ordered]@{ Factor='ExecutableCompanyNameCorroborated'; Points=($score - $previousScore) })
                }
                if ($executableIdentity.ProductMatchesRegistration -and $executableIdentity.TrustedPublisherSignature) {
                    $previousScore = $score
                    $score = [Math]::Min(100, $score + 25)
                    $evidence.Add('AuthenticodePublisherSignatureValid')
                    $scoreBreakdown.Add([pscustomobject][ordered]@{ Factor='AuthenticodePublisherSignatureValid'; Points=($score - $previousScore) })
                }
            }
            # Apply the vendor-only penalty after all supporting metadata so a
            # publisher's own generic registration cannot win on accumulated fields.
            if ($primaryTokens.Count -gt 1 -and $displayTokens.Count -gt 0 -and
                @($displayTokens | Where-Object { $_ -notin $publisherTokens }).Count -eq 0) {
                $previousScore = $score
                $score = [Math]::Max(0, $score - 35)
                $evidence.Add('CandidateNameIsPublisherOnly')
                $scoreBreakdown.Add([pscustomobject][ordered]@{ Factor='CandidateNameIsPublisherOnly'; Points=($score - $previousScore) })
            }
            if ($score -gt 0) {
                [pscustomobject][ordered]@{
                    Scope = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'Scope')
                    View = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'View')
                    SubKey = $subKey
                    DisplayName = $displayName
                    DisplayVersion = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'DisplayVersion')
                    Publisher = $entryPublisher
                    InstallLocation = $installLocation
                    UninstallString = $uninstallString
                    QuietUninstallString = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'QuietUninstallString')
                    URLInfoAbout = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'URLInfoAbout')
                    HelpLink = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'HelpLink')
                    InstallSource = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'InstallSource')
                    WindowsInstaller = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'WindowsInstaller')
                    DisplayIcon = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'DisplayIcon')
                    URLUpdateInfo = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'URLUpdateInfo')
                    Comments = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'Comments')
                    InstallDate = [string](Get-WintainiumWindowsSettingValue -Object $entry -Name 'InstallDate')
                    EvidenceSource = 'WindowsUninstallRegistry'
                    IdentityScore = $score
                    IdentityConfidence = if ($score -ge 70) { 'Strong' } else { 'ReviewOnly' }
                    IdentityEvidence = @($evidence)
                    IdentityScoreBreakdown = @($scoreBreakdown)
                    ExecutableIdentityEvidence = $executableIdentity
                    IdentityScoreThreshold = 70
                    IdentitySeparationThreshold = 15
                    IdentityRunnerUpScore = 0
                    IdentityScoreMargin = $score
                }
            }
        }
        $orderedScored = @($scored | Sort-Object -Property @{Expression='IdentityScore';Descending=$true}, @{Expression='DisplayName';Descending=$false})
        if ($orderedScored.Count -gt 0) {
            $topScore = [int]$orderedScored[0].IdentityScore
            $secondScore = if ($orderedScored.Count -gt 1) { [int]$orderedScored[1].IdentityScore } else { 0 }
            for ($candidateIndex = 0; $candidateIndex -lt $orderedScored.Count; $candidateIndex++) {
                $scoredCandidate = $orderedScored[$candidateIndex]
                $runnerUpScore = if ($candidateIndex -eq 0) { $secondScore } else { $topScore }
                $scoredCandidate.IdentityRunnerUpScore = $runnerUpScore
                $scoredCandidate.IdentityScoreMargin = [int]$scoredCandidate.IdentityScore - $runnerUpScore
            }
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

function Get-WintainiumWindowsExecutableIdentityEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Entry,
        [AllowNull()][string]$ApplicationPublisher
    )

    $installLocation = [string](Get-WintainiumWindowsSettingValue -Object $Entry -Name 'InstallLocation')
    if ([string]::IsNullOrWhiteSpace($installLocation) -or
        -not [System.IO.Path]::IsPathFullyQualified($installLocation) -or
        -not (Test-Path -LiteralPath $installLocation -PathType Container)) {
        return $null
    }

    $installRoot = [System.IO.Path]::GetFullPath($installLocation).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $paths = [System.Collections.Generic.List[string]]::new()
    $displayIcon = [string](Get-WintainiumWindowsSettingValue -Object $Entry -Name 'DisplayIcon')
    if ($displayIcon) {
        $iconPath = ($displayIcon -replace ',\s*-?\d+\s*$', '').Trim().Trim('"')
        if ([System.IO.Path]::IsPathFullyQualified($iconPath) -and [System.IO.Path]::GetExtension($iconPath) -ieq '.exe') {
            $paths.Add($iconPath)
        }
    }

    $displayName = [string](Get-WintainiumWindowsSettingValue -Object $Entry -Name 'DisplayName')
    $baseName = [regex]::Replace($displayName.Trim(), '\s+\d+(?:\.\d+)*(?:[a-z])?$', '').Trim()
    if ($baseName -and $baseName -notmatch '[\\/:*?"<>|]') {
        $paths.Add((Join-Path -Path $installRoot -ChildPath ($baseName + '.exe')))
    }

    foreach ($path in @($paths | Select-Object -Unique)) {
        try {
            $fullPath = [System.IO.Path]::GetFullPath($path)
            if (-not $fullPath.StartsWith($installRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -or
                -not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
                continue
            }

            $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($fullPath)
            $productName = [string]$versionInfo.ProductName
            $companyName = [string]$versionInfo.CompanyName
            $registeredName = ConvertTo-WintainiumIdentityName -Value $displayName
            $productMatchesRegistration = $registeredName -and (ConvertTo-WintainiumIdentityName -Value $productName) -eq $registeredName
            $publisherNormalized = ConvertTo-WintainiumIdentityName -Value $ApplicationPublisher
            $companyMatchesPublisher = $publisherNormalized -and (ConvertTo-WintainiumIdentityName -Value $companyName) -eq $publisherNormalized

            $signatureStatus = 'NotChecked'
            $signerName = ''
            $trustedPublisherSignature = $false
            try {
                $signature = Get-AuthenticodeSignature -FilePath $fullPath -ErrorAction Stop
                $signatureStatus = [string]$signature.Status
                if ($null -ne $signature.SignerCertificate) {
                    $signerName = [string]$signature.SignerCertificate.GetNameInfo(
                        [System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
                }
                $trustedPublisherSignature = $signatureStatus -eq 'Valid' -and
                    $publisherNormalized -and
                    (ConvertTo-WintainiumIdentityName -Value $signerName) -eq $publisherNormalized
            }
            catch {
                $signatureStatus = 'Unavailable'
            }

            return [pscustomobject][ordered]@{
                Path = $fullPath
                ProductName = $productName
                CompanyName = $companyName
                OriginalFilename = [string]$versionInfo.OriginalFilename
                SignatureStatus = $signatureStatus
                SignerName = $signerName
                ProductMatchesRegistration = [bool]$productMatchesRegistration
                CompanyMatchesPublisher = [bool]$companyMatchesPublisher
                TrustedPublisherSignature = [bool]$trustedPublisherSignature
            }
        }
        catch {
            continue
        }
    }

    return $null
}

function ConvertTo-WintainiumComparableExecutableVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$Version,
        [AllowNull()] [string]$RegistryVersion
    )

    # FileVersionInfo may expose numeric version-resource components using
    # a culture-specific separator. Version identifiers are invariant, so
    # normalize only strictly numeric, comma-delimited three/four-part values.
    if ($Version -match '^\s*\d+(?:\s*,\s*\d+){2,3}\s*$') {
        $Version = [regex]::Replace($Version.Trim(), '\s*,\s*', '.')
    }
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
        $applicationHomepage = [string](Get-WintainiumWindowsSettingValue -Object $Request.Manifest -Name 'homepage')
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
        $firstCandidate = if ($candidateCount -gt 0) { @($observation.Candidates)[0] } else { $null }
        $candidateConfidence = if ($null -ne $firstCandidate) { [string](Get-WintainiumWindowsSettingValue -Object $firstCandidate -Name 'IdentityConfidence') } else { '' }
        if ($candidateCount -eq 1 -and $candidateConfidence -eq 'ReviewOnly') {
            $candidate = $firstCandidate
            $evidence=[pscustomobject][ordered]@{ApplicationId=$applicationId;InstallationState='Unknown';EvidenceSource='WindowsUninstallRegistry'}
            $warnings += [pscustomobject]@{
                Code = 'WindowsReconciliationIdentityRequiresConfirmation'
                Message = 'Registry identity evidence is suggestive but does not meet the confidence and separation thresholds required to confirm the installed application.'
                OperationId = $operationId
                CandidateCount = 1
                CandidateDisplayName = [string](Get-WintainiumWindowsSettingValue -Object $candidate -Name 'DisplayName')
                CandidateRegistrySubKey = [string](Get-WintainiumWindowsSettingValue -Object $candidate -Name 'SubKey')
                IdentityScore = Get-WintainiumWindowsSettingValue -Object $candidate -Name 'IdentityScore'
                IdentityScoreThreshold = Get-WintainiumWindowsSettingValue -Object $candidate -Name 'IdentityScoreThreshold'
                IdentityRunnerUpScore = Get-WintainiumWindowsSettingValue -Object $candidate -Name 'IdentityRunnerUpScore'
                IdentityScoreMargin = Get-WintainiumWindowsSettingValue -Object $candidate -Name 'IdentityScoreMargin'
                IdentitySeparationThreshold = Get-WintainiumWindowsSettingValue -Object $candidate -Name 'IdentitySeparationThreshold'
                IdentityScoreBreakdown = @(Get-WintainiumWindowsSettingValue -Object $candidate -Name 'IdentityScoreBreakdown')
                ExecutableIdentityEvidence = Get-WintainiumWindowsSettingValue -Object $candidate -Name 'ExecutableIdentityEvidence'
                IdentityEvidence = @(Get-WintainiumWindowsSettingValue -Object $candidate -Name 'IdentityEvidence')
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
                CandidateEvidence = @($observation.Candidates | ForEach-Object {
                    [pscustomobject]@{
                        DisplayName = [string](Get-WintainiumWindowsSettingValue -Object $_ -Name 'DisplayName')
                        RegistrySubKey = [string](Get-WintainiumWindowsSettingValue -Object $_ -Name 'SubKey')
                        IdentityScore = Get-WintainiumWindowsSettingValue -Object $_ -Name 'IdentityScore'
                        IdentityConfidence = Get-WintainiumWindowsSettingValue -Object $_ -Name 'IdentityConfidence'
                        IdentityScoreThreshold = Get-WintainiumWindowsSettingValue -Object $_ -Name 'IdentityScoreThreshold'
                        IdentityRunnerUpScore = Get-WintainiumWindowsSettingValue -Object $_ -Name 'IdentityRunnerUpScore'
                        IdentityScoreMargin = Get-WintainiumWindowsSettingValue -Object $_ -Name 'IdentityScoreMargin'
                        IdentitySeparationThreshold = Get-WintainiumWindowsSettingValue -Object $_ -Name 'IdentitySeparationThreshold'
                        IdentityScoreBreakdown = @(Get-WintainiumWindowsSettingValue -Object $_ -Name 'IdentityScoreBreakdown')
                        ExecutableIdentityEvidence = Get-WintainiumWindowsSettingValue -Object $_ -Name 'ExecutableIdentityEvidence'
                        IdentityEvidence = @(Get-WintainiumWindowsSettingValue -Object $_ -Name 'IdentityEvidence')
                    }
                })
            }
            return & $base $true 'Unknown' $evidence @() (@($warnings)+$ambiguity)
        }
        $candidate=@($observation.Candidates)[0]
        $candidateEvidenceSource = [string](Get-WintainiumWindowsSettingValue -Object $candidate -Name 'EvidenceSource')
        if ([string]::IsNullOrWhiteSpace($candidateEvidenceSource)) { $candidateEvidenceSource = 'WindowsUninstallRegistry' }
        $candidateMsiProductCode = [string](Get-WintainiumWindowsSettingValue -Object $candidate -Name 'MsiProductCode')
        $candidateInstallLocation = [string](Get-WintainiumWindowsSettingValue -Object $candidate -Name 'InstallLocation')
        $candidateDisplayName = [string](Get-WintainiumWindowsSettingValue -Object $candidate -Name 'DisplayName')
        $candidateDisplayVersion = [string](Get-WintainiumWindowsSettingValue -Object $candidate -Name 'DisplayVersion')
        $evidence=[ordered]@{ApplicationId=$applicationId;InstallationState='Installed';EvidenceSource=$candidateEvidenceSource;IdentityConfidence=$candidateConfidence}
        if (-not [string]::IsNullOrWhiteSpace($candidateMsiProductCode)) { $evidence.MsiProductCode=$candidateMsiProductCode }
        $version = if (-not [string]::IsNullOrWhiteSpace($candidateDisplayVersion)) { $candidateDisplayVersion } else { $null }
        $versionSource = if ($null -ne $version) { 'Registry' } else { $null }
        $executableVersion = Get-WintainiumWindowsExecutableVersion -InstallationLocation $candidateInstallLocation -DisplayName $candidateDisplayName -RegistryVersion $candidateDisplayVersion
        if ($null -ne $executableVersion -and -not [string]::IsNullOrWhiteSpace([string]$executableVersion.Version)) {
            $version = [string]$executableVersion.Version
            $versionSource = 'ExecutableFileVersion'
        }
        if ($null -ne $version) { $evidence.Version=$version; $evidence.VersionSource=$versionSource }
        if($candidateInstallLocation){$evidence.InstallationLocation=$candidateInstallLocation}
        if ($candidateConfidence -eq 'Strong' -and $null -ne (Get-WintainiumWindowsSettingValue -Object $candidate -Name 'IdentityScore')) {
            $warnings += [pscustomobject]@{
                Code = 'WindowsReconciliationIdentityResolved'
                Message = 'Installed-state identity was resolved using layered registry evidence rather than an explicit exact-name predicate.'
                OperationId = $operationId
                CandidateDisplayName = [string](Get-WintainiumWindowsSettingValue -Object $candidate -Name 'DisplayName')
                CandidateRegistrySubKey = [string](Get-WintainiumWindowsSettingValue -Object $candidate -Name 'SubKey')
                IdentityScore = Get-WintainiumWindowsSettingValue -Object $candidate -Name 'IdentityScore'
                IdentityScoreThreshold = Get-WintainiumWindowsSettingValue -Object $candidate -Name 'IdentityScoreThreshold'
                IdentityRunnerUpScore = Get-WintainiumWindowsSettingValue -Object $candidate -Name 'IdentityRunnerUpScore'
                IdentityScoreMargin = Get-WintainiumWindowsSettingValue -Object $candidate -Name 'IdentityScoreMargin'
                IdentitySeparationThreshold = Get-WintainiumWindowsSettingValue -Object $candidate -Name 'IdentitySeparationThreshold'
                IdentityScoreBreakdown = @(Get-WintainiumWindowsSettingValue -Object $candidate -Name 'IdentityScoreBreakdown')
                ExecutableIdentityEvidence = Get-WintainiumWindowsSettingValue -Object $candidate -Name 'ExecutableIdentityEvidence'
                IdentityEvidence = @(Get-WintainiumWindowsSettingValue -Object $candidate -Name 'IdentityEvidence')
            }
        }
        if ($candidateConfidence -eq 'Direct') {
            $warnings += [pscustomobject]@{
                Code = 'WindowsReconciliationIdentityResolved'
                Message = 'Installed-state identity was resolved by an exact configured Windows Installer ProductCode.'
                OperationId = $operationId
                CandidateDisplayName = $candidateDisplayName
                CandidateRegistrySubKey = [string](Get-WintainiumWindowsSettingValue -Object $candidate -Name 'SubKey')
                IdentityConfidence = 'Direct'
                MsiProductCode = $candidateMsiProductCode
                IdentityEvidence = @(Get-WintainiumWindowsSettingValue -Object $candidate -Name 'IdentityEvidence')
            }
        }
        $installedArchitecture = Get-WintainiumWindowsExecutableArchitecture -InstallationLocation $candidateInstallLocation -DisplayName $candidateDisplayName
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
