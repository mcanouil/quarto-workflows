# Changelog

## Unreleased

- refactor: Remove the `pin-files` input of the release workflow. A reusable workflow can check out its own commit with `job.workflow_sha` instead, which needs no rewrite under `.github/workflows/`. (#58)

## 2.9.0 (2026-10-28)

- feat: Add the `pin-files` input to the release workflow. The pins of the repository in the files it lists, such as `<repository>/.github/actions/<name>@X.Y.Z`, follow each release. (#57)

## 2.8.1 (2026-10-28)

- fix: Skip `test/` and `tests/` in the root render check of the release workflow when they hold a Quarto project, as `docs/` already is. Those test fixtures failed to render without their own configuration. (#56)

## 2.8.0 (2026-10-19)

- refactor: Write the extension manifest and CITATION.cff through the release-actions presets. (#54)

## 2.7.0 (2026-10-19)

- feat: Add the `path` input to the Pages workflow, so a caller can render and deploy a Quarto project other than `docs/`. (#53)
- perf: Fetch the whole history in the Pages workflow only when it resolves the latest version tag. (#53)

## 2.6.0 (2026-10-18)

- refactor: Remove the `setup-git-user` action, which no caller uses now that every workflow takes its token from `release-actions` `token`. (#52)

## 2.5.0 (2026-10-17)

- feat: Add the `tag` and `sha` outputs to the release workflow, so a later job of the caller can work on the release. (#51)
- feat: Add the `notes-header` input to the release workflow, a template from the caller at the start of the release body. (#51)
- refactor: Let `release-actions` v1.3.0 stop a repeated or unsafe release, and drop the steps that did this in the workflows. (#51)

## 2.4.0 (2026-10-17)

- feat: Add a `quarto-version` input to the extensions updates workflow, so a caller can run the updater on the Quarto pre-release. (#50)
- feat: Title a second project release on the same day `YYYY-MM-DD (2)`, and so on, instead of repeating the date. (#50)
- refactor: Resolve tokens with the `token` action of `release-actions`, and land the version bump and the thumbnail with its `land` action.
  The version bump pull request now comes from `release/<version>`, and a `GH_TOKEN` commits as the owner of that token. (#50)

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
