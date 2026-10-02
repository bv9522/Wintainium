function Test-WintainiumInstallerInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$DownloadResult,

        [Parameter(Mandatory)]
        [psobject]$Manifest
    )

    $errors = [System.Collections.Generic.List[object]]::new()

    $requiredDownloadProperties = @(
        'OperationId',
        'Status',
        'Uri',
        'FileName',
        'DestinationPath'
    )

    foreach ($property in $requiredDownloadProperties) {
        if ($null -eq $DownloadResult.PSObject.Properties[$property]) {
            $errors.Add([pscustomobject]@{
                Code = 'InstallerInputDownloadPropertyMissing'
                Property = $property
                Message = "Download result is missing required property '$property'."
            })
        }
    }

    if ($null -ne $DownloadResult.PSObject.Properties['Status'] -and
        [string]$DownloadResult.Status -ne 'Downloaded') {
        $errors.Add([pscustomobject]@{
            Code = 'InstallerInputDownloadNotCompleted'
            Property = 'Status'
            Message = 'Installer input requires a completed download with Status = Downloaded.'
        })
    }

    if ($null -ne $DownloadResult.PSObject.Properties['DestinationPath']) {
        $destinationPath = [string]$DownloadResult.DestinationPath

        if ([string]::IsNullOrWhiteSpace($destinationPath)) {
            $errors.Add([pscustomobject]@{
                Code = 'InstallerInputArtifactPathInvalid'
                Property = 'DestinationPath'
                Message = 'DestinationPath must be a non-empty path.'
            })
        }
        elseif (-not [System.IO.Path]::IsPathFullyQualified($destinationPath)) {
            $errors.Add([pscustomobject]@{
                Code = 'InstallerInputArtifactPathNotAbsolute'
                Property = 'DestinationPath'
                Message = 'DestinationPath must be an absolute path.'
            })
        }
        elseif (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf)) {
            $errors.Add([pscustomobject]@{
                Code = 'InstallerInputArtifactMissing'
                Property = 'DestinationPath'
                Message = "Downloaded artifact '$destinationPath' does not exist as a file."
            })
        }
    }

    if ($null -eq $Manifest.PSObject.Properties['Installer'] -or $null -eq $Manifest.Installer) {
        $errors.Add([pscustomobject]@{
            Code = 'InstallerInputManifestInstallerMissing'
            Property = 'Installer'
            Message = 'Application manifest does not declare an installer plugin reference.'
        })
    }
    else {
        $installer = $Manifest.Installer

        $hasProperty = {
            param([object]$Object, [string]$Name)
            if ($null -eq $Object) { return $false }
            if ($Object -is [System.Collections.IDictionary]) { return $Object.Contains($Name) }
            return $null -ne $Object.PSObject.Properties[$Name]
        }
        $getProperty = {
            param([object]$Object, [string]$Name)
            if ($null -eq $Object) { return $null }
            if ($Object -is [System.Collections.IDictionary]) {
                if ($Object.Contains($Name)) { return $Object[$Name] }
                return $null
            }
            $property = $Object.PSObject.Properties[$Name]
            if ($null -ne $property) { return $property.Value }
            return $null
        }

        foreach ($property in @('pluginId', 'requiredContractVersion', 'settings')) {
            if (-not (& $hasProperty $installer $property)) {
                $errors.Add([pscustomobject]@{
                    Code = 'InstallerInputManifestInstallerPropertyMissing'
                    Property = "Installer.$property"
                    Message = "Installer plugin reference is missing required property '$property'."
                })
            }
        }

        $pluginId = & $getProperty $installer 'pluginId'
        if ((& $hasProperty $installer 'pluginId') -and
            [string]$pluginId -notmatch '^Wintainium\.installer\.[a-z0-9-]+(?:\.[a-z0-9-]+)*            $errors.Add([pscustomobject]@{
                Code = 'InstallerInputManifestInstallerIdInvalid'
                Property = 'Installer.pluginId'
                Message = 'Installer plugin reference must use a valid Wintainium.installer.* identifier.'
            })
        }

        $requiredContractVersion = & $getProperty $installer 'requiredContractVersion'
        if ((& $hasProperty $installer 'requiredContractVersion') -and
            [string]$requiredContractVersion -notmatch '^[1-9][0-9]*
            $errors.Add([pscustomobject]@{
                Code = 'InstallerInputManifestInstallerContractInvalid'
                Property = 'Installer.requiredContractVersion'
                Message = 'Installer plugin requiredContractVersion must be a positive major version.'
            })
        }

        $settings = & $getProperty $installer 'settings'
        if ((& $hasProperty $installer 'settings') -and
            $settings -isnot [System.Management.Automation.PSCustomObject] -and
            $settings -isnot [System.Collections.IDictionary]) {
            $errors.Add([pscustomobject]@{
                Code = 'InstallerInputManifestInstallerSettingsInvalid'
                Property = 'Installer.settings'
                Message = 'Installer plugin settings must be an object.'
            })
        }
    }

    [pscustomobject][ordered]@{
        IsValid = $errors.Count -eq 0
        Errors = $errors.ToArray()
    }
}
) {
            $errors.Add([pscustomobject]@{
                Code = 'InstallerInputManifestInstallerIdInvalid'
                Property = 'Installer.pluginId'
                Message = 'Installer plugin reference must use a valid Wintainium.installer.* identifier.'
            })
        }

        if ($null -ne $installer.PSObject.Properties['requiredContractVersion'] -and
            [string]$installer.requiredContractVersion -notmatch '^[1-9][0-9]*$') {
            $errors.Add([pscustomobject]@{
                Code = 'InstallerInputManifestInstallerContractInvalid'
                Property = 'Installer.requiredContractVersion'
                Message = 'Installer plugin requiredContractVersion must be a positive major version.'
            })
        }

        if ($null -ne $installer.PSObject.Properties['settings'] -and
            $installer.settings -isnot [System.Management.Automation.PSCustomObject] -and
            $installer.settings -isnot [System.Collections.IDictionary]) {
            $errors.Add([pscustomobject]@{
                Code = 'InstallerInputManifestInstallerSettingsInvalid'
                Property = 'Installer.settings'
                Message = 'Installer plugin settings must be an object.'
            })
        }
    }

    [pscustomobject][ordered]@{
        IsValid = $errors.Count -eq 0
        Errors = $errors.ToArray()
    }
}
) {
            $errors.Add([pscustomobject]@{
                Code = 'InstallerInputManifestInstallerContractInvalid'
                Property = 'Installer.requiredContractVersion'
                Message = 'Installer plugin requiredContractVersion must be a positive major version.'
            })
        }

        if ($null -ne $installer.PSObject.Properties['settings'] -and
            $installer.settings -isnot [System.Management.Automation.PSCustomObject] -and
            $installer.settings -isnot [System.Collections.IDictionary]) {
            $errors.Add([pscustomobject]@{
                Code = 'InstallerInputManifestInstallerSettingsInvalid'
                Property = 'Installer.settings'
                Message = 'Installer plugin settings must be an object.'
            })
        }
    }

    [pscustomobject][ordered]@{
        IsValid = $errors.Count -eq 0
        Errors = $errors.ToArray()
    }
}
) {
            $errors.Add([pscustomobject]@{
                Code = 'InstallerInputManifestInstallerIdInvalid'
                Property = 'Installer.pluginId'
                Message = 'Installer plugin reference must use a valid Wintainium.installer.* identifier.'
            })
        }

        if ($null -ne $installer.PSObject.Properties['requiredContractVersion'] -and
            [string]$installer.requiredContractVersion -notmatch '^[1-9][0-9]*$') {
            $errors.Add([pscustomobject]@{
                Code = 'InstallerInputManifestInstallerContractInvalid'
                Property = 'Installer.requiredContractVersion'
                Message = 'Installer plugin requiredContractVersion must be a positive major version.'
            })
        }

        if ($null -ne $installer.PSObject.Properties['settings'] -and
            $installer.settings -isnot [System.Management.Automation.PSCustomObject] -and
            $installer.settings -isnot [System.Collections.IDictionary]) {
            $errors.Add([pscustomobject]@{
                Code = 'InstallerInputManifestInstallerSettingsInvalid'
                Property = 'Installer.settings'
                Message = 'Installer plugin settings must be an object.'
            })
        }
    }

    [pscustomobject][ordered]@{
        IsValid = $errors.Count -eq 0
        Errors = $errors.ToArray()
    }
}
