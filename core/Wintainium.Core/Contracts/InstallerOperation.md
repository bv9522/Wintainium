# Installer Operation Contract

## Status

Phase 6G contract: Accepted for implementation.

## Purpose

Phase 6G defines the Core-owned integration boundary that composes installer
selection, installer invocation preparation, installer plugin execution,
controlled process execution, and structured installation-result creation.

The installer plugin is responsible for translating the constrained 6D
`InstallerInvocation` into a structured process specification. Core validates
that specification and passes only the validated process inputs to the 6E
controlled process boundary.

## Boundary

```text
Selected Installer
      |
      v
Installer Invocation (6D)
      |
      v
Installer Plugin
      |
      | structured process specification
      v
Core validation
      |
      v
Controlled Installer Process (6E)
      |
      v
Installation Result (6F)
```

## Core-to-installer operation

The validated installer module must export exactly this fixed operation:

`Invoke-WintainiumInstaller -Invocation <InstallerInvocation>`

The descriptor cannot select an arbitrary command or PowerShell expression.
Core loads the module from the already validated 6D `PluginModulePath` and
invokes only the fixed operation name.

The plugin receives only the constrained 6D invocation. It does not receive
the application manifest, provider data, download credentials, trust policy,
or arbitrary Core state.

## Installer process specification

A successful installer operation returns exactly one structured object with:

- `ExecutablePath` — absolute path to the process Core should start.
- `Arguments` — zero or more structured argument strings; these are passed to
  the 6E process boundary without shell command construction.
- `WorkingDirectory` — optional absolute existing directory.
- `EnvironmentVariables` — optional dictionary of environment-variable
  overrides.

The plugin does not supply a timeout or cancellation token. Those are Core
execution-policy inputs owned by the 6G coordinator and passed to Phase 6E.

`ExecutablePath` is the plugin's explicit process target. Core must not infer
an executable from the downloaded artifact filename, extension, archive
contents, or vendor metadata.

## Validation

Core rejects a plugin result when:

- the plugin returns no result or more than one result;
- the result is missing `ExecutablePath`;
- `ExecutablePath` is empty, relative, or does not identify an existing file;
- `Arguments` is present but is not an array of strings;
- `WorkingDirectory` is present and is not an absolute existing directory;
- `EnvironmentVariables` is present but is not a dictionary;
- an environment-variable name is empty or invalid.

Core normalizes valid paths to full paths before passing them to 6E.

Phase 6E independently validates the concrete process request again. 6G must
not weaken that boundary.

## Integration result

The 6G operation returns the structured 6F installation result. Expected
operation-boundary failures are converted into the same result shape rather
than escaping as unstructured installer failures.

The operation preserves the 6D correlation identifiers through the 6F result.

## Security boundary

Installer plugin code is executable plugin code and is therefore itself an
execution boundary. Loading a plugin is not equivalent to trusting a downloaded
artifact. Artifact authenticity, integrity, signature validity, and approval
remain outside this contract.

The plugin may choose how to construct a process specification, but Core
retains the final process boundary. No shell command line, `cmd.exe /c`,
`Invoke-Expression`, or arbitrary descriptor-selected command is permitted.

The installer plugin must not be used to bypass Core trust, verification,
policy, cancellation, timeout, process-lifecycle, or result semantics.

## Phase boundary

6C selects the installer plugin.

6D prepares the constrained installer invocation.

6G invokes the fixed installer-plugin operation, validates its process
specification, delegates process lifecycle to 6E, and converts the 6E result
through 6F.

6E owns process lifecycle and termination.

6F owns structured installation-result interpretation.

Post-install application-state reconciliation, application health, and update
verification remain outside Phase 6G.
