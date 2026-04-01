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
- **Project type detection**: Semantic versioning for extensions (repos with `_extensions/`), date-based versioning for presentations.
- **Project directory detection**: Renders from `docs/` when `docs/_quarto.yml` exists, otherwise from the repository root.
- **Extension assets**: Packages `_extensions/` as `{name}-v{version}.tar.gz` and `.zip` release assets.
- **Multi-format rendering**: Renders each detected format individually via `quarto render --to`.
- **Slide-to-PDF conversion**: Automatic PDF generation using DeckTape for custom Reveal.js format extensions and presentations.
- **GitHub integration**: Creates PRs for version bumps, deploys to GitHub Pages, and publishes releases with assets and install instructions.

#### Inputs

| Input       | Default     | Description                                                                                       |
| ----------- | ----------- | ------------------------------------------------------------------------------------------------- |
| `version`   | `"minor"`   | Version bump type (`patch`/`minor`/`major`). Used for extensions only; ignored for presentations. |
| `quarto`    | `"release"` | Quarto version to install (`release` or `pre-release`).                                           |
| `gh-app-id` |             | GitHub App ID for authentication (optional).                                                      |

#### Example

The `version` input is only relevant for extension repos (repos with `_extensions/`).
For presentations, it is ignored and date-based versioning is used automatically.

```yaml
name: Release

on:
  workflow_dispatch:
    inputs:
      version:
        type: choice
        description: "Version"
        required: false
        default: "minor"
        options:
          - "patch"
          - "minor"
          - "major"
      quarto:
        type: choice
        description: "Quarto version"
        required: false
        default: "release"
        options:
          - "release"
          - "pre-release"

permissions:
  contents: write
  pull-requests: write
  id-token: write
  pages: write

jobs:
  release:
    uses: mcanouil/quarto-workflows/.github/workflows/release.yml@main
    secrets: inherit
    with:
      gh-app-id: ${{ vars.APP_ID }}
      version: "${{ github.event.inputs.version }}"
      quarto: "${{ github.event.inputs.quarto }}"
```

### Legacy workflows

The following workflows are still available for backwards compatibility but are superseded by [`release.yml`](.github/workflows/release.yml).

- [`release-extension.yml`](.github/workflows/release-extension.yml): requires explicit `formats`, `tinytex`, `r`, `python`, `julia`, and `post-render` inputs.
- [`release-revealjs.yml`](.github/workflows/release-revealjs.yml): dedicated Reveal.js presentation workflow with date-based versioning.
