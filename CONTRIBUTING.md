# Contributing to TwinPixCleaner

Thanks for your interest in contributing! This document covers how to report issues, suggest features, and submit changes.

## Reporting bugs or requesting features

Please use the issue templates:
- [Report a bug](https://github.com/AkshayKrGupta/TwinPixCleaner/issues/new?template=bug_report.yml)
- [Request a feature](https://github.com/AkshayKrGupta/TwinPixCleaner/issues/new?template=feature_request.yml)

Search [existing issues](https://github.com/AkshayKrGupta/TwinPixCleaner/issues) first to avoid duplicates. For security vulnerabilities, see [SECURITY.md](SECURITY.md) instead of filing a public issue.

## Development setup

See the [README's "Build from Source"](README.md#option-2-build-from-source) section for build commands and the Apple Photos permission caveat (you need `./scripts/build_app.sh` and the bundled `.app`, not `swift run`, to test Photos-library scanning).

There is no test target in `Package.swift` currently — don't assume `swift test` works.

## Branching strategy

- Never commit directly to `main` or `dev`.
- Branch off the latest `dev`:
  ```bash
  git fetch origin dev
  git checkout -b feat/your-feature-name origin/dev   # new features
  git checkout -b fix/your-fix-name origin/dev         # bug fixes
  ```
- Open your pull request against `dev`, not `main`. Releases are merged from `dev` into `main` separately.

## Commit messages

Format: `(flag) message`

- Flags: `(fix)`, `(feature)`, `(ui)` — pick whichever matches the change. Use another short lowercase flag (e.g. `(chore)`, `(refactor)`) only if none of those fit.
- No emoji.
- Cover, in plain language: what changed, which feature/screen it affects, and what value it delivers. Skip filler like "updated code."

Example:
```
(feature) add pagination to results list

Lets users page through large duplicate sets instead of loading
everything at once, reducing memory use on big scans.
```

## Pull requests

- Keep PRs focused — one logical change per PR is easier to review than a bundle of unrelated fixes.
- Fill out the PR template: what changed, how you tested it, and link the issue it addresses if there is one.
- Build and run the actual `.app` bundle (`./scripts/build_app.sh`) to verify UI/Photos-related changes before opening the PR — `swift build` passing isn't sufficient proof a UI change works.

## Code style

- Follow the existing project structure: `Core/` holds logic with no SwiftUI dependency, `UI/` holds views and the view model.
- Reuse existing constants and components (`Core/AppConstants.swift` for strings/icons/metrics, `FrostTheme.swift` for colors) instead of inlining new literals.
- Prefer the smallest change that solves the problem — this project favors straightforward SwiftUI over premature abstraction.

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you're expected to uphold it.
