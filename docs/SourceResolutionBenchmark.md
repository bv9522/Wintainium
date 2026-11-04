# Source Resolution Benchmark

## Purpose

The source-resolution benchmark protects the identity contract against regressions across a representative set of real-world software repositories. It complements the synthetic 100-case URL-shape stress matrix; it does not replace it.

The corpus is stored in `tests/Fixtures/SourceResolutionBenchmark/real-world-github-applications.json`. Each record names a software project and its GitHub repository in `owner/repository` form.

All 100 repository paths were individually checked against GitHub repository search when the corpus was assembled on 2026-11-03. The check establishes that the exact public repository identifier was discoverable at that time; it does not establish publisher ownership or that the repository is the preferred official release channel.

## What the benchmark verifies

For each of the 100 repository records, the test exercises one of eight URL shapes:

- Repository root
- `www.github.com` host with a `.git` suffix
- Releases collection
- Release-tag page
- Branch tree page
- Issue page
- Commit page
- Actions page with a query string

The test verifies that the provider consistently derives the expected repository-based application ID, display-name slug, publisher/owner, canonical repository URI, provider settings, source context, and operation correlation. Release-tag context must be present only for release-tag URLs.

The test performs no network access. Source identity parsing is deterministic and must not depend on GitHub API availability.

## What the benchmark does not claim

This corpus is a source-identity regression benchmark, not proof that all 100 repositories are currently reachable, maintained, or official publisher endpoints. It does not verify repository ownership, application publisher identity, whether a repository is the project's preferred release channel, or whether the repository slug is the ideal end-user display name. Those claims require separate evidence and capabilities.

In particular, the current GitHub resolver derives identity from the repository path. It does not query GitHub to prove that the repository exists. The benchmark must not be interpreted as 100/100 independently verified publisher identities.

The current reference source-resolution provider is GitHub Releases. Non-GitHub sources remain unsupported unless a registered provider explicitly advertises and safely resolves that source family. The benchmark must not reward false-positive recognition merely to increase coverage.

## Acceptance criteria

A benchmark case passes only when:

1. The expected provider recognizes the source family.
2. The resolver returns the expected stable source identity and canonical URI.
3. Provider settings and source context preserve the correct upstream repository facts.
4. Correlation data is preserved.
5. Unsupported or ambiguous sources are rejected safely rather than assigned a guessed identity.
6. No network request is needed for URL-to-repository identity normalization.

A successful resolver response for the wrong repository is a failure. A safe unsupported result is preferable to a false-positive identity.

## Resolver competition policy

Core continues to invoke every provider advertising source resolution. Exactly one successful result is accepted; zero successes produce a structured failure; multiple successes produce `SourceAmbiguous`. A non-decline failure from a competing provider is retained as a warning when another provider succeeds. This conservative policy remains in place until a broader provider ecosystem supplies evidence for a different precedence model.

## Follow-on coverage

As additional source-resolution providers are introduced, extend the corpus with real application sources from those source families. Each addition must include an expected provider, expected identity facts, and negative/ambiguous controls. Do not retrofit provider-specific assumptions into Core or weaken the one-success safety rule to make the score look better.
