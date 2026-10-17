# Changelog

## Unreleased

- feat: Add a `quarto-version` input to the extensions updates workflow, so a caller can run the updater on the Quarto pre-release.
- feat: Title a second project release on the same day `YYYY-MM-DD (2)`, and so on, instead of repeating the date.
- refactor: Resolve tokens with the `token` action of `release-actions`, and land the version bump and the thumbnail with its `land` action. The version bump pull request now comes from `release/<version>`, and a `GH_TOKEN` commits as the owner of that token.

## 2.3.0 (2026-10-16)

- fix: Stop the release when GitHub cannot say whether the tag or release exists, instead of reading the error as a free version. (#48)

## 2.2.1 (2026-10-16)

- fix: The thumbnail job no longer fails after its pull request merges. (#47)

## 2.2.0 (2026-10-16)

- fix: Refuse an existing tag or release before the version bump is pushed. (#46)
- fix: Name a missing or differently written version line before the version bump. (#46)

## 2.1.0 (2026-10-16)

- feat: Release notes of this repository now come from the changelog. (#45)

## 2.0.0 (2026-08-06)

- feat!: Skip draft pull requests in the Pages workflow, and scope the release permissions per job. (#44)

## 1.0.0 (2026-08-02)

- feat: Initial release.
