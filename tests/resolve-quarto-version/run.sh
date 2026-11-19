#!/usr/bin/env bash

# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# Runs the resolver against each fixture with fixed latest versions and checks
# the version it prints.

set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT="${HERE}/../../.github/actions/resolve-quarto-version/resolve-quarto-version.sh"

export QUARTO_STABLE_VERSION=1.11.9
export QUARTO_PRERELEASE_VERSION=1.12.3

FAILURES=0

check() {
  local label=$1 expected=$2 actual
  shift 2
  actual=$("${SCRIPT}" "$@" 2>/dev/null)
  if [ "${actual}" = "${expected}" ]; then
    echo "PASS ${label}: ${actual}"
  else
    echo "FAIL ${label}: expected ${expected}, got ${actual}"
    FAILURES=$((FAILURES + 1))
  fi
}

check "no extension" release auto "${HERE}/no-extension/docs"
check "missing _extensions folder" release auto "${HERE}/does-not-exist"
check "range the stable version meets" release auto "${HERE}/loose-range/docs"
check "range only the pre-release meets" pre-release auto "${HERE}/needs-prerelease/docs"
check "extension without an owner folder" pre-release auto "${HERE}/flat-layout/docs"
check "one extension needs the pre-release" pre-release auto "${HERE}/mixed/docs"
check "range written without quotes" pre-release auto "${HERE}/unquoted-range/docs"
check "range nothing meets" release auto "${HERE}/unsatisfiable/docs"
check "range that does not parse" release auto "${HERE}/invalid-range/docs"
check "bundled extension is ignored" release auto "${HERE}/nested-ignored/docs"
check "trailing slash on the path" pre-release auto "${HERE}/needs-prerelease/docs/"
check "release passes through" release release "${HERE}/needs-prerelease/docs"
check "pre-release passes through" pre-release pre-release "${HERE}/loose-range/docs"
check "version number passes through" 1.9.37 1.9.37 "${HERE}/needs-prerelease/docs"

if [ "${FAILURES}" -ne 0 ]; then
  echo "${FAILURES} check(s) failed."
  exit 1
fi
echo "All checks passed."
