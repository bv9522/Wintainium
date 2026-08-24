# Roadmap

This roadmap is directional and may change through documented decisions.

## Foundation

- Establish repository conventions and architecture documentation.
- Decide the public PowerShell module contract and plugin contract before
  implementing providers.
- Add development, test, and release policies.

## Version 0.1 — Usable engine

- JSON application manifests
- GitHub Releases source plugin
- Portable ZIP and MSI installer plugins
- Basic EXE installer plugin
- Command-line PowerShell workflow

## Phase 3 — Provider architecture

- 3A: Provider Contract v1
- 3B: Provider resolution and capability enforcement
- 3C: Fixed provider operation boundary
- 3D: Reusable offline provider contract-test harness
- 3E: First real reference provider — GitHub Releases
- 3F: Documentation and final Phase 3 lock

GitHub is the first reference provider, not the universal source model. Future
providers are expected to support official vendor websites, vendor APIs,
feeds, CDNs, and other authoritative distribution sources without changing the
Core provider boundary.

## Version 0.5 — Extensible operation

- Stable plugin framework
- Configuration system and logging
- Multiple application management
- Update-all command
- Additional official-source providers beyond GitHub

## Version 1.0 — Desktop experience

- C#/.NET GUI over the PowerShell engine
- Plugin manager
- Automatic scheduling and settings
- Release packaging and upgrade path
