# Wintainium CLI Reference

## Scope

This document is the practical reference for Wintainium's currently supported public PowerShell commands. The commands return structured engine results; they do not own presentation formatting or expose internal orchestration wiring.

The current public surface is intentionally limited to three operations:

- `Get-WintainiumManifest`
- `Test-WintainiumApplicationDefinition`
- `Get-WintainiumApplicationRelease`

The end-to-end update lifecycle is implemented internally but is **not yet a public command**. Do not construct internal orchestration objects or private stage requests from a client script to work around that boundary.

## Import

From the repository root:

```powershell
Import-Module .\core\Wintainium.Core\Wintainium.Core.psd1 -Force
```

Verify the exported surface:

```powershell
Get-Command -Module Wintainium.Core
```

Only the three commands listed above are intended as the user-facing Core API at this stage.

---

## Get-WintainiumManifest

### Purpose

Discovers and imports application manifests from a local filesystem collection. This is an offline discovery/import operation.

### Parameters

- `-Path` **(required)** — local manifest collection directory.
- `-Recurse` — also search child directories.
- `-SchemaPath` — override the application-manifest JSON Schema used during import. The module's bundled schema is used by default.

Example with an explicit schema path:

```powershell
$result = Get-WintainiumManifest `
    -Path 'C:\Wintainium\manifests' `
    -SchemaPath 'C:\Wintainium\schemas\application-manifest.schema.json'
```

### Typical use

```powershell
$result = Get-WintainiumManifest -Path 'C:\Wintainium\manifests'
```

Recursive discovery:

```powershell
$result = Get-WintainiumManifest -Path 'C:\Wintainium\manifests' -Recurse
```

### Result

The structured result contains:

- `OperationId` — Core-generated correlation identifier.
- `IsSuccessful` — whether discovery/import completed successfully.
- `Candidates` — discovered candidate paths/inputs.
- `ManifestPaths` — manifest paths accepted for import.
- `Manifests` — imported manifest objects.
- `Errors` — structured errors.
- `Warnings` — structured warnings.
- `LogEvents` — structured diagnostic events.

Collection-valued properties are arrays, including when no values are present.

### Automation example

```powershell
$result = Get-WintainiumManifest -Path 'C:\Wintainium\manifests'

if (-not $result.IsSuccessful) {
    $result.Errors | ForEach-Object {
        Write-Error "[$($_.Code)] $($_.Message)"
    }
    return
}

$result.Manifests | Select-Object Id, Name
```

### Responsibility boundary

This command does not validate an application's provider behavior, discover upstream releases, decide whether an installed application needs an update, download an artifact, verify an artifact, or install an application.

---

## Test-WintainiumApplicationDefinition

### Purpose

Validates one application definition and resolves the provider and installer capabilities declared by the manifest.

### Parameters

- `-ManifestPath` **(required)** — path to the application manifest to validate.
- `-PluginRoot` — root directory containing the provider and installer plugins required by the manifest. The module's default plugin root is used when omitted.
- `-SchemaPath` — override the application-manifest JSON Schema used during validation. The module's bundled schema is used by default.

Example with an explicit plugin root and schema:

```powershell
$validation = Test-WintainiumApplicationDefinition `
    -ManifestPath 'C:\Wintainium\manifests\Example.wintainium.json' `
    -PluginRoot 'C:\Wintainium\plugins' `
    -SchemaPath 'C:\Wintainium\schemas\application-manifest.schema.json'
```

### Typical use

```powershell
$validation = Test-WintainiumApplicationDefinition -ManifestPath 'C:\Wintainium\manifests\Example.wintainium.json'
```

Check validity and errors:

```powershell
$validation.IsValid
$validation.Errors | Select-Object Code, Message
```

### Result

The structured result contains:

- `OperationId` — Core-generated correlation identifier.
- `IsValid` — whether the application definition is valid and required capabilities can be resolved.
- `Manifest` — the validated manifest when available.
- `ProviderPlugin` — resolved provider capability when available.
- `InstallerPlugin` — resolved installer capability when available.
- `Errors` — structured errors.
- `Warnings` — structured warnings.
- `LogEvents` — structured diagnostic events.

### Responsibility boundary

Validation performs no network release discovery, artifact download, installation, or installed-state management. A valid definition means the definition and required plugin capabilities are usable; it does not mean an update is available.

---

## Get-WintainiumApplicationRelease

### Purpose

Validates an application definition, resolves its provider, and discovers normalized upstream release observations through the provider boundary.

### Parameters

- `-ManifestPath` **(required)** — path to the application manifest whose releases should be discovered.
- `-PluginRoot` — root directory containing the provider and installer plugins required by the manifest. The module's default plugin root is used when omitted.
- `-SchemaPath` — override the application-manifest JSON Schema used during validation. The module's bundled schema is used by default.

### Typical use

```powershell
$releaseResult = Get-WintainiumApplicationRelease -ManifestPath 'C:\Wintainium\manifests\Example.wintainium.json'
```

For a non-default plugin/schema layout:

```powershell
$releaseResult = Get-WintainiumApplicationRelease `
    -ManifestPath 'C:\Wintainium\manifests\Example.wintainium.json' `
    -PluginRoot 'C:\Wintainium\plugins' `
    -SchemaPath 'C:\Wintainium\schemas\application-manifest.schema.json'
```

Inspect the result:

```powershell
$releaseResult.Status
$releaseResult.Releases
$releaseResult.Errors | Select-Object Code, Message
```

### Result

The structured result contains:

- `OperationId` — Core-generated correlation identifier.
- `IsSuccessful` — whether release discovery completed successfully.
- `Status` — documented operation status.
- `Manifest` — application manifest used for discovery.
- `ProviderPlugin` — resolved provider capability.
- `Releases` — normalized release observations returned by the provider.
- `Errors` — structured errors.
- `Warnings` — structured warnings.
- `LogEvents` — structured diagnostic events.

### Responsibility boundary

Release discovery does not decide whether an installed application needs an update. It also does not download the selected artifact or install anything.

---

## Structured errors

Expected operational failures are returned through the structured `Errors` collection. Error objects expose a stable machine-readable `Code` and a human-readable `Message`, with contextual data where the owning operation provides it.

Clients should branch on documented error codes/categories rather than parse `Message` text.

The public contract recognizes these semantic categories:

- caller input;
- application definition;
- plugin capability;
- provider/discovery;
- acquisition;
- verification;
- installer;
- cancellation;
- internal/unexpected engine failure.

PowerShell parameter-binding errors and programmer errors may remain normal terminating/non-terminating PowerShell errors rather than operation-result errors.

## Operation correlation

`OperationId` is generated by Core. Clients consume it for correlation and diagnostics; they do not generate or replace it.

Structured `LogEvents` are diagnostic data, not a second control interface. Clients should not use log-message wording to make business decisions.

## JSON and pipeline use

Results are ordinary structured PowerShell objects and can be composed with standard PowerShell tooling:

```powershell
$result | Select-Object IsSuccessful, Status, OperationId
$result.Errors | Where-Object Code -ne 'None'
$result.Manifests | ForEach-Object Name
$result | ConvertTo-Json -Depth 10
```

Do not depend on property ordering, console formatting, colors, progress text, or diagnostic wording. Presentation belongs outside Core.

## End-to-end update lifecycle

There is intentionally no public `Update` command in the current contract.

A complete update requires authoritative installed-application state in addition to the manifest and provider release result. The current repository does not yet provide the required authoritative retrieval/persistence boundary. The public surface therefore does not invent installed state or require callers to manufacture it.

The eventual public update command will also be backed by a Core-owned composition seam. Callers will not be expected to construct:

- orchestration `StagePlan`;
- `CancellationContext`;
- `StageFactory`;
- provider requests;
- download requests;
- installer requests;
- individual stage executors.

Those are engine concerns. The public boundary will accept a purpose-built request and return the same kind of structured result used by the other public operations.

The installed-state and upgrade boundary is planned for Phase 8E.

## Contract rules for clients

A client of the public API should:

1. Supply explicit documented inputs.
2. Treat results as structured data.
3. Check `IsSuccessful` or `IsValid` as appropriate.
4. Use `Status` where documented.
5. Branch on stable error codes rather than diagnostic message text.
6. Preserve `OperationId` for correlation.
7. Keep presentation logic outside Core.
8. Avoid calling private functions or constructing internal engine objects.

A future CLI presentation layer and the future C#/.NET GUI are both expected to consume this same engine boundary rather than duplicate business rules.

## See also

- `docs/GettingStarted.md` — first-use walkthrough.
- `docs/ManifestAuthoring.md` — manifest authoring and validation guidance.
- `docs/PublicResultContract.md` — structured result contract.
- `docs/PublicPowerShellContract.md` — public API and architectural boundary.
- `docs/OrchestrationComposition.md` — internal composition requirements for the eventual end-to-end lifecycle.
