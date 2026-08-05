# Plugin Descriptor Contract (Phase 1)

Each plugin directory contains a `plugin.json` descriptor. The Phase 1
registry reads descriptors only; it does not load plugin behavior.

Required fields:

- `pluginId`: Stable identifier beginning with `Wintainium.provider.` or
  `Wintainium.installer.`.
- `pluginType`: `Provider` or `Installer`.
- `contractVersions`: Supported major contract versions.
- `capabilities`: An object describing supported capability boundaries.

Installer descriptors must declare `capabilities.supportedFormats`. Future
phases will add validated, plugin-owned settings schemas without changing the
core's provider/installer separation.

