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
# latest versions, and QUARTO_DOWNLOAD_URL replaces the base URL of the lookup,
# so that the resolution can be tested without a network.
#
# When RESOLVE_SUMMARY_FILE names a file, a Markdown section that explains the
# result is appended to it.

set -euo pipefail

QUARTO_INPUT=${1:-auto}
SITE_PATH=${2:-docs}
SITE_PATH=${SITE_PATH%/}
DOWNLOAD_URL=${QUARTO_DOWNLOAD_URL:-https://quarto.org/docs/download}

STABLE=""
PRERELEASE=""
PRERELEASE_NOTE=""
RELEASE_CELLS=()
PRERELEASE_CELLS=()
RANGES=()
LABELS=()
CONSTRAINED=0

# Appends the explanation to RESOLVE_SUMMARY_FILE, then prints the result.
finish() {
  local result=$1 reasoning=$2 index range
  if [ -n "${RESOLVE_SUMMARY_FILE:-}" ]; then
    {
      echo "### Quarto version"
      echo
      echo "- Input: \`${QUARTO_INPUT}\`."
      echo "- Resolved: \`${result}\`."
      if [ -n "${STABLE}${PRERELEASE_NOTE}" ]; then
        echo "- Latest release: ${STABLE:-could not be found}."
        echo "- Latest pre-release: ${PRERELEASE:-${PRERELEASE_NOTE:-could not be found}}."
      fi
      if [ "${CONSTRAINED}" -gt 0 ]; then
        echo
        echo "| Extension | quarto-required | Release${STABLE:+ ${STABLE}} | Pre-release${PRERELEASE:+ ${PRERELEASE}} |"
        echo "| --- | --- | --- | --- |"
        for index in "${!LABELS[@]}"; do
          range=none
          if [ -n "${RANGES[index]}" ]; then
            range="\`${RANGES[index]//|/\\|}\`"
          fi
          echo "| ${LABELS[index]} | ${range} | ${RELEASE_CELLS[index]:-not checked} | ${PRERELEASE_CELLS[index]:-not checked} |"
        done
      fi
      echo
      echo "${reasoning}"
      echo
    } >>"${RESOLVE_SUMMARY_FILE}"
  fi
  echo "${result}"
  exit 0
}

if [ "${QUARTO_INPUT}" != "auto" ]; then
  finish "${QUARTO_INPUT}" "The value was passed through unchanged, so the extensions were not read."
fi

fallback() {
  echo "::warning::Could not resolve the Quarto version from the extensions (${1}); using release." >&2
  finish release "${2:-The version could not be established (${1}), so release is used.}"
}

latest_version() {
  curl --silent --show-error --fail --location \
    --connect-timeout 10 --max-time 30 --retry 3 --retry-delay 2 \
    "${DOWNLOAD_URL}/${1}.json" | jq -er '.version'
}

# Only the manifests directly under _extensions belong to the site. Those
# nested deeper are bundled inside an extension and carry their own constraints,
# which Quarto does not check against the site.
if [ -d "${SITE_PATH}/_extensions" ]; then
  while IFS= read -r manifest; do
    range=$(sed -n -E 's/^quarto-required:[[:space:]]*(.*)$/\1/p' "${manifest}" | head -n 1)
    range=$(printf '%s' "${range}" | sed -E "s/[[:space:]]+#.*$//; s/^[\"']//; s/[\"'][[:space:]]*$//")
    RANGES+=("${range}")
    label=${manifest#"${SITE_PATH}"/_extensions/}
    LABELS+=("${label%/*}")
    if [ -n "${range}" ]; then
      CONSTRAINED=$((CONSTRAINED + 1))
    fi
  done < <(find "${SITE_PATH}/_extensions" -mindepth 2 -maxdepth 3 -type f \
    \( -name _extension.yml -o -name _extension.yaml \) | sort)
fi

if [ "${CONSTRAINED}" -eq 0 ]; then
  echo "::notice::Quarto release: no extension under ${SITE_PATH}/_extensions sets quarto-required." >&2
  finish release "No extension under \`${SITE_PATH}/_extensions\` sets \`quarto-required\`, so release is used."
fi

STABLE=${QUARTO_STABLE_VERSION:-}
PRERELEASE_NOTE="not looked up, because the release lookup failed"
if [ -z "${STABLE}" ]; then
  STABLE=$(latest_version _download) || fallback "the stable version lookup failed"
fi
PRERELEASE_NOTE="not looked up, because the release satisfies every range"

# Succeeds when the version meets the range, and an empty range always does.
check_range() {
  [ -z "${2}" ] || npx --yes semver@7.8.6 -r "${2}" "${1}" >/dev/null 2>&1
}

# Prints what the first range marked no in the given cells requires, or nothing.
first_failure() {
  local index=0 cell
  for cell in "$@"; do
    if [ "${cell}" = "no" ]; then
      echo "\`${LABELS[index]}\` requires \`${RANGES[index]}\`"
      return 0
    fi
    index=$((index + 1))
  done
}

for index in "${!RANGES[@]}"; do
  if check_range "${STABLE}" "${RANGES[index]}"; then
    RELEASE_CELLS[index]=yes
  else
    RELEASE_CELLS[index]=no
  fi
done
STABLE_FAILED=$(first_failure "${RELEASE_CELLS[@]}")

if [ -z "${STABLE_FAILED}" ]; then
  echo "::notice::Quarto release (${STABLE}) satisfies every extension." >&2
  finish release "The latest release (${STABLE}) satisfies every \`quarto-required\` range, so release is used."
fi

PRERELEASE=${QUARTO_PRERELEASE_VERSION:-}
PRERELEASE_NOTE=""
if [ -z "${PRERELEASE}" ]; then
  PRERELEASE=$(latest_version _prerelease) || fallback "the pre-release version lookup failed"
fi

for index in "${!RANGES[@]}"; do
  if check_range "${PRERELEASE}" "${RANGES[index]}"; then
    PRERELEASE_CELLS[index]=yes
  else
    PRERELEASE_CELLS[index]=no
  fi
done
PRERELEASE_FAILED=$(first_failure "${PRERELEASE_CELLS[@]}")

if [ -z "${PRERELEASE_FAILED}" ]; then
  echo "::notice::Quarto pre-release (${PRERELEASE}) chosen: ${STABLE_FAILED}, which release (${STABLE}) does not satisfy." >&2
  finish pre-release "The latest release (${STABLE}) does not satisfy every range (${STABLE_FAILED}), but the latest pre-release (${PRERELEASE}) does, so pre-release is used."
fi

BOTH_FAIL=""
for index in "${!RANGES[@]}"; do
  if [ "${RELEASE_CELLS[index]}" = "no" ] && [ "${PRERELEASE_CELLS[index]}" = "no" ]; then
    BOTH_FAIL="${BOTH_FAIL:+${BOTH_FAIL}, }\`${LABELS[index]}\` (\`${RANGES[index]}\`)"
  fi
done

if [ -n "${BOTH_FAIL}" ]; then
  fallback "no version satisfies ${BOTH_FAIL}" \
    "Neither release (${STABLE}) nor pre-release (${PRERELEASE}) satisfies ${BOTH_FAIL}, so release is used. A range that cannot be read, or a semver check that cannot run, gives the same result."
fi
fallback "no single version satisfies every range" \
  "No single Quarto version satisfies every range: release (${STABLE}) fails ${STABLE_FAILED}, and pre-release (${PRERELEASE}) fails ${PRERELEASE_FAILED}, so release is used."
