# Real-world application acceptance

## Scope

The live catalog contains 25 real publisher sources: 17 official download/release pages and 8 upstream GitHub Releases pages. This runner is separate from Pester unit tests and the existing 100-case GitHub URL-shape benchmark.

For every application it invokes the production Core onboarding workflow against the live URL, allowing all registered source-resolution-capable providers to compete. It persists the generated definition only in a unique temporary workspace, performs live release and artifact discovery, reconciles installed state through the production Windows registry plugin using actual machine evidence, and evaluates update status through the public Core command.

The report records the selected provider, installer and reconciliation plugin IDs, discovered release/artifact counts, latest version, observed installation state/version, update decision, warnings and errors. It also inventories production plugin descriptors and capabilities.

## Safety boundary

This runner does not download or execute third-party installers. EXE/MSI installers can make machine-wide changes, MSIX registers packages, and portable ZIP installs can overwrite destinations. It would be unsafe to run 25 publishers' installers or updates on a daily-use PC.

Consequently, this is a live preflight of onboarding, parsing, installed-state discovery and update decisions. It is not a claim that real-world installation/update execution has been validated. The production installer plugins have dedicated plugin-level unit coverage, and the EXE process path also has a controlled integration test. Those checks exercise installer contracts with controlled payloads, not real publisher applications. A destructive lifecycle acceptance pass should run in a disposable Windows VM with snapshots and explicit approval.

The runner writes manifests and state only beneath its unique temporary workspace. It never modifies the user's normal Wintanium manifest/state directories and never runs installer execution.

## Run

From the repository root in PowerShell 7.4 or newer:

~~~powershell
.\tests\RealWorld\Invoke-WintainiumRealWorldAcceptance.ps1
~~~

Reports are written as JSON, CSV and Markdown beneath the system temporary directory in Wintainium-RealWorldAcceptance. The isolated workspace is retained for diagnosis.

A Passed case means onboarding, release discovery with at least one supported artifact, registry reconciliation and update-status evaluation completed. Incomplete is not a pass: it indicates a capability gap such as no supported artifacts or unavailable installed-state evidence. Failed indicates a required operation failed. Network outages, rate limits, publisher changes and product defects should be distinguished using captured error codes and diagnostics.

## Production plugin inventory

The current production set contains two providers (GitHub Releases and Official Download Page), one Windows installed-application reconciliation plugin, and four installers (EXE, MSI, MSIX and Portable ZIP). The per-application report records the provider/installer/reconciliation identities selected by Core. The plugin inventory reports all descriptors and their declared capabilities. Descriptor validation or installer selection is not proof of successful installation.

## Follow-on execution test

Actual first-install and update execution must be tested in a disposable Windows VM. That pass should run real publisher artifacts through download, verification and the relevant installer plugin, then verify the resulting registry evidence and update state. It must include explicit cleanup/rollback checks and preserve the VM snapshot when any operation fails.
