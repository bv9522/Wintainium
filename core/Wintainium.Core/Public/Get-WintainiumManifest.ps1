function Get-WintainiumManifest {
    <#
    .SYNOPSIS
    Discovers and imports Wintainium manifests from a local collection directory.

    .DESCRIPTION
    Performs offline manifest discovery and import only. Recognized manifest files use
    the .wintainium.json filename convention. Invalid candidates do not prevent valid
    manifests from being returned.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [switch]$Recurse,

        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json')
    )

    $operationId = [guid]::NewGuid().Guid
    $errors = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[object]]::new()
    $logEvents = [System.Collections.Generic.List[object]]::new()
    $manifests = [System.Collections.Generic.List[object]]::new()
    $manifestPaths = [System.Collections.Generic.List[string]]::new()
    $candidates = @()

    $logEvents.Add((New-WintainiumLogEvent -Severity Information -OperationId $operationId -Component 'Core' -EventName 'ManifestDiscoveryStarted' -Message 'Manifest collection discovery started.' -Context @{ Path = $Path; Recurse = $Recurse.IsPresent }))

    if (-not (Test-Path -LiteralPath $Path)) {
        $errors.Add([pscustomobject][ordered]@{
                Code = 'ManifestCollectionNotFound'
                Path = '$'
                Message = "Manifest collection '$Path' was not found."
            })
    }
    elseif (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        $errors.Add([pscustomobject][ordered]@{
                Code = 'ManifestCollectionPathInvalid'
                Path = '$'
                Message = "Manifest collection path '$Path' is not a directory."
            })
    }
    else {
        try {
            $candidates = @(Find-WintainiumManifestFile -ManifestRoot $Path -Recurse:$Recurse)
        }
        catch {
            $errors.Add([pscustomobject][ordered]@{
                    Code = 'ManifestCollectionReadFailed'
                    Path = '$'
                    Message = $_.Exception.Message
                })
        }
    }

    foreach ($candidate in $candidates) {
        $importResult = Import-WintainiumManifest -Path $candidate -SchemaPath $SchemaPath
        foreach ($errorRecord in @($importResult.Errors)) {
            $errors.Add([pscustomobject][ordered]@{
                    Code = $errorRecord.Code
                    Path = $candidate
                    Message = $errorRecord.Message
                })
        }
        foreach ($warningRecord in @($importResult.Warnings)) {
            $warnings.Add([pscustomobject]$warningRecord)
        }
        if ($importResult.IsValid) {
            $manifests.Add($importResult.Manifest)
            $manifestPaths.Add($candidate)
        }
    }

    $seenIds = @{}
    for ($index = 0; $index -lt $manifests.Count; $index++) {
        $id = [string]$manifests[$index].Id
        if ($seenIds.ContainsKey($id)) {
            $errors.Add([pscustomobject][ordered]@{
                    Code = 'ManifestDuplicateApplicationId'
                    Path = $manifestPaths[$index]
                    Message = "Application ID '$id' is defined by multiple manifests: '$($seenIds[$id])' and '$($manifestPaths[$index])'."
                })
        }
        else {
            $seenIds[$id] = $manifestPaths[$index]
        }
    }

    $severity = if ($errors.Count -eq 0) { 'Information' } else { 'Error' }
    $eventName = if ($errors.Count -eq 0) { 'ManifestDiscoverySucceeded' } else { 'ManifestDiscoveryFailed' }
    $message = if ($errors.Count -eq 0) { 'Manifest collection discovery completed successfully.' } else { 'Manifest collection discovery completed with errors.' }
    $logEvents.Add((New-WintainiumLogEvent -Severity $severity -OperationId $operationId -Component 'Core' -EventName $eventName -Message $message -Context @{ CandidateCount = $candidates.Count; ManifestCount = $manifests.Count; ErrorCount = $errors.Count; WarningCount = $warnings.Count }))

    [pscustomobject][ordered]@{
        OperationId = $operationId
        IsSuccessful = $errors.Count -eq 0
        Candidates = @($candidates)
        ManifestPaths = $manifestPaths.ToArray()
        Manifests = $manifests.ToArray()
        Errors = $errors.ToArray()
        Warnings = $warnings.ToArray()
        LogEvents = $logEvents.ToArray()
    }
}
