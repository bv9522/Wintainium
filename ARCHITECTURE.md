# Architecture

## Boundary

The PowerShell engine owns discovery, trust evaluation, validation, downloads,
installation coordination, configuration, and logging. A future GUI is a
client of that engine and must not duplicate engine rules.

## Main components

| Component | Responsibility |
| --- | --- |
| Core | Public commands, contracts, orchestration, shared validation, and error handling. |
| Provider plugins | Obtain version and artifact metadata from upstream software providers. |
| Installer plugins | Validate and apply a downloaded artifact according to its format. |
| Application manifests | Declare portable application-management intent and select compatible plugins. |
| Manifest repositories | Store and distribute Wintanium application manifests. |
| Configuration | Holds user-selected paths, policies, and enabled plugins. |

## Repositories and providers

A **manifest repository** is a location that stores Wintanium manifest files.
It distributes management definitions; it is not necessarily related to an
application publisher.

An **upstream software provider** is the official developer, vendor, service,
or location from which a provider plugin discovers release and artifact
metadata. Examples include GitHub Releases, a vendor API, a local repository,
or a future Microsoft Store integration.

These are separate concepts. A manifest can be distributed from one manifest
repository while its provider plugin discovers releases from a different
upstream software provider.

## Plugin design rules

- Plugins expose a small documented contract and return structured objects.
- Plugins do not directly depend on one another.
- Core does not contain vendor- or application-specific branching.
- A manifest selects provider and installer plugins by stable identifiers.
- Plugin failures produce actionable errors and leave state recoverable.
- Provider and installer plugins communicate only with the core.

## Trust and validation

Download URLs, release metadata, and artifacts are treated as untrusted input.
The core evaluates trust, validates downloaded artifacts, evaluates checksums
and signatures when available, enforces safety policy, and requires user
approval when appropriate. Manifests express application intent and acceptable
artifact preferences only; they do not make trust decisions or bypass safety
controls.

The core validates expected file types and destination paths before
installation. User data must never be overwritten implicitly.

Detailed command and object contracts will be added before the first feature.
