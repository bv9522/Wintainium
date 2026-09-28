# Wintainium Installer Contract

## Purpose

The installer contract defines the Core-to-installer boundary for applying an
artifact that Core has already selected and verified for installation. Installer
plugins provide installation capability; they do not choose releases, select
artifacts, perform update policy, or own authoritative managed application state.

The current production installer implementations are:

| Plugin | Supported format | Mode |
| --- | --- | --- |
| Wintainium.installer.exe | exe | process |
| Wintainium.installer.msi | msi | process |
| Wintainium.installer.portable-zip | zip | archive |
| Wintainium.installer.msix | msix | package |

All four implement Installer Contract Version 1.

## Descriptor

An installer descriptor identifies the plugin and declares its supported
capabilities. The entry point is a relative .psm1 path.

Example:

~~~json
{
  "pluginId": "Wintainium.installer.exe",
  "pluginType": "Installer",
  "contractVersions": ["1"],
  "entryPoint": "Wintainium.installer.exe.psm1",
  "capabilities": {
    "supportedFormats": ["exe"],
    "installationMode": "process"
  }
}
~~~

The descriptor is validated before execution. Core also revalidates the
resolved descriptor when preparing an installer invocation and requires the
plugin ID, plugin type, and entry point to match the selected plugin. Duplicate
plugin identities are rejected.

## Selection boundary

Installer selection is Core-owned.

1. Manifest validation resolves the declared installer capability.
2. Core selects an eligible artifact using machine architecture and manifest
   format policy.
3. Core resolves the declared or policy-selected installer plugin.
4. Core validates Contract 1 compatibility and supported artifact format.
5. Core prepares a structured installer invocation.
6. The installer plugin applies the artifact.

An explicitly declared installer is not silently replaced by another installer.
The Core default application policy may select a compatible installer when the
manifest leaves the mechanism to default policy, but this remains a Core
policy choice rather than an intrinsic priority of the installer plugins.

## Invocation boundary

Installer invocation is structured. Core passes the selected artifact and
structured settings to the installer operation; installers do not receive an
arbitrary shell command selected by the manifest.

EXE and MSI installers produce structured process specifications with executable
path, argument array, working directory, and environment data as applicable.
Process arguments remain separate values rather than being joined into a shell
command string.

The portable ZIP installer requires an absolute destination path. Its optional
archive entry point must be a relative path, must not be rooted, and must not
contain parent traversal. Nested relative paths are allowed.

The MSIX installer uses the system Windows PowerShell executable and passes
installer settings as JSON data through process arguments. The command used to
invoke Add-AppxPackage is fixed by the plugin implementation rather than
constructed from manifest-controlled text.

Installer plugins do not implicitly elevate themselves. Elevation, when needed
by an installation target, remains an operating-system/process concern rather
than a hidden installer policy.

## Security boundary

Installer descriptors and invocation validation establish contract integrity;
they are not a sandbox. Plugin modules are trusted code and execute in-process
under the Core process. The system therefore must not treat a third-party
plugin as safe merely because its descriptor is valid.

The implementation does establish several concrete boundaries:

- descriptor identity, type, contract, capabilities, and entry-point validation;
- rejection of duplicate plugin identities;
- absolute .psm1 module-path validation before module loading;
- plugin-root containment for relative entry points;
- artifact-format compatibility checks;
- structured installer settings rather than arbitrary command construction;
- process argument boundaries for EXE/MSI installation;
- portable archive path traversal rejection;
- fixed MSIX command construction with JSON settings arguments;
- structured installer results and operation correlation.

These controls reduce malformed-plugin and command-boundary risks but do not
claim isolation from malicious PowerShell code.

## Responsibility split

| Concern | Owner |
| --- | --- |
| Release discovery | Provider |
| Release/update decision | Core |
| Artifact eligibility and selection | Core |
| Installer selection | Core |
| Artifact trust/verification | Core |
| Installation mechanics | Installer plugin |
| Installed-application evidence | Reconciliation plugin |
| Authoritative managed state | Core |
| Presentation | Desktop/CLI client |

The governing principle is:

**Manifest describes. Provider discovers. Core decides. Download obtains. Verification establishes trust. Installer applies. Orchestration coordinates. UX presents.**
