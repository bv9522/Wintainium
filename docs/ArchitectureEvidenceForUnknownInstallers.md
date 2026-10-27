# Architecture Decision: Evidence-Based Installer Architecture Inspection

- Status: Accepted direction; implementation pending
- Phase: 14 — GUI Productization
- Scope: Artifact architecture inference and update-target selection

## Context

The official-download-page provider can infer architecture from artifact names and explicit publisher text. Unknown architecture is otherwise rejected by artifact eligibility unless a manifest explicitly permits it. The architecture of an installer executable is not necessarily the architecture of the application payload it installs.

Core Temp 1.21 provides a verified example: its official setup executable has an x86 PE header, but static extraction of the checksum-matched, validly signed Inno Setup package reveals two main application binaries, one x64 and one x86. Therefore, inspecting the setup executable's PE machine type alone would incorrectly describe its payload.

## Decision

Implement a general, evidence-based architecture inspection path for supported installer formats. Do not default unknown `.exe` files to neutral, and do not assume that all installers made with a particular framework are dual-architecture.

The inspection must establish the architecture of the packaged application payload, not merely the architecture of the setup stub.

### Evidence rules

1. Artifact extension, filename, and setup-stub PE architecture are insufficient to prove payload architecture.
2. Explicit publisher metadata may classify an artifact only when the claim clearly applies to that specific installer and meets the provider's evidence contract.
3. Static inspection may establish architecture when a supported package parser can enumerate relevant payload files and their PE machine types.
4. A dual-architecture classification requires evidence of both x86 and x64 payloads (or equivalent reliable package metadata); separate sibling download links alone are not enough.
5. Unknown, malformed, unsupported, or ambiguous packages remain unknown and are not made eligible by inference.
6. Installer contents must never be executed to discover architecture.

## Pipeline implications

Current artifact eligibility occurs before download. The implementation must account for that ordering rather than silently weakening the existing eligibility check.

The intended lifecycle is:

1. Discover the candidate and preserve source-page provenance.
2. Mark a suitable unknown-architecture installer as requiring inspection, not as neutral or eligible by default.
3. Acquire it into staging and perform the existing trust verification.
4. For verified artifacts and supported formats, inspect package metadata and payload PE headers without executing files.
5. Resolve the payload architecture evidence to x86, x64, dual-architecture, or unknown.
6. Complete architecture eligibility using the resolved evidence; reject or try another candidate if evidence remains insufficient.
7. Retain normal installer execution and post-install reconciliation behavior.

The implementation must preserve the governing boundary: **Manifest describes. Provider discovers. Core decides. Download obtains. Verification establishes trust. Installer applies. Orchestration coordinates. UX presents.**

## Initial format support

The implementation does not depend on an external installer inspector. Wintainium reads a PE machine header using native static file I/O, but does not mistake the outer bootstrapper architecture for the installed payload architecture. When payload architecture remains unresolved, an artifact with supported publisher checksum evidence can be offered through a generic, operation-specific decision: accept the architecture risk, use a known-compatible fallback from the same release, or cancel. SHA256 is preferred; legacy MD5 requires its separate explicit authorization before the architecture decision can be reached. The normal checksum verification and all other safety gates remain mandatory.

No third-party installer-inspection executable is required or bundled. Native PE-header inspection is evidence only; it cannot establish the payload architecture of arbitrary bootstrapper installers.

Inspection is performed only after the selected artifact has passed SHA256 verification. The parser extracts to a unique temporary directory, is time-limited, and the extracted files are inspected as data only. Wintainium never launches the installer or extracted application during architecture discovery. The first supported payload relationship is deliberately narrow: a single top-level executable, or duplicate same-path executable variants that establish the target architecture. Ambiguous layouts remain unresolved.

## Regression coverage

- A verified dual-architecture installer with x86 and x64 application payloads can be classified as supporting both.
- An x86 setup stub containing only an x86 application remains x86.
- An x64 setup stub containing only an x64 application remains x64.
- An ordinary or uninspectable unknown-architecture `.exe` remains unknown and is rejected when the manifest does not permit unknown architecture.
- An Inno Setup installer is not considered dual-architecture merely because of its format.
- Separate x86 and x64 sibling artifacts do not prove that an unrelated setup executable contains both payloads.
- Inspection never executes any installer or extracted application binary.
- Existing explicit publisher-metadata evidence behavior remains covered.
- Existing unrelated architecture-eligibility and update-decision tests remain green.

## Core Temp fixture

The official Core Temp 1.21 installer used for investigation:

- URL: `https://www.alcpu.com/CoreTemp/Core-Temp-setup-v1.21.0.207.exe`
- Official SHA-256: `FBF053DB5567D55D20F8D54B8930E95914FFD44073A62ED71AC9048C89D4ECB6`
- Downloaded artifact matched that SHA-256 and had a valid Authenticode signature from ALCPU.
- Static extraction revealed `Core Temp.exe$0` as x64 and `Core Temp.exe$1` as x86, both version 1.21.0.207.

This is a test fixture for the inspection capability, not a product-specific rule or manifest exception.

## Acceptance criteria

The change is complete only when the architecture inspection is integrated at the correct lifecycle boundary, focused and full regression suites pass, the Release build succeeds, and negative tests demonstrate that unknown architecture is never silently promoted to neutral.
