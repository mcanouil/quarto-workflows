#!/usr/bin/env bash

# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# Resolves the Quarto version to install and prints it on stdout.
#
# Usage: resolve-quarto-version.sh <quarto> <path>
#
# Any value but `auto` is printed unchanged. `auto` reads `quarto-required`
# from the top-level extensions under <path>/_extensions and prints `release`
# when the latest stable Quarto satisfies every range, `pre-release` when only
# the latest pre-release does, and `release` whenever that cannot be decided.
#
# QUARTO_STABLE_VERSION and QUARTO_PRERELEASE_VERSION replace the lookup of the
# latest versions, so that the resolution can be tested without a network.

set -euo pipefail

QUARTO_INPUT=${1:-auto}
SITE_PATH=${2:-docs}
SITE_PATH=${SITE_PATH%/}

if [ "${QUARTO_INPUT}" != "auto" ]; then
  echo "${QUARTO_INPUT}"
  exit 0
fi

fallback() {
  echo "::warning::Could not resolve the Quarto version from the extensions (${1}); using release." >&2
  echo "release"
  exit 0
}

latest_version() {
  curl --silent --show-error --fail --location \
    --connect-timeout 10 --max-time 30 --retry 3 --retry-delay 2 \
    "https://quarto.org/docs/download/${1}.json" | jq -er '.version'
}

# Only the manifests directly under _extensions belong to the site. Those
# nested deeper are bundled inside an extension and carry their own constraints,
# which Quarto does not check against the site.
MANIFESTS=()
if [ -d "${SITE_PATH}/_extensions" ]; then
  while IFS= read -r manifest; do
    MANIFESTS+=("${manifest}")
  done < <(find "${SITE_PATH}/_extensions" -mindepth 2 -maxdepth 3 -type f \
    \( -name _extension.yml -o -name _extension.yaml \) | sort)
fi

RANGES=()
LABELS=()
for manifest in "${MANIFESTS[@]+"${MANIFESTS[@]}"}"; do
  range=$(sed -n -E 's/^quarto-required:[[:space:]]*(.*)$/\1/p' "${manifest}" | head -n 1)
  range=$(printf '%s' "${range}" | sed -E "s/[[:space:]]+#.*$//; s/^[\"']//; s/[\"'][[:space:]]*$//")
  if [ -n "${range}" ]; then
    RANGES+=("${range}")
    LABELS+=("${manifest#"${SITE_PATH}"/_extensions/}")
  fi
done

if [ "${#RANGES[@]}" -eq 0 ]; then
  echo "::notice::Quarto release: no extension under ${SITE_PATH}/_extensions sets quarto-required." >&2
  echo "release"
  exit 0
fi

STABLE=${QUARTO_STABLE_VERSION:-}
if [ -z "${STABLE}" ]; then
  STABLE=$(latest_version _download) || fallback "the stable version lookup failed"
fi

satisfies_all() {
  local version=$1 index
  FAILED=""
  for index in "${!RANGES[@]}"; do
    if ! npx --yes semver@7.8.6 -r "${RANGES[index]}" "${version}" >/dev/null 2>&1; then
      FAILED="${LABELS[index]} requires ${RANGES[index]}"
      return 1
    fi
  done
}

if satisfies_all "${STABLE}"; then
  echo "::notice::Quarto release (${STABLE}) satisfies every extension." >&2
  echo "release"
  exit 0
fi
STABLE_FAILED=${FAILED}

PRERELEASE=${QUARTO_PRERELEASE_VERSION:-}
if [ -z "${PRERELEASE}" ]; then
  PRERELEASE=$(latest_version _prerelease) || fallback "the pre-release version lookup failed"
fi

if satisfies_all "${PRERELEASE}"; then
  echo "::notice::Quarto pre-release (${PRERELEASE}) chosen: ${STABLE_FAILED}, which release (${STABLE}) does not satisfy." >&2
  echo "pre-release"
  exit 0
fi

fallback "${FAILED}, which neither release (${STABLE}) nor pre-release (${PRERELEASE}) satisfies, or the range is invalid"
