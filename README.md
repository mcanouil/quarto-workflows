# Quarto Actions Workflows

GitHub Actions workflows for Quarto projects.

## Usage

> [!NOTE]
> Both workflows require a GitHub label `Type: CI/CD :robot:` to be available in your repository for automated PR management.

### [`release-extension.yml`](.github/workflows/release-extension.yml)

A comprehensive reusable workflow for releasing Quarto extensions with automatic versioning, multi-format rendering, and GitHub Pages deployment.

Key features include:

- **Version Management**: Automatic semantic versioning (major/minor/patch) with manifest updates.
- **Multi-language Support**: Optional R, Python, and Julia environments with dependency management.
- **Multi-format Rendering**: Supports HTML, PDF, DOCX, Reveal.js, Beamer, and PowerPoint outputs.
- **Slide-to-PDF Conversion**: Automatic generation of PDF versions using DeckTape.
- **Template Thumbnails**: Auto-generates and updates template preview images.
- **GitHub Integration**: Creates PRs for version bumps, deploys to Pages, and publishes releases with assets.

```yaml
name: Release Quarto Extension

on:
  workflow_dispatch:
    inputs:
      version:
        type: choice
        description: "Version"
        required: false
        default: "patch"
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
    uses: mcanouil/quarto-workflows/.github/workflows/release-extension.yml@main
    secrets: inherit
    with:
      version: "${{ github.event.inputs.version }}"
      formats: "html typst pdf docx revealjs beamer pptx"
      quarto: "${{ github.event.inputs.quarto }}"
      tinytex: true
      r: false
      python: false
      julia: false
      gh-token: "${{ secrets.GITHUB_TOKEN }}"
      gh-app-id: "${{ vars.APP_ID }}"
```

### [`release-revealjs.yml`](.github/workflows/release-revealjs.yml)

A streamlined workflow specifically designed for building and deploying Reveal.js presentations with Quarto.

Key features include:

- **Version Management**: Date-based versioning with automatic suffix handling for multiple releases.
- **Multi-language Support**: Optional R, Python, and Julia environments with dependency management.
- **Slide-to-PDF Conversion**: Automatic generation of PDF versions using DeckTape.
- **GitHub Integration**: Creates PRs for version bumps, deploys to Pages, and publishes releases with assets.

```yaml
name: Release Reveal.js Slides

on:
  workflow_dispatch:
    inputs:
      quarto:
        description: "Quarto version"
        required: true
        default: "release"
        type: string

permissions:
  contents: write
  pull-requests: write
  id-token: write
  pages: write

jobs:
  release:
    uses: mcanouil/quarto-workflows/.github/workflows/release-revealjs.yml@main
    secrets: inherit
    with:
      quarto: "${{ github.event.inputs.quarto }}"
      r: false
      python: false
      julia: false
      gh-token: "${{ secrets.GITHUB_TOKEN }}"
      gh-app-id: "${{ vars.APP_ID }}"
```
