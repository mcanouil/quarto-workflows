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
  actual=$("${SCRIPT}" "$@" 2>/dev/null) || actual="exit status $?"
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

SCRATCH=$(mktemp -d)
trap 'rm -rf "${SCRATCH}"' EXIT

check_summary() {
  local label=$1 pattern=$2 file=$3
  if [ -f "${file}" ] && grep -Eq -- "${pattern}" "${file}"; then
    echo "PASS ${label}"
  else
    echo "FAIL ${label}: no match for ${pattern} in:"
    { sed 's/^/  | /' "${file}" 2>/dev/null || echo '  (no summary file)'; }
    FAILURES=$((FAILURES + 1))
  fi
}

check "root project resolves from ." pre-release auto "${HERE}/root-project"
(cd "${HERE}/root-project" && RESOLVE_SUMMARY_FILE="${SCRATCH}/root.md" "${SCRIPT}" auto . >/dev/null 2>&1)
check_summary "root project summary names the extension" '^\| demo \| .>=1\.12\.1. ' "${SCRATCH}/root.md"
if grep -q 'x/y' "${SCRATCH}/root.md"; then
  echo "FAIL root project summary lists the docs extension"
  FAILURES=$((FAILURES + 1))
else
  echo "PASS root project summary leaves out the docs extension"
fi

RESOLVE_SUMMARY_FILE="${SCRATCH}/needs.md" "${SCRIPT}" auto "${HERE}/needs-prerelease/docs" >/dev/null 2>&1
check_summary "summary heading" '^### Quarto version$' "${SCRATCH}/needs.md"
check_summary "summary table header" '^\| Extension \| quarto-required \| Release 1\.11\.9 \| Pre-release 1\.12\.3 \|$' "${SCRATCH}/needs.md"
check_summary "summary row: no for release, yes for pre-release" '^\| acme/atelier \| .>=1\.12\.1. \| no \| yes \|$' "${SCRATCH}/needs.md"
check_summary "summary reasoning names pre-release" 'pre-release' "${SCRATCH}/needs.md"

RESOLVE_SUMMARY_FILE="${SCRATCH}/loose.md" "${SCRIPT}" auto "${HERE}/loose-range/docs" >/dev/null 2>&1
check_summary "release summary row" '^\| acme/loose \| .>=1\.3\.0. \| yes \| not checked \|$' "${SCRATCH}/loose.md"
check_summary "release summary says the pre-release was not looked up" 'Latest pre-release: not looked up, because the release satisfies every range\.' "${SCRATCH}/loose.md"
check_summary "release summary header has no unknown version" '^\| Extension \| quarto-required \| Release 1\.11\.9 \| Pre-release \|$' "${SCRATCH}/loose.md"

RESOLVE_SUMMARY_FILE="${SCRATCH}/explicit.md" "${SCRIPT}" release "${HERE}/needs-prerelease/docs" >/dev/null 2>&1
check_summary "explicit value summary" 'passed through' "${SCRATCH}/explicit.md"
check_summary "explicit value summary heading" '^### Quarto version$' "${SCRATCH}/explicit.md"

RESOLVE_SUMMARY_FILE="${SCRATCH}/pipe.md" "${SCRIPT}" auto "${HERE}/pipe-range/docs" >/dev/null 2>&1
check_summary "range with a pipe is escaped" '^\| acme/either \| .>=1\.12\.1 \\\|\\\| \^1\.11\.0. \|' "${SCRATCH}/pipe.md"
ROWS=$(grep -c "^| acme/" "${SCRATCH}/pipe.md" || true)
ROWS=${ROWS:-0}
if [ "${ROWS}" -eq 1 ]; then
  echo "PASS range with a pipe keeps one row"
else
  echo "FAIL range with a pipe gives ${ROWS} rows"
  FAILURES=$((FAILURES + 1))
fi

RESOLVE_SUMMARY_FILE="${SCRATCH}/empty.md" "${SCRIPT}" auto "${HERE}/no-extension/docs" >/dev/null 2>&1
check_summary "empty folder summary says no extension sets quarto-required" 'No extension under .*sets .quarto-required., so release is used\.' "${SCRATCH}/empty.md"
if grep -Eq 'could not be found|Latest' "${SCRATCH}/empty.md"; then
  echo "FAIL empty folder summary claims a lookup"
  FAILURES=$((FAILURES + 1))
else
  echo "PASS empty folder summary claims no lookup"
fi

check "manifest without quarto-required adds no constraint" release auto "${HERE}/no-range-manifest/docs"
RESOLVE_SUMMARY_FILE="${SCRATCH}/plain.md" "${SCRIPT}" auto "${HERE}/no-range-manifest/docs" >/dev/null 2>&1
check_summary "manifest without quarto-required is listed" '^\| acme/plain \| none \| yes \| not checked \|$' "${SCRATCH}/plain.md"

check "manifest named _extension.yaml is read" pre-release auto "${HERE}/yaml-manifest/docs"

check "conflicting ranges fall back to release" release auto "${HERE}/conflicting/docs"
RESOLVE_SUMMARY_FILE="${SCRATCH}/conflict.md" "${SCRIPT}" auto "${HERE}/conflicting/docs" >/dev/null 2>&1
check_summary "conflicting ranges: no single version" 'No single Quarto version satisfies every range' "${SCRATCH}/conflict.md"
check_summary "conflicting ranges: row of the first extension" '^\| a/x \| .>=1\.12\.1. \| no \| yes \|$' "${SCRATCH}/conflict.md"
check_summary "conflicting ranges: row of the second extension" '^\| a/y \| .<1\.12\.0. \| yes \| no \|$' "${SCRATCH}/conflict.md"
if grep -Eq 'Neither release' "${SCRATCH}/conflict.md"; then
  echo "FAIL conflicting ranges blame an extension that release satisfies"
  FAILURES=$((FAILURES + 1))
else
  echo "PASS conflicting ranges blame no single extension"
fi

unset RESOLVE_SUMMARY_FILE
check "no summary file still prints the version" pre-release auto "${HERE}/needs-prerelease/docs"

OFFLINE=$(
  unset QUARTO_STABLE_VERSION QUARTO_PRERELEASE_VERSION
  export QUARTO_DOWNLOAD_URL=http://127.0.0.1:9
  RESOLVE_SUMMARY_FILE="${SCRATCH}/offline.md" "${SCRIPT}" auto "${HERE}/needs-prerelease/docs" 2>/dev/null
)
if [ "${OFFLINE}" = "release" ]; then
  echo "PASS fetch failure falls back to release"
else
  echo "FAIL fetch failure falls back to release: got ${OFFLINE}"
  FAILURES=$((FAILURES + 1))
fi
check_summary "fetch failure summary" 'Latest release: could not be found\.' "${SCRATCH}/offline.md"
check_summary "fetch failure still shows the table" '^\| acme/atelier \| .>=1\.12\.1. \| not checked \| not checked \|$' "${SCRATCH}/offline.md"
check_summary "fetch failure summary heading" '^### Quarto version$' "${SCRATCH}/offline.md"

if [ "${FAILURES}" -ne 0 ]; then
  echo "${FAILURES} check(s) failed."
  exit 1
fi
echo "All checks passed."
