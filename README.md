# Quarto Actions Workflows

GitHub Actions workflows for Quarto projects.

## Usage

> [!NOTE]
> All workflows require a GitHub label `Type: CI/CD :robot:` to be available in your repository for automated PR management.

### [`release.yml`](.github/workflows/release.yml)

A unified reusable workflow for releasing Quarto extensions and presentations.
It auto-detects output formats, language runtimes, and project type via `quarto inspect`.

Key features include:

- **Auto-detection**: Output formats, engines (R/Python/Julia), and TinyTeX are detected by the [`setup-quarto-compute`](#setup-quarto-compute) action, shared with `pages.yml`. Slide-to-PDF needs are derived from the detected formats.
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

### [`pages.yml`](.github/workflows/pages.yml)

A reusable workflow that renders the documentation website under `docs/` and deploys it to GitHub Pages.
The Release workflow calls it after tagging, so the published site describes the version users can install.
It is also dispatchable on its own, and a pull request that calls it renders the site as a check without deploying.

Key features include:

- **Released source by default**: The latest version tag is resolved and rendered, unless `ref` or `use-main-as-release` says otherwise. Pull requests always render their own head.
- **Extension mirror**: `docs/_scripts/sync-extension.sh` is run when present, so a shortcode contributed by the repository's own extension is on disk before Quarto builds its extension registry.
- **Compute environment**: R, Python, Julia, TinyTeX, and Chrome libraries are installed from what [`setup-quarto-compute`](#setup-quarto-compute) detects, so pages that execute code render.
- **Single deployment at a time**: Pages runs queue rather than cancel; pull request renders get a per-ref concurrency group and run in parallel.

#### Inputs

| Input                 | Default     | Description                                                                        |
| --------------------- | ----------- | ---------------------------------------------------------------------------------- |
| `ref`                 | `""`        | Commit or ref to build. Defaults to the latest version tag.                        |
| `use-main-as-release` | `false`     | Render from the triggering ref instead of the latest version tag.                   |
| `quarto`              | `"release"` | Quarto version to install (`release` or `pre-release`).                            |

#### Example

```yaml
name: Pages

on:
  pull_request:
    paths:
      - "docs/**"
      - "_extensions/**"
      - "CHANGELOG.md"
      - ".github/workflows/pages.yml"
  workflow_dispatch:
    inputs:
      use-main-as-release:
        type: boolean
        description: "Render from the default branch instead of the latest version tag"
        default: false
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
  pages:
    uses: mcanouil/quarto-workflows/.github/workflows/pages.yml@main
    permissions:
      contents: read
      pages: write
      id-token: write
    with:
      use-main-as-release: ${{ inputs.use-main-as-release || false }}
      quarto: ${{ inputs.quarto || 'release' }}
```

## Actions

### [`setup-quarto-compute`](.github/actions/setup-quarto-compute/action.yml)

A composite action that reads what a Quarto project needs from `quarto inspect`, then installs only that.
It is used by both `release.yml` and `pages.yml`, and expects Quarto to be installed already, along with any extension the project resolves.

Engines come from the project-level inspection, so `.qmd`, `.ipynb`, and `.md` inputs all count.
Formats are derived from that same inspection rather than from a pass over every input, since a project inspection reports engines but no resolved formats.
They are collected from the project configuration, the front matter of each `.qmd` input, and the `_metadata.yml` files above it, which is where Quarto itself reads them from.
Reading those `_metadata.yml` files needs `yq`, which the GitHub-hosted runners provide.
Dependency manifests are looked up in the project directory first and the repository root second, which is how a `docs/` website renders with a `pyproject.toml` or `renv.lock` kept at the root.

A Python environment is left activated by `uv`, so later steps render with it without sourcing anything.
Inspection does not run pre-render scripts, so a document generated by one is invisible to detection: an engine used only by a generated document has to be present in a committed document as well.
The detected formats and engines are written to the job summary by the action itself, so callers do not repeat them.

#### Inputs

| Input      | Default | Description                                                                                                         |
| ---------- | ------- | -------------------------------------------------------------------------------------------------------------------- |
| `path`     | `"."`   | Quarto project directory or single document to inspect.                                                             |
| `chromium` | `"auto"`| Install Chrome libraries: `auto` only when a LaTeX-bound format is detected, `true` always, `false` never.           |

#### Outputs

| Output         | Description                                                        |
| -------------- | ------------------------------------------------------------------- |
| `formats`      | Space-separated output formats detected across the project.        |
| `engines`      | Space-separated engines detected across the project.               |
| `need-r`       | Whether the `knitr` engine is used.                                |
| `need-python`  | Whether the `jupyter` engine is used.                              |
| `need-julia`   | Whether the `julia` engine is used.                                |
| `need-tinytex` | Whether a LaTeX-bound format is produced (Typst does not count).   |
| `input-files`  | Newline-separated input files the project renders, as absolute paths. |

#### Installed per detection

| Detected                        | Installed                                                                                  |
| ------------------------------- | ------------------------------------------------------------------------------------------ |
| `knitr`                         | R (public RSPM binaries), then `renv` when a `renv.lock` is found, otherwise a cached `knitr` and `rmarkdown`. |
| `jupyter`                       | `uv`, with the interpreter it resolves from `requires-python`, then `uv sync` when a `pyproject.toml` is found, otherwise a bootstrap environment with `jupyter` and `papermill`. |
| `julia`                         | Julia and a package cache, then `Pkg.instantiate()` and `IJulia`.                          |
| `pdf`, `beamer`, `latex` format | TinyTeX, cached across runs and put on `PATH`, and the Chrome libraries Quarto needs to turn diagrams into images. |

#### Tests

[`test-setup-quarto-compute.yml`](.github/workflows/test-setup-quarto-compute.yml) runs the action against the fixtures under [`tests/`](tests), one per install path: `knitr` with a `renv.lock`, `jupyter` with and without a `pyproject.toml`, `julia`, a PDF format, and a Reveal.js deck converted with DeckTape as the release workflow does.
Each fixture asserts what detection reported, checks that the toolchain it installed is usable, and renders.
It runs on pull requests touching the action, its fixtures, or the slides script, on dispatch, and monthly.
