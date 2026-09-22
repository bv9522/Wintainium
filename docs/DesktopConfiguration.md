# Desktop Configuration Foundation

## Purpose

Phase 11I establishes the desktop configuration boundary without inventing a new persistent storage contract. The desktop client may own presentation preferences that are inherently client-specific, but durable storage remains deferred until its ownership and upgrade semantics are explicitly defined.

## Current desktop-owned settings

The initial desktop settings model contains:

- Theme preference: System, Light, or Dark.
- Visual style: Windows 11, Y2K, or Frutiger Aero.

These settings are represented by WintainiumDesktopSettings and accessed through WintainiumDesktopSettingsService.

The service is owned at application scope so multiple desktop windows observe the same settings during a running session.

## Persistence boundary

The current service is intentionally in-memory only.

It does not:

- choose a manifest root;
- choose a user-data directory;
- create a second Core configuration store;
- persist application policy;
- persist application notes;
- persist source/provider configuration;
- persist update scheduling;
- infer installed state;
- modify Core lifecycle behavior.

Durable desktop configuration requires a later documented persistence contract that identifies the owner, storage location, upgrade behavior, and failure semantics.

## Settings categories

The Settings window retains the agreed categories:

- General
- Appearance
- Updates
- Sources
- Advanced

Only Appearance has concrete settings in this foundation batch. The other categories remain structural surfaces until their underlying contracts exist.

The Updates category concerns Wintainium itself, not the update state of managed applications.

## Architectural rule

The desktop configuration layer is presentation/application configuration. It must not become a parallel implementation of Core business rules.

When a setting affects discovery, update decisions, installation, provider behavior, verification, reconciliation, or other engine-owned policy, the authoritative contract must be established at the Core boundary before the desktop client persists or enforces that setting.
