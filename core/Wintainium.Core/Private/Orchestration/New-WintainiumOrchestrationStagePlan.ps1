function New-WintainiumOrchestrationStagePlan {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$OrchestrationRequest
    )

    $requiredProperties = @(
        'OperationId'
        'ManifestPath'
        'MachineArchitecture'
        'DownloadRoot'
    )

    $errors = [System.Collections.Generic.List[object]]::new()

    if ($null -eq $OrchestrationRequest) {
        $errors.Add([pscustomobject]@{
                Code = 'OrchestrationStagePlanRequestMissing'
                Message = 'OrchestrationRequest is required.'
            })
    }
    else {
        foreach ($propertyName in $requiredProperties) {
            $property = $OrchestrationRequest.PSObject.Properties[$propertyName]
            if ($null -eq $property -or $null -eq $property.Value -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
                $errors.Add([pscustomobject]@{
                        Code = 'OrchestrationStagePlanRequestPropertyMissing'
                        Message = "OrchestrationRequest must contain a non-empty $propertyName property."
                    })
            }
        }

        $operationId = [string]$OrchestrationRequest.OperationId
        $parsedOperationId = [guid]::Empty
        if (-not [guid]::TryParse($operationId, [ref]$parsedOperationId)) {
            $errors.Add([pscustomobject]@{
                    Code = 'OrchestrationStagePlanOperationIdInvalid'
                    Message = 'OrchestrationRequest.OperationId must be a valid GUID.'
                })
        }
    }

    if ($errors.Count -gt 0) {
        return [pscustomobject][ordered]@{
            IsValid = $false
            Plan = $null
            Errors = $errors.ToArray()
        }
    }

    $stageNames = @(
        'ManifestValidation'
        'ReleaseDiscovery'
        'UpdateDecision'
        'Download'
        'Verification'
        'InstallerSelection'
        'Installation'
    )

    $stages = for ($index = 0; $index -lt $stageNames.Count; $index++) {
        [pscustomobject][ordered]@{
            Sequence = $index + 1
            Name = $stageNames[$index]
            Required = $true
        }
    }

    [pscustomobject][ordered]@{
        IsValid = $true
        Plan = [pscustomobject][ordered]@{
            OperationId = [string]$OrchestrationRequest.OperationId
            ManifestPath = [string]$OrchestrationRequest.ManifestPath
            MachineArchitecture = [string]$OrchestrationRequest.MachineArchitecture
            DownloadRoot = [string]$OrchestrationRequest.DownloadRoot
            Stages = @($stages)
        }
        Errors = @()
    }
}
