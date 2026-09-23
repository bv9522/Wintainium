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
- optional `Policy` — an advanced Core policy override. Normal desktop onboarding omits this parameter and lets Core resolve its default application policy.
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
4. default application-policy resolution when no override is supplied;
5. normalization through `New-WintainiumApplicationDefinitionFromSource`;
6. persistence through `Set-WintainiumApplicationDefinition`;
7. operation correlation and structured diagnostics.

Providers own source-specific interpretation only.

The desktop adapter exposes the command without reproducing Core behavior.

## Provider selection

Core considers capable source-resolution providers in deterministic descriptor order.

- zero successful resolutions → structured unsupported/unavailable/interactive result;
- exactly one successful resolution → continue to policy resolution and normalization;
- more than one successful resolution → `SourceAmbiguous` and no persistence.

A provider that does not advertise source resolution remains valid and is not invoked for onboarding.

## Core-owned default policy

When the caller omits `Policy`, Core resolves the default application policy from the registered plugin descriptors. The desktop client does not construct this object.

The current default policy requires:

- exactly one eligible installer plugin supporting Core contract version `1`;
- exactly one eligible reconciliation plugin supporting application-state reconciliation under Core contract version `1`;
- the selected installer's supported artifact formats limited to the formats recognized by Core (`zip`, `msi`, and `exe`);
- stable release channel;
- `x64`, `x86`, `arm64`, and `neutral` artifact architectures;
- unknown artifact architecture disallowed.

Zero or multiple eligible installer/reconciliation plugins produce a structured `ApplicationPolicyUnavailable` or `ApplicationPolicyAmbiguous` failure. Core does not silently select a plugin when the policy is ambiguous.

This keeps lifecycle policy authoritative in Core while allowing the desktop client to remain a thin presentation/application client.

## Persistence

Only a successfully normalized application definition is passed to the existing application-definition persistence boundary.

A failed source resolution, failed default-policy resolution, or failed normalization does not create a manifest.

Installed application observations remain owned by `installed-state.json`; onboarding never mutates installed state.

## Desktop adapter

The C# adapter exposes:

`WintainiumCoreClient.OnboardApplicationAsync`

and the presentation service:

`WintainiumApplicationOnboardingService.OnboardAsync`

Both may omit the policy object and allow Core to resolve the authoritative default. If an explicit policy override is ever supplied by an upper layer, the desktop service treats it as opaque and does not construct or interpret provider-specific settings.

## Non-goals

This phase does not:

- perform release discovery;
- select a final artifact;
- download or install software;
- modify installed state;
- scrape arbitrary web pages;
- execute page scripts;
- define durable desktop settings;
- move lifecycle policy construction into the GUI.
