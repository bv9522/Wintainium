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

The result is normalized source identity, with a product name kept separate from an optional HTML description. The resolver removes known page-section labels (such as SourceForge's `Files`) from supported product-name cases and normalizes known official-page taglines when the page concatenates them into the product identity. It does not select a release, choose an installer, or return downloadable artifacts.

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

## Layered release-version evidence

Official download-page release discovery uses cumulative, constrained evidence layers rather than application-specific parsing rules. It first recognizes versioned release sections and explicitly labeled version metadata within those sections. When a publisher places the current version at page level, the resolver accepts established explicit forms such as a `Current Version` field or a stable-release statement. It also recognizes a version explicitly paired with the Windows platform in compact metadata (for example, `Version 3.0.24 • Windows • 43 MB`), then scopes artifact discovery to the Windows heading section.

The platform-scoped form does not authorize arbitrary version extraction from filenames or unrelated page text. A version paired with another platform is not accepted as Windows release evidence. Existing release-section, SourceForge, and explicit current-version paths remain in place; pages that do not provide sufficient evidence continue to produce structured no-release results.

Interactive, authenticated, JavaScript-only, anti-bot, or otherwise non-deterministic pages remain candidates for structured `InteractiveResolutionRequired` or `SourceUnsupported` outcomes.

## Security boundary

The resolver treats page content as untrusted data. It does not execute scripts, follow page-provided commands, or execute downloaded content.

Network timeout, redirect, content-size, and trust controls remain part of the provider hardening work before broad real-world validation.


## Structured platform metadata fallback

Some publishers expose current platform downloads in a JavaScript object (for example, a `PLATFORMS` map) rather than heading-delimited HTML sections. The provider has a final conditional text-parsing layer for this structure; it does not execute JavaScript. It accepts entries only when they declare a Windows platform name, a strictly formatted version, and an HTTP/HTTPS location resolving to a supported artifact filename. Artifacts are grouped by declared version and normalized through the existing release/artifact parser. Non-Windows entries, malformed metadata, unsafe schemes, unsupported filenames, and duplicate locations are ignored. Existing heading-based and page-level resolvers retain priority.
