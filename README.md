# Quarto Actions Workflows

GitHub Actions workflows for Quarto projects.

## Usage

> [!NOTE]
> All workflows require a GitHub label `Type: CI/CD :robot:` to be available in your repository for automated PR management.

### [`release.yml`](.github/workflows/release.yml)

A unified reusable workflow for releasing Quarto extensions and presentations.
It auto-detects output formats, language runtimes, and project type via `quarto inspect`.

Key features include:

- **Auto-detection**: Output formats, engines (R/Python/Julia), TinyTeX, and slide-to-PDF needs are detected automatically from `.qmd` files.
- **Repo type detection**: A repo is treated as an extension when it owns the manifest derived from its name (`owner/quarto-<name>` then `_extensions/<name>/_extension.yml`); such repos use semantic versioning. Every other repo is a project and uses date-based versioning, so a project that merely installs extensions as dependencies is not mistaken for one. Set the `repo-type` input to `extension` or `project` to override the detection.
- **Project directory detection**: Renders from `docs/` when `docs/_quarto.yml` exists, otherwise from the repository root.
- **Quarto project type**: The project type and output directory are read from `quarto inspect`, so `website` and `book` projects (and any custom `output-dir`) are deployed from the directory Quarto reports. Non-default projects render as a whole project, while default projects render each detected format individually.
- **Extension assets**: Packages `_extensions/` as `{name}-v{version}.tar.gz` and `.zip` release assets.
- **Multi-format rendering**: Renders each detected format individually via `quarto render --to`.
- **Slide-to-PDF conversion**: Automatic PDF generation using DeckTape for custom Reveal.js format extensions and presentations.
- **GitHub integration**: Creates PRs for version bumps, deploys to GitHub Pages, and publishes releases with assets and install instructions.

#### Inputs

| Input       | Default     | Description                                                                                         |
| ----------- | ----------- | --------------------------------------------------------------------------------------------------- |
| `version`   | `"minor"`   | Version bump type (`patch`/`minor`/`major`). Used for extensions only; ignored for projects.        |
| `repo-type` | `"auto"`    | Repo type (`auto`/`extension`/`project`). `auto` detects from the repo name and owned manifest.     |
| `quarto`    | `"release"` | Quarto version to install (`release` or `pre-release`).                                             |
| `gh-app-id` |             | GitHub App ID for authentication (optional).                                                        |

#### Secrets

The workflow accepts secrets via `secrets: inherit`.
When a GitHub App is used for authentication (recommended), the following secrets should be configured in the calling repository:

| Secret    | Description                                                                                                   |
| --------- | ------------------------------------------------------------------------------------------------------------- |
| `APP_KEY` | GitHub App private key. Required when `gh-app-id` is provided. Used to generate tokens for GitHub operations. |

Alternatively, if not using a GitHub App, the workflow falls back to the default `GITHUB_TOKEN`.
A `GH_TOKEN` secret (personal access token) can also be provided as an override.

#### Example

A reusable workflow cannot raise the caller's token, so the calling job grants the write scopes the release needs.
Everything else in the calling workflow stays read-only.

```yaml
name: Release

on:
  workflow_dispatch:
    inputs:
      version:
        type: choice
        description: "Version"
        default: "minor"
        options:
          - "patch"
          - "minor"
          - "major"
      quarto:
        type: choice
        description: "Quarto version"
        default: "release"
        options:
          - "release"
          - "pre-release"

permissions:
  contents: read

jobs:
  release:
    uses: mcanouil/quarto-workflows/.github/workflows/release.yml@main
    permissions:
      contents: write
      pull-requests: write
      pages: write
      id-token: write
    secrets: inherit
    with:
      gh-app-id: ${{ vars.APP_ID }}
      version: ${{ inputs.version }}
      quarto: ${{ inputs.quarto }}
```

The `version` input is only relevant for extension repos, meaning repos that own a matching `_extensions/<name>/_extension.yml`.
A project ignores it and uses date-based versioning taken from `CITATION.cff`, so its caller drops both the `version` dispatch input and the `version:` line under `with:`.
