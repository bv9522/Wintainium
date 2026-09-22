# Application Onboarding Contract

## Purpose

Phase 12.9 establishes the public Core boundary used by the desktop client when a user supplies an official source URL.

The desktop flow is:

**Add Software → Core onboarding → source resolution → normalized application definition → persistence → collection refresh**

The desktop client supplies the source URI and presents the structured result. It does not resolve providers, construct manifests, interpret provider settings, select artifacts, or persist files directly.

## Public command

The public Core command is:

`Invoke-WintainiumApplicationOnboarding`

Inputs:

- `SourceUri` — absolute HTTP/HTTPS URI supplied by the user.
- `ManifestRoot` — authoritative application-definition collection root.
- `Policy` — Core-owned application policy required to complete the application definition.
- optional `PluginRoot`, `SchemaPath`, and `OperationId`.

The command returns exactly one structured result containing:

- `OperationId`
- `IsSuccessful`
- `Status`
- `SourceResolution`
- `ApplicationDefinition`
- `ManifestPath`
- `Errors`
- `Warnings`
- `LogEvents`

## Ownership

Core owns:

1. source URI validation;
2. discovery of registered providers advertising `sourceResolution`;
3. provider resolution and ambiguity handling;
4. normalization through `New-WintainiumApplicationDefinitionFromSource`;
5. persistence through `Set-WintainiumApplicationDefinition`;
6. operation correlation and structured diagnostics.

Providers own source-specific interpretation only.

The desktop adapter exposes the command without reproducing Core behavior.

## Provider selection

Core considers capable source-resolution providers in deterministic descriptor order.

- zero successful resolutions → structured unsupported/unavailable/interactive result;
- exactly one successful resolution → continue to normalization;
- more than one successful resolution → `SourceAmbiguous` and no persistence.

A provider that does not advertise source resolution remains valid and is not invoked for onboarding.

## Persistence

Only a successfully normalized application definition is passed to the existing application-definition persistence boundary.

A failed source resolution or failed normalization does not create a manifest.

Installed application observations remain owned by `installed-state.json`; onboarding never mutates installed state.

## Policy boundary

The onboarding command deliberately requires Core-owned application policy. The source resolver does not invent installer, reconciliation, release, or artifact policy.

This preserves the Phase 12.4 ownership decision. A later policy contract must define how default or user-selected lifecycle policy is obtained without moving policy construction into the GUI.

Until that policy source exists, the desktop Add Software interaction must not silently invent installer or artifact choices.

## Desktop adapter

The C# adapter exposes:

`WintainiumCoreClient.OnboardApplicationAsync`

and the presentation service:

`WintainiumApplicationOnboardingService.OnboardAsync`

Both treat the policy as an opaque Core-owned object. The desktop layer maps the structured result to presentation models and does not interpret provider-specific settings.

## Non-goals

This phase does not:

- perform release discovery;
- select a final artifact;
- download or install software;
- modify installed state;
- scrape arbitrary web pages;
- execute page scripts;
- define durable desktop settings;
- invent lifecycle policy defaults.
