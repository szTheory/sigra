#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'Sigra pin resolution: %s\n' "$*" >&2
  exit 1
}

# Dependency resolution is intentionally available only on GitHub pull requests.
if [[ "${GITHUB_ACTIONS:-}" != "true" || "${GITHUB_EVENT_NAME:-}" != "pull_request" ]]; then
  die "refusing to resolve dependencies outside a GitHub pull_request event"
fi

command -v mix >/dev/null 2>&1 || die "Mix is required"
command -v mktemp >/dev/null 2>&1 || die "mktemp is required"

temp_root="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
probe_dir="$(mktemp -d "${temp_root%/}/sigra-pin-resolution.XXXXXXXX")"
trap 'rm -rf "$probe_dir"' EXIT

project_dir="$probe_dir/project"
hex_home="$probe_dir/hex-home"
log_path="$probe_dir/deps-get.log"
mkdir -p "$project_dir" "$hex_home"

# Registry availability checked 2026-11-17: 1.7.1 is the newest non-retired
# release, 1.7.2 is unpublished, and the unrelated 1.20.0 release is retired.
printf '%s\n' \
  'defmodule SigraPinResolutionProbe.MixProject do' \
  '  use Mix.Project' \
  '  def project, do: [app: :sigra_pin_resolution_probe, version: "0.0.0", deps: deps()]' \
  '  defp deps, do: [{:sigra, "~> 1.7.1"}]' \
  'end' > "$project_dir/mix.exs"

(
  cd "$project_dir"
  export HEX_HOME="$hex_home"
  mix deps.get
) >"$log_path" 2>&1 || {
  sed -n '1,40p' "$log_path" >&2
  die "scratch project dependency resolution failed"
}

lockfile="$project_dir/mix.lock"
[[ -s "$lockfile" ]] || die "resolver produced no scratch lockfile"
selected="$(sed -nE 's/^[[:space:]]*"sigra": \{:hex, :sigra, "([0-9]+\.[0-9]+\.[0-9]+)".*/\1/p' "$lockfile")"
[[ -n "$selected" ]] || die "scratch lockfile has no selected Sigra release"
[[ "$selected" =~ ^1\.7\.[0-9]+$ ]] || die "resolver selected unexpected Sigra release: $selected"
if grep -Eiq 'sigra.*retir(ed|ement)|retir(ed|ement).*sigra' "$log_path"; then
  die "resolver marked selected Sigra release $selected as retired"
fi

printf 'Resolved Sigra %s from ~> 1.7.1 in isolated pull-request scratch project.\n' "$selected"
