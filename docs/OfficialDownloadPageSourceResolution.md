# Official Download Page Source Resolution

## Phase 12.5B

This batch establishes a constrained HTML source-resolution capability for official software download pages.

It is **not** an arbitrary-web scraper.

The resolver currently uses a small identity surface:

- HTML `<title>`;
- `application-name` metadata;
- Open Graph `og:title` / `og:site_name`;
- the first `h1`;
- an optional canonical `link rel="canonical"`.

The result is normalized source identity. It does not select a release, choose an installer, or return downloadable artifacts.

## Relationship to HTML fallback approaches

HTML fallback is technically capable of supporting software sites that do not expose a structured release API. Obtainium demonstrates a broader approach that can use configurable regular expressions or CSS selectors to extract versions and download links.

Wintainium does not adopt arbitrary page-specific scraping configuration at this stage.

The initial web-source boundary deliberately establishes a narrower, deterministic capability:

1. accept an HTTP/HTTPS page;
2. retrieve the HTML document as data;
3. inspect well-defined identity metadata;
4. establish normalized application/source facts when identity is explicit;
5. return a structured failure when identity cannot be established.

This keeps page interpretation behind the provider boundary without turning Core into a general-purpose scraper.

## Deferred responsibilities

Download links and release/artifact candidates are intentionally outside source resolution.

Later provider release/artifact discovery can use the normalized `pageUri`. Core remains responsible for environment-aware artifact eligibility and final selection.

Interactive, authenticated, JavaScript-only, anti-bot, or otherwise non-deterministic pages remain candidates for structured `InteractiveResolutionRequired` or `SourceUnsupported` outcomes.

## Security boundary

The resolver treats page content as untrusted data. It does not execute scripts, follow page-provided commands, or execute downloaded content.

Network timeout, redirect, content-size, and trust controls remain part of the provider hardening work before broad real-world validation.
