# Public Application Reconciliation Contract

## Purpose

Invoke-WintainiumApplicationReconciliation is the Core-owned boundary for
refreshing authoritative installed state from current system evidence.

The command:

1. validates the application manifest;
2. resolves the manifest's declared reconciliation plugin;
3. reads the prior authoritative installed state;
4. invokes the reconciliation plugin;
5. converts trustworthy evidence through the authoritative state boundary; and
6. persists Installed or NotInstalled evidence.

Unknown evidence is never allowed to overwrite a trustworthy prior state.

## Public result

The command returns one structured result containing:

- OperationId
- IsSuccessful
- Status
- ApplicationId
- State
- Reconciliation
- Errors
- Warnings
- LogEvents

State is the authoritative Core state after the reconciliation attempt. When
evidence is Unknown and a trustworthy prior state exists, the returned state
remains the prior state and the reconciliation boundary reports preservation.

## Desktop usage

The desktop client may call this command through its documented Core adapter.
The desktop client does not invoke reconciliation plugins, registry readers, or
authoritative persistence helpers directly.

Collection refresh uses this boundary before projecting installed state into the
desktop presentation model. A separate Get-WintainiumApplicationInstalledState
call remains a read-only observation of already persisted authoritative state.

## Architecture

```text
Desktop
  |
  v
Invoke-WintainiumApplicationReconciliation
  |
  +--> manifest validation / plugin resolution
  |
  +--> reconciliation plugin
  |       |
  |       +--> Windows uninstall registry
  |
  +--> authoritative state reconciliation
  |
  v
installed-state.json
  |
  v
Desktop presentation model
```

The boundary is generic: no application-specific installer, registry key, or
provider logic belongs in the desktop client.
