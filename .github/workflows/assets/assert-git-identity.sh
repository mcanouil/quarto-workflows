#!/usr/bin/env bash

# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# Asserts the git identity setup-git-user wrote, for one of the credential paths
# it resolves. TOKEN carries the token the action returned.

set -euo pipefail

MODE="${1:?usage: assert-git-identity.sh <fallback|app>}"
TOKEN="${TOKEN:-}"

FALLBACK_NAME="github-actions[bot]"
FALLBACK_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"

# An unset key exits non-zero, which would abort before reporting which
# assertion failed.
NAME=$(git config --global user.name || true)
EMAIL=$(git config --global user.email || true)

FAILED=false
fail() {
  echo "::error::${1}"
  FAILED=true
}

if [ -z "${TOKEN}" ]; then
  fail "The action resolved no token."
fi

case "${MODE}" in
  fallback)
    [ "${NAME}" = "${FALLBACK_NAME}" ] || fail "user.name: expected '${FALLBACK_NAME}', got '${NAME}'"
    [ "${EMAIL}" = "${FALLBACK_EMAIL}" ] || fail "user.email: expected '${FALLBACK_EMAIL}', got '${EMAIL}'"
    ;;
  app)
    # The App slug is whatever App the repository configured, so the shape of the
    # identity is asserted rather than a particular name.
    if [ "${NAME}" = "${FALLBACK_NAME}" ] || [ "${NAME}" = "${NAME%\[bot\]}" ]; then
      fail "user.name: expected an App bot, got '${NAME}'"
    fi
    echo "${EMAIL}" | grep -qE '^[0-9]+\+.+\[bot\]@users\.noreply\.github\.com$' ||
      fail "user.email: expected a numeric App noreply address, got '${EMAIL}'"
    ;;
  *)
    echo "::error::Unknown mode '${MODE}' (expected fallback or app)"
    exit 1
    ;;
esac

if [ "${FAILED}" = "true" ]; then
  exit 1
fi
echo "The ${MODE} identity is ${NAME} <${EMAIL}>."
