# Plugin Descriptor Contract

Each plugin directory contains a `plugin.json` descriptor. The registry reads
and validates descriptors without loading plugin behavior.

## Common fields

Required fields:

- `pluginId`: Stable identifier beginning with `Wintainium.provider.` or
  `Wintainium.installer.`.
- `pluginType`: `Provider` or `Installer`.
- `contractVersions`: Supported major contract versions.
- `capabilities`: An object describing supported capability boundaries.

Provider IDs are stable machine identifiers and are independent of display
names.

## Provider descriptors

Provider Contract Version 1 requires these fields and boolean capabilities:

- `entryPoint`: Relative `.psm1` module path inside the provider plugin
  directory. Parent-directory traversal and rooted paths are invalid.
- `capabilities.releaseDiscovery`: provider can discover releases.
- `capabilities.artifactDiscovery`: provider can discover artifact candidates
  associated with releases.

Core invokes only the fixed `Invoke-WintainiumProvider` operation exported by
the declared module entry point. The descriptor cannot select an arbitrary
command to execute.

Providers may declare additional stable capability information, but provider
specific API details do not become Core contracts merely by appearing in the
descriptor.

A provider descriptor identifies capabilities and a constrained executable
module reference. It must not contain arbitrary PowerShell commands, script
expressions, command lines, or manifest-controlled executable instructions.

See `ProviderContract.md` for the complete Phase 3 provider contract.

## Installer descriptors

Installer Contract Version 1 requires `capabilities.supportedFormats` to be a
non-empty JSON array of unique, non-empty string format identifiers. Core
validates the identifier shape but intentionally does not maintain a universal
format allowlist.

Installer descriptor validation is declarative and does not load installer
behavior or execute an artifact. See `InstallerDescriptor.md` for the complete
Phase 6B installer descriptor and capability contract.
