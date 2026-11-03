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


## Adjacent SHA-256 sidecar resolution

After the existing page-level checksum parsers and structured release evidence have had priority, the provider conditionally checks for an adjacent .sha256 resource for each artifact in the highest numerically versioned release that still lacks SHA-256 evidence. Historical release sections are not queried, avoiding unnecessary network requests for obsolete artifacts. If release versions cannot be parsed numerically, the provider conservatively checks the publisher's first release section. The sidecar URI is derived from the exact artifact path; query strings and fragments are not copied. This supports both conventional text sidecars (a digest with an optional filename) and publisher checksum landing pages that render an explicitly labelled SHA-256 digest as HTML.

The resolver accepts exactly one 64-character hexadecimal digest. When a text sidecar declares a filename, it must match the artifact filename. HTML responses must contain one explicitly labelled SHA-256 checksum. Ambiguous/multiple digests, malformed content, mismatched filenames, oversized responses, credentials, unsupported schemes, and HTTPS-to-HTTP redirects are rejected. HTTPS redirects to publisher-designated mirrors remain supported, provided the final resource still has a .sha256 path.

Sidecar retrieval is additive and conditional: existing page or release-provider SHA-256 evidence takes precedence and prevents an unnecessary sidecar request. A missing or rejected sidecar does not make release discovery fail and does not relax the installer's verification requirements; the artifact remains without SHA-256 evidence and downstream verification continues to reject it when SHA-256 is required. Diagnostics expose aggregate attempt, resolution, rejection, and unavailable counts without logging digest values or full sidecar URLs.


## Interactive source access challenges

Official-page retrieval distinguishes a publisher page that is unsupported from a supported HTTP/HTTPS page that cannot be retrieved by the provider's non-browser HTTP client. When an HTTP failure exposes a recognized anti-bot challenge response, the provider returns the contract status `InteractiveResolutionRequired` and error code `SourceAccessChallengeRequired` rather than the generic `SourceUnavailable` result.

The current implementation recognizes Cloudflare challenge responses through the `Cf-Mitigated: challenge` response header, with a conservative fallback for a 403 Cloudflare response containing the known challenge-document markers. Diagnostics retain the HTTP status, safe final URL, content type, server, Cloudflare request identifier when supplied, challenge classification, and request duration. Response bodies, challenge tokens, cookies, and signed query strings are not copied into diagnostics.

Wintainium does not execute challenge scripts, replay browser fingerprints, extract challenge tokens, or automate challenge solving. The classification tells the user that an interactive browser route or another official publisher endpoint is required. This is a retrieval/access limitation, not evidence that the publisher page or software is invalid.
