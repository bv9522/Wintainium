#requires -Version 7.4
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent),
    [string]$CatalogPath = (Join-Path $PSScriptRoot 'real-world-applications.json'),
    [string]$ReportDirectory = (Join-Path ([IO.Path]::GetTempPath()) 'Wintainium-RealWorldAcceptance'),
    [string]$WorkspaceRoot = (Join-Path ([IO.Path]::GetTempPath()) ('Wintainium-RealWorld-' + [guid]::NewGuid().ToString('N')))
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$core=Join-Path $RepositoryRoot 'core/Wintainium.Core/Wintainium.Core.psd1'
$schema=Join-Path $RepositoryRoot 'schemas/application-manifest.schema.json'
$plugins=Join-Path $RepositoryRoot 'plugins'
if(!(Test-Path $core)){throw "Core module not found: $core"}
Import-Module $core -Force
$apps=@(Get-Content $CatalogPath -Raw -Encoding utf8 | ConvertFrom-Json)
if($apps.Count -lt 25){throw 'The acceptance catalog must contain at least 25 applications.'}
$manifestRoot=Join-Path $WorkspaceRoot 'manifests'
$stateRoot=Join-Path $WorkspaceRoot 'state'
New-Item -ItemType Directory -Force -Path $manifestRoot,$stateRoot,$ReportDirectory | Out-Null
$results=[System.Collections.Generic.List[object]]::new()
$i=0
foreach($app in $apps){
    $i++
    Write-Host "[$i/$($apps.Count)] $($app.name)"
    $row=[ordered]@{Id=$app.id;Name=$app.name;SourceFamily=$app.sourceFamily;SourceUri=$app.sourceUri;Status='Started';FailureCategory=$null;ApplicationId=$null;ProviderPluginId=$null;InstallerPluginId=$null;ReconciliationPluginId=$null;ManifestPath=$null;OnboardingStatus=$null;ReleaseStatus=$null;ReleaseCount=0;ArtifactCount=0;LatestVersion=$null;ReconciliationStatus=$null;InstallationState='Unknown';InstalledVersion=$null;UpdateStatus=$null;IsUpdateAvailable=$null;Errors=@();Warnings=@()}
    try{
        $on=Invoke-WintainiumApplicationOnboarding -SourceUri $app.sourceUri -ManifestRoot $manifestRoot -PluginRoot $plugins -SchemaPath $schema
        $row.OnboardingStatus=[string]$on.Status
        if(!$on.IsSuccessful){$row.Status='Failed';$row.FailureCategory='OnboardingOrSourceResolution';$row.Errors=@($on.Errors|%{"$($_.Code): $($_.Message)"});$row.Warnings=@($on.Warnings|%{"$($_.Code): $($_.Message)"});$results.Add([pscustomobject]$row);continue}
        $row.ManifestPath=[string]$on.ManifestPath
        $def=$on.ApplicationDefinition
        $row.ApplicationId=[string]$def.Id
        $row.ProviderPluginId=[string]$def.Source.pluginId
        $expectedProvider=if($app.sourceFamily -eq 'GitHubReleases'){'Wintainium.provider.github-releases'}else{'Wintainium.provider.official-download-page'}
        if($row.ProviderPluginId -ne $expectedProvider){$row.Status='Failed';$row.FailureCategory='UnexpectedProviderSelection';$row.Errors+="Expected provider $expectedProvider but Core selected $($row.ProviderPluginId).";$results.Add([pscustomobject]$row);continue}
        $row.InstallerPluginId=[string]$def.Installer.pluginId
        $row.ReconciliationPluginId=[string]$def.Reconciliation.pluginId
        $release=Get-WintainiumApplicationRelease -ManifestPath $row.ManifestPath -PluginRoot $plugins -SchemaPath $schema
        $row.ReleaseStatus=[string]$release.Status
        if(!$release.IsSuccessful){$row.Status='Failed';$row.FailureCategory='LiveReleaseDiscovery';$row.Errors=@($release.Errors|%{"$($_.Code): $($_.Message)"});$row.Warnings=@($release.Warnings|%{"$($_.Code): $($_.Message)"});$results.Add([pscustomobject]$row);continue}
        $row.ReleaseCount=@($release.Releases).Count
        $artifacts=@($release.Releases|%{@($_.Artifacts)})
        $row.ArtifactCount=$artifacts.Count
        if($release.Releases.Count){$row.LatestVersion=[string]$release.Releases[0].Version}
        $rec=Invoke-WintainiumApplicationReconciliation -ManifestPath $row.ManifestPath -StateRoot $stateRoot -PluginRoot $plugins -SchemaPath $schema
        $row.ReconciliationStatus=[string]$rec.Status
        if($rec.IsSuccessful -and $null -ne $rec.State){$row.InstallationState=[string]$rec.State.InstallationState;$row.InstalledVersion=[string]$rec.State.Version}
        else{$row.Errors+=@($rec.Errors|%{"$($_.Code): $($_.Message)"});$row.Warnings+=@($rec.Warnings|%{"$($_.Code): $($_.Message)"})}
        $update=Get-WintainiumApplicationUpdateStatus -ManifestPath $row.ManifestPath -StateRoot $stateRoot -PluginRoot $plugins -SchemaPath $schema
        $row.UpdateStatus=[string]$update.Status
        if($null -ne $update.Decision){$row.IsUpdateAvailable=[bool]$update.Decision.IsUpdateAvailable}
        $row.Warnings+=@($update.Warnings|%{"$($_.Code): $($_.Message)"})
        if(!$update.IsSuccessful){$row.Errors+=@($update.Errors|%{"$($_.Code): $($_.Message)"});$row.Status='Failed';$row.FailureCategory='UpdateDecision'}
        elseif(!$rec.IsSuccessful){$row.Status='Incomplete';$row.FailureCategory='InstallationState'}
        elseif(!$row.ArtifactCount){$row.Status='Incomplete';$row.FailureCategory='NoSupportedArtifacts'}
        else{$row.Status='Passed'}
    }catch{$row.Status='Failed';$row.FailureCategory='RunnerException';$row.Errors+= $_.Exception.Message}
    $results.Add([pscustomobject]$row)
}
$inventory=foreach($f in Get-ChildItem $plugins -Filter plugin.json -Recurse -File){
    try{$d=Get-Content $f.FullName -Raw|ConvertFrom-Json;[pscustomobject]@{PluginId=$d.pluginId;PluginType=$d.pluginType;Capabilities=$d.capabilities;Valid=($d.contractVersions.Count -gt 0 -and [bool]$d.entryPoint)}}
    catch{[pscustomobject]@{PluginId=$null;PluginType=$null;Capabilities=$null;Valid=$false}}
}
$report=[ordered]@{GeneratedAtUtc=[DateTimeOffset]::UtcNow.ToString('o');ApplicationCount=$results.Count;Passed=@($results|? Status -eq Passed).Count;Incomplete=@($results|? Status -eq Incomplete).Count;Failed=@($results|? Status -eq Failed).Count;PluginCount=@($inventory).Count;ValidPluginDescriptors=@($inventory|? Valid).Count;ExecutionBoundary='Live onboarding, release/artifact parsing, actual Windows registry reconciliation, and update-decision evaluation. No artifact downloads or installer execution.';Applications=@($results);Plugins=@($inventory)}
$stamp=Get-Date -Format yyyyMMdd-HHmmss
$json=Join-Path $ReportDirectory "acceptance-$stamp.json"
$csv=Join-Path $ReportDirectory "acceptance-$stamp.csv"
$md=Join-Path $ReportDirectory "acceptance-$stamp.md"
$report|ConvertTo-Json -Depth 30|Set-Content $json -Encoding utf8
$results|Export-Csv $csv -NoTypeInformation -Encoding utf8
$lines=@('# Wintainium real-world acceptance','',"Generated: $($report.GeneratedAtUtc)","Applications: $($report.ApplicationCount) | Passed: $($report.Passed) | Incomplete: $($report.Incomplete) | Failed: $($report.Failed)","Plugins valid: $($report.ValidPluginDescriptors)/$($report.PluginCount)",'','| Application | Source | Result | Provider | Releases | Artifacts | Installed state | Update |','|---|---|---|---|---:|---:|---|---|')
foreach($r in $results){$lines+="| $($r.Name) | $($r.SourceFamily) | $($r.Status) | $($r.ProviderPluginId) | $($r.ReleaseCount) | $($r.ArtifactCount) | $($r.InstallationState) $($r.InstalledVersion) | $($r.UpdateStatus) |"}
$lines|Set-Content $md -Encoding utf8
Write-Host "Passed=$($report.Passed); Incomplete=$($report.Incomplete); Failed=$($report.Failed)"
Write-Host "JSON: $json";Write-Host "CSV: $csv";Write-Host "Markdown: $md";Write-Host "Workspace retained at: $WorkspaceRoot"
if($report.Failed -or $report.Incomplete){exit 1}
