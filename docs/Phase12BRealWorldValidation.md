# Phase 12B — Real-World Source Validation

## Status

12.10B is the live-source validation checkpoint for Phase 12B.

This checkpoint validates the two implemented source-resolution vertical slices against real public source URLs:

- GitHub repository/release URLs.
- Structured official download pages.

It validates source resolution only. It does not execute an update, download an installer, install software, or require production installer/reconciliation plugins.

## Validation boundary

The live validation test is:

`tests/Integration/Phase12B-RealWorldSourceValidation.Tests.ps1`

The checkpoint exercises:

1. A live GitHub repository URL.
2. A live GitHub releases URL.
3. The live 7-Zip official download page.
4. The live VLC official download page.

The GitHub source resolver intentionally performs no network request during source identity resolution. Its real-world cases therefore validate that actual public GitHub URL forms are accepted and normalized by the resolver.

The official-download-page provider does make a live HTTPS request because page identity is derived from the returned HTML. The test therefore depends on network availability and the current public page exposing supported identity metadata.

## What this does not validate

This checkpoint does not prove:

- release discovery from the live GitHub API;
- artifact selection against live releases;
- downloading;
- verification;
- installation;
- reconciliation;
- desktop persistence across process restarts;
- successful end-to-end onboarding where the current repository lacks production installer/reconciliation plugins.

Those belong to later integration work.

## Checkpoint

From the repository root:

```powershell
Invoke-Pester .\tests\Integration\Phase12B-RealWorldSourceValidation.Tests.ps1
```

Expected result: **4/4 green**.

If a live official page changes its metadata or is temporarily unavailable, that is a real-world validation failure to investigate rather than something to hide with a fixture or a fallback parser.
