# GitHub Releases Provider

## Status

Phase 3E reference provider: implemented.

The GitHub Releases provider is the first real Wintainium provider implementation. It is a reference implementation of Provider Contract v1, not the architectural definition of a Wintainium source.

## Purpose

The provider translates GitHub Releases into normalized Wintainium release and artifact candidates.

Core remains source-agnostic. A future provider may discover software from a vendor website, vendor API, RSS/Atom feed, update manifest, CDN, or another official distribution source without changing the Core provider contract.

## Configuration

The provider requires a non-secret `source.settings.repository` value using the `owner/repository` form.

Example:

```json
"source": {
  "pluginId": "Wintainium.provider.github-releases",
  "requiredContractVersion": "1",
  "settings": {
    "repository": "neovim/neovim"
  }
}
```

An optional `maxPages` setting limits pagination to between 1 and 20 pages. The default is 10 pages. Each request asks GitHub for up to 100 releases.

Authentication credentials are intentionally not stored in manifests. Public GitHub Releases access requires no credential. Future authenticated-source support belongs to the secure credential/configuration layer rather than manifest data.

## Normalization

Each GitHub release becomes one normalized Wintainium release:

- `id` -> `ReleaseId`
- `tag_name` -> `Version`
- `prerelease = true` -> `Channel = prerelease`
- otherwise -> `Channel = stable`
- `published_at` -> `PublishedAt` when present and valid

Each GitHub release asset becomes an artifact candidate. The provider maps `.zip`, `.msi`, and `.exe` extensions to the corresponding Wintainium formats and reports other extensions as `unknown` rather than discarding them.

Architecture is inferred conservatively from filenames using recognizable `x64`/`amd64`, `x86`/`win32`/`i386`-style, and `arm64`/`aarch64` tokens. Unknown architecture remains `unknown`.

GitHub does not provide a cryptographic hash for every release asset through the standard Releases API, so the provider does not invent hash values. Download verification remains a later Core lifecycle responsibility.

## Failure behavior

The provider returns structured Provider Contract v1 outcomes:

- invalid repository configuration -> `ConfigurationInvalid`
- missing repository -> `SourceNotFound`
- authentication failure -> `AuthenticationFailed`
- rate limiting, forbidden access, or upstream server failure -> `SourceUnavailable`
- malformed release data -> `UpstreamResponseInvalid`
- zero releases -> successful `NoReleasesFound`

The provider never throws an expected source failure across the Core boundary.

## Network boundary

Only the provider contacts GitHub. Manifest discovery/import and Core manifest validation remain offline. The provider uses the public GitHub REST Releases endpoint and sends a stable User-Agent and GitHub's recommended media type.

## Architectural significance

GitHub is deliberately the first reference provider because it is a useful, well-defined public release source. Wintainium must not become GitHub-specific. The long-term provider ecosystem is expected to include multiple source families, especially official vendor sites and APIs for software that is not distributed through GitHub.
