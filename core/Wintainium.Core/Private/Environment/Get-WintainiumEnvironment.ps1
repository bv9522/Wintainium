function Get-WintainiumEnvironment {
    [CmdletBinding()]
    param(
        [Parameter()]
        [psobject]$Overrides
    )

    $overrideProperties = @{}
    if ($null -ne $Overrides) {
        foreach ($property in $Overrides.PSObject.Properties) {
            $overrideProperties[$property.Name] = $property.Value
        }
    }

    $osVersion = [System.Environment]::OSVersion.Version
    $osArchitecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    $processArchitecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture

    $machineArchitecture = switch ($osArchitecture.ToString().ToLowerInvariant()) {
        'x64' { 'x64' }
        'x86' { 'x86' }
        'arm64' { 'arm64' }
        'arm' { 'arm' }
        default { 'unknown' }
    }

    $normalizedProcessArchitecture = switch ($processArchitecture.ToString().ToLowerInvariant()) {
        'x64' { 'x64' }
        'x86' { 'x86' }
        'arm64' { 'arm64' }
        'arm' { 'arm' }
        default { 'unknown' }
    }

    [pscustomobject][ordered]@{
        OperatingSystem = if ($overrideProperties.ContainsKey('OperatingSystem')) { [string]$overrideProperties['OperatingSystem'] } else { 'Windows' }
        OperatingSystemVersion = if ($overrideProperties.ContainsKey('OperatingSystemVersion')) { [string]$overrideProperties['OperatingSystemVersion'] } else { $osVersion.ToString() }
        OperatingSystemBuild = if ($overrideProperties.ContainsKey('OperatingSystemBuild')) { [int]$overrideProperties['OperatingSystemBuild'] } else { [int]$osVersion.Build }
        MachineArchitecture = if ($overrideProperties.ContainsKey('MachineArchitecture')) { [string]$overrideProperties['MachineArchitecture'] } else { $machineArchitecture }
        ProcessArchitecture = if ($overrideProperties.ContainsKey('ProcessArchitecture')) { [string]$overrideProperties['ProcessArchitecture'] } else { $normalizedProcessArchitecture }
    }
}
