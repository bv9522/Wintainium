function New-WintainiumOrchestrationRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$MachineArchitecture,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DownloadRoot
    )

    $errors = [System.Collections.Generic.List[object]]::new()

    $manifestPathValue = $ManifestPath.Trim()
    if (-not [System.IO.Path]::IsPathFullyQualified($manifestPathValue)) {
        $errors.Add([pscustomobject]@{
                Code = 'OrchestrationManifestPathNotAbsolute'
                Message = 'ManifestPath must be an absolute path.'
            })
    }

    $downloadRootValue = $DownloadRoot.Trim()
    if (-not [System.IO.Path]::IsPathFullyQualified($downloadRootValue)) {
        $errors.Add([pscustomobject]@{
                Code = 'OrchestrationDownloadRootNotAbsolute'
                Message = 'DownloadRoot must be an absolute path.'
            })
    }

    $machineArchitectureValue = $MachineArchitecture.Trim()
    if ([string]::IsNullOrWhiteSpace($machineArchitectureValue)) {
        $errors.Add([pscustomobject]@{
                Code = 'OrchestrationMachineArchitectureEmpty'
                Message = 'MachineArchitecture must not be empty.'
            })
    }

    if ($errors.Count -gt 0) {
        return [pscustomobject][ordered]@{
            IsValid = $false
            Request = $null
            Errors = $errors.ToArray()
        }
    }

    [pscustomobject][ordered]@{
        IsValid = $true
        Request = [pscustomobject][ordered]@{
            OperationId = [guid]::NewGuid().ToString()
            ManifestPath = [System.IO.Path]::GetFullPath($manifestPathValue)
            MachineArchitecture = $machineArchitectureValue
            DownloadRoot = [System.IO.Path]::GetFullPath($downloadRootValue)
        }
        Errors = @()
    }
}
