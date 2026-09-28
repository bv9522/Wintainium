# Wintainium Manifest Authoring

A Wintainium application manifest is a JSON declaration of how an application is identified, where its releases are discovered, which installer capability handles the artifact, and which release/artifact policies Core should apply, and which release/artifact policies Core should apply.

The authoritative machine-readable definition is `schemas/application-manifest.schema.json` (JSON Schema Draft 2020-12). This guide explains the fields at a human level; the schema remains the final validation authority.

## File naming

Local manifest discovery recognizes files using the `.wintainium.json` filename convention.

For example:

```text
manifests/
└── Example.Application.wintainium.json
```

Use `Get-WintainiumManifest` to discover and import a collection. Discovery is offline; it does not contact providers or upstream release sources.

## Required top-level fields

Every manifest must contain:

| Field | Purpose |
|---|---|
| `manifestVersion` | Manifest format version. The current schema requires `"1.0"`. |
| `id` | Stable application identifier. Use lowercase identifiers matching the schema pattern. |
| `name` | Human-readable application name. |
| `source` | Provider plugin reference used to discover releases. |
| `installer` | Installer plugin reference used to apply an artifact. |
| `release` | Release-selection policy, currently expressed as `stable`, `prerelease`, or `any`. |
| `artifact` | Supported artifact formats and machine architectures. |

Optional descriptive fields include `description`, `homepage`, `publisher`, `aliases`, `documentation`, `notes`, and `deprecated`.

## Provider reference

The `source` object identifies the provider capability rather than embedding provider implementation logic in the manifest:

```json
"source": {
  "pluginId": "Wintainium.provider.example",
  "requiredContractVersion": "1",
  "settings": {}
}
```

`pluginId` must use the `Wintainium.provider.*` naming convention. `requiredContractVersion` declares the minimum provider contract version required by the manifest. `settings` is provider-specific configuration and must be understood by that provider.

A manifest describes the desired source; the provider performs discovery. Do not put HTTP logic, scraping code, executable commands, or provider implementation details into a manifest.

## Installer reference

The `installer` object identifies the installer capability:

```json
"installer": {
  "pluginId": "Wintainium.installer.example",
  "requiredContractVersion": "1",
  "settings": {}
}
```

The installer reference declares capability and configuration. It does not cause installation during manifest import or validation. When present, pluginId is an explicit installer selection; Core does not silently substitute a different installer.

## Release policy

The `release` object currently requires `channel`:

```json
"release": {
  "channel": "stable"
}
```

Allowed values are:

- `stable` — stable releases only.
- `prerelease` — prereleases only.
- `any` — either release channel, subject to the rest of the decision policy.

Release discovery reports what the provider observes. Core's update-decision layer is responsible for deciding whether an observed release is an applicable update.

## Artifact policy

The `artifact` object declares formats and architectures that the application can accept:

```json
"artifact": {
  "formats": ["msi", "exe"],
  "architectures": ["x64"]
}
```

Supported formats are `zip`, `msi`, `msix`, and `exe`. Supported architectures are `x64`, `x86`, `arm64`, and `neutral`.

`allowUnknownArchitecture` may be set to `true` when the manifest explicitly permits an artifact whose architecture cannot be identified. This is a policy declaration; it does not bypass other artifact eligibility or verification rules.

## Complete illustrative shape

The following is an illustrative manifest shape, not a claim that the example plugin IDs or settings exist in the repository:

```json
{
  "manifestVersion": "1.0",
  "id": "example.vendor-application",
  "name": "Example Application",
  "description": "An illustrative Wintainium application definition.",
  "homepage": "https://example.com/",
  "publisher": "Example Vendor",
  "source": {
    "pluginId": "Wintainium.provider.example",
    "requiredContractVersion": "1",
    "settings": {}
  },
  "installer": {
    "pluginId": "Wintainium.installer.example",
    "requiredContractVersion": "1",
    "settings": {}
  },
  "release": {
    "channel": "stable"
  },
  "artifact": {
    "formats": ["msi"],
    "architectures": ["x64"]
  }
}
```

Replace the illustrative provider and installer references with capabilities that are actually available in the target Wintainium environment.

## Validate before release discovery

Validate a manifest directly:

```powershell
$validation = Test-WintainiumApplicationDefinition -ManifestPath 'C:\Wintainium\manifests\Example.Application.wintainium.json'

$validation.IsValid
$validation.Errors | Select-Object Code, Message
```

A valid application definition means the manifest and its required plugin capabilities satisfy the current validation boundary. It does **not** mean that an update is available, an artifact has been downloaded, or an application has been installed.

Release discovery can then be requested:

```powershell
$releases = Get-WintainiumApplicationRelease -ManifestPath 'C:\Wintainium\manifests\Example.Application.wintainium.json'
$releases.Status
$releases.Releases
$releases.Errors | Select-Object Code, Message
```

## Common authoring mistakes

### Using an unsupported filename

`Get-WintainiumManifest` discovers the `.wintainium.json` convention. A JSON file with another extension may not be treated as a manifest candidate.

### Adding undeclared properties

The current schema sets `additionalProperties` to `false` for the manifest and its structured objects. Extra fields that are not part of the schema are invalid.

### Using the wrong application ID format

Application IDs must be lowercase and match the schema's identifier pattern. Keep IDs stable once published; the ID is an application identity, not a display name.

### Treating provider settings as generic Core settings

Provider settings belong to the provider named by `source.pluginId`. Core should not interpret provider-specific settings unless a contract explicitly requires it.

### Assuming a valid manifest means an update exists

Validation establishes definition/plugin capability validity. Release discovery establishes upstream observations. Installed-state comparison and update selection belong to the later decision/orchestration boundary.

## Relationship to the engine

The manifest is declarative:

**Manifest describes → Provider discovers → Core decides → Download obtains → Verification establishes trust → Installer applies → Orchestration coordinates → UX presents.**

Manifest authoring should therefore express policy and capability references, not reproduce implementation logic owned by Core or plugins.

## See also

- `schemas/application-manifest.schema.json` — authoritative manifest schema.
- `docs/GettingStarted.md` — first-use workflow.
- `docs/CLI.md` — public command reference.
- `docs/PublicResultContract.md` — structured result contract.
- `docs/ProviderContractTestHarness.md` — provider development/testing boundary.

## Installer and artifact selection

Artifact selection and installer selection are separate Core-owned decisions.

Core first evaluates artifact eligibility and selects an artifact using
architecture and manifest format policy. Exact machine architecture has
priority over neutral artifacts, and unknown architecture is accepted only when
the manifest explicitly allows it. The manifest's format order is considered
within the eligible architecture set.

The selected artifact is then checked against the installer capability. If the
manifest explicitly names an installer plugin, that exact plugin must be
registered, Contract 1 compatible, and capable of handling the selected format.
Core does not silently switch installers.

If the manifest leaves installer selection to the Core default application
policy, Core currently prefers compatible mechanisms in this order:

1. exe
2. msi
3. msix
4. zip

This is a policy default, not a universal ranking that overrides application
requirements. Manifest-declared artifact formats can narrow the eligible set,
and explicit installer selection remains authoritative.

The production Contract 1 installer plugins are:

- Wintainium.installer.exe — EXE process installation.
- Wintainium.installer.msi — MSI process installation.
- Wintainium.installer.msix — MSIX package installation.
- Wintainium.installer.portable-zip — portable/archive installation.

See docs/InstallerContract.md for the installer execution and security
boundary.

## Architecture policy

Architecture is evaluated independently from installer format. The current
Core policy distinguishes x64, x86, arm64, and neutral rather than treating
32-bit and 64-bit Windows artifacts as interchangeable. On a 64-bit machine,
an x64 artifact is preferred over a neutral artifact; an x86 artifact remains
a distinct candidate and is not relabeled as x64.

This same distinction matters to Windows installed-application reconciliation:
32-bit and 64-bit registry views are evidence sources, not proof that an
application itself has a particular architecture.