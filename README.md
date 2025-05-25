# Quarto Actions Workflows

GitHub Actions workflows for Quarto projects.

## Usage

### `release-extension.yml`

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
    uses: mcanouil/quarto-extension-actions/.github/workflows/release-extension.yml@main
    secrets: inherit
    with:
      version: "${{ github.event.inputs.version }}"
      formats: "html typst pdf docx revealjs beamer pptx"
      tinytex: true
      quarto: "${{ github.event.inputs.quarto }}"
```

### `release-revealjs.yml`

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
    uses: mcanouil/quarto-extension-actions/.github/workflows/release-revealjs.yml@main
    secrets: inherit
    with:
      quarto: "${{ github.event.inputs.quarto }}"
```
