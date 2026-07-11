#!/usr/bin/env bash
# scripts/ci/lib/resolve-sigra-source.sh
#
# Sourceable resolver for the upgrade-smoke lane's published-source version.
# Selects the latest published Hex release within a configured series while
# durably excluding known immutable Hex strays — releases that were published
# in error and can neither be unpublished (past Hex's 1-hour window) nor
# retired programmatically (Hex 2.5 blocks `mix hex.retire`; manual retire is
# deferred as PUB-04). Without the exclusion, a stray with a numerically
# higher version (e.g. `1.20.0`) out-sorts the real GA under `sort -V`.
#
# Exposes: validate_source_series, series_regex, resolve_latest_sigra_source,
# validate_override_version. Callers must set SOURCE_SERIES before invoking
# any of these functions (upgrade-smoke.sh does this before sourcing).

validate_source_series() {
  if [[ ! "${SOURCE_SERIES}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "FAIL: SIGRA_UPGRADE_SOURCE_SERIES must be a major or major.minor series; got '${SOURCE_SERIES}'" >&2
    exit 1
  fi
}

series_regex() {
  if [[ "${SOURCE_SERIES}" == *.* ]]; then
    printf '^%s\\.[0-9]+$' "${SOURCE_SERIES//./\\.}"
  else
    printf '^%s\\.[0-9]+\\.[0-9]+$' "${SOURCE_SERIES}"
  fi
}

resolve_latest_sigra_source() {
  local info versions selected exclude
  local -a exclude_arr

  validate_source_series
  info="$(mix hex.info sigra)"

  # Known immutable Hex strays: releases published in error that cannot be
  # unpublished or retired. They out-sort real GA releases by `sort -V`, so
  # drop them by exact version before selecting the latest. This is a durable
  # fact, not a per-release floor — new real releases (1.4.0, 1.5.0, …)
  # require no code edit. Comma-separated; configurable without a code change
  # if another stray is ever published.
  exclude="${SIGRA_UPGRADE_SMOKE_EXCLUDE_VERSIONS:-1.20.0}"
  IFS=',' read -ra exclude_arr <<<"${exclude}"

  versions="$(printf '%s\n' "${info}" \
    | sed -n 's/^  \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' \
    | grep -E "$(series_regex)" \
    | grep -vxF -f <(printf '%s\n' "${exclude_arr[@]}") \
    || true)"

  if [[ -z "${versions}" ]]; then
    echo "FAIL: no published sigra release found on Hex for series ${SOURCE_SERIES} (after excluding: ${exclude})" >&2
    exit 1
  fi

  selected="$(printf '%s\n' "${versions}" | sort -V | tail -n1)"
  printf '%s' "${selected}"
}

validate_override_version() {
  local override="${1}"
  local info

  validate_source_series
  if ! printf '%s\n' "${override}" | grep -Eq "$(series_regex)"; then
    echo "FAIL: SIGRA_UPGRADE_SMOKE_START_VERSION must match configured series ${SOURCE_SERIES}; got '${override}'" >&2
    exit 1
  fi

  info="$(mix hex.info sigra)"
  if ! printf '%s\n' "${info}" | grep -Eq "^  ${override}( |\()"; then
    echo "FAIL: override '${override}' is not a published sigra release on Hex" >&2
    exit 1
  fi
}
