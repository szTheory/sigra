#!/usr/bin/env bash
set -euo pipefail

PACKAGE="sigra"
VERSION="1.20.0"
REASON="invalid"
RETIRE_MESSAGE="Retired: use the supported ~> 1.5.0 requirement instead."
SCHEMA="sigra.phase-242-hex-remediation/1"
PACKAGE_URL="${HEX_REMEDIATION_PACKAGE_URL:-https://hex.pm/api/packages/${PACKAGE}}"
HEXDOCS_URL="${HEX_REMEDIATION_HEXDOCS_URL:-https://hexdocs.pm/${PACKAGE}/}"

die() {
  echo "hex remediation verification: $*" >&2
  exit 1
}

require_output_path() {
  case "$1" in
    ""|/*|*'..'*) die "output path must be a relative, non-parent path" ;;
  esac
}

atomic_write() {
  local output="$1"
  local source="$2"
  require_output_path "$output"
  mkdir -p "$(dirname "$output")"
  mv "$source" "$output"
}

capture_snapshot() {
  local slot="$1"
  local output="$2"
  local tmp_dir body projected
  case "$slot" in before|after_retire|after_docs_revert) ;; *) die "unknown snapshot slot: $slot" ;; esac
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN
  body="$tmp_dir/package.json"
  projected="$tmp_dir/projected.json"
  curl -fsS "$PACKAGE_URL" -o "$body" || die "public package read failed for $slot"
  [ -s "$body" ] || die "public package response is empty for $slot"
  LC_ALL=C jq -e --arg package "$PACKAGE" --arg version "$VERSION" --arg slot "$slot" '
    def release: ([.releases[]? | select(.version == $version)] | first) // empty;
    if .name != $package then error("package name mismatch") else . end |
    release as $release |
    if ($release | type) != "object" then error("target release is absent") else . end |
    if ([.latest_version, .latest_stable_version, .retirements] | any(. == null)) then
      error("required package projection field missing")
    else . end |
    {
      captured_at: (now | todateiso8601),
      slot: $slot,
      package: {
        name: .name,
        latest_version: .latest_version,
        latest_stable_version: .latest_stable_version,
        retirements: .retirements,
        release: {version: $release.version, has_docs: ($release.has_docs // false)}
      }
    }
  ' "$body" > "$projected" || die "public package response is not valid UTF-8 JSON with required target fields for $slot"
  atomic_write "$output" "$projected"
  trap - RETURN
  rm -rf "$tmp_dir"
}

classify_root() {
  local output="$1"
  local tmp_dir body classification projected
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN
  body="$tmp_dir/root.html"
  projected="$tmp_dir/root.json"
  curl -fsSL "$HEXDOCS_URL" -o "$body" || die "HexDocs root read failed"
  [ -s "$body" ] || die "HexDocs root response is empty"
  if LC_ALL=C grep -aq '/sigra/1\.5\.' "$body"; then
    classification="current_1_5"
  elif LC_ALL=C grep -aq '/sigra/1\.20\.0' "$body"; then
    classification="still_phantom_1_20"
  else
    classification="unavailable_or_ambiguous"
  fi
  jq -n --arg captured_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" --arg url "$HEXDOCS_URL" --arg classification "$classification" \
    '{captured_at: $captured_at, url: $url, classification: $classification}' > "$projected"
  atomic_write "$output" "$projected"
  trap - RETURN
  rm -rf "$tmp_dir"
  [ "$classification" = "current_1_5" ] || die "HexDocs root is $classification, not current_1_5"
}

resolver_receipt() {
  local case_name="$1"
  local output="$2"
  local requirement expected_warning tmp_dir project hex_home mix_home log lock selected warning projected
  case "$case_name" in
    broad) requirement="~> 1.0"; expected_warning=true ;;
    safe) requirement="~> 1.5.0"; expected_warning=false ;;
    *) die "unknown resolver case: $case_name" ;;
  esac
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN
  project="$tmp_dir/project"
  hex_home="$tmp_dir/hex-home"
  mix_home="$tmp_dir/mix-home"
  mkdir -p "$project" "$hex_home" "$mix_home"
  printf '%s\n' \
    'defmodule HexRemediationProbe.MixProject do' \
    '  use Mix.Project' \
    '  def project, do: [app: :hex_remediation_probe, version: "0.0.0", deps: deps()]' \
    "  defp deps, do: [{:sigra, \"$requirement\"}]" \
    'end' > "$project/mix.exs"
  log="$tmp_dir/mix.log"
  unset HEX_IGNORE_RETIREMENTS
  if (
    cd "$project"
    export HEX_HOME="$hex_home" MIX_HOME="$mix_home"
    mix deps.get
  ) >"$log" 2>&1; then
    :
  else
    sed -n '1,20p' "$log" >&2
    die "resolver failed for $case_name"
  fi
  lock="$project/mix.lock"
  [ -s "$lock" ] || die "resolver produced no lockfile for $case_name"
  selected="$(sed -nE 's/.*"sigra": \{:\"hex\", :sigra, "([0-9]+\.[0-9]+\.[0-9]+)".*/\1/p' "$lock" | head -n 1)"
  [ -n "$selected" ] || die "resolver lockfile has no selected sigra version for $case_name"
  if grep -qi 'retir' "$log"; then warning=true; else warning=false; fi
  if [ "$case_name" = broad ]; then
    [ "$selected" = "$VERSION" ] || die "broad resolver selected $selected instead of $VERSION"
    [ "$warning" = true ] || die "broad resolver did not emit a retirement warning"
  else
    [[ "$selected" =~ ^1\.5\.[0-9]+$ ]] || die "safe resolver selected $selected outside 1.5.x"
    [ "$warning" = "$expected_warning" ] || die "safe resolver unexpectedly emitted a retirement warning"
  fi
  projected="$tmp_dir/resolver.json"
  jq -n --arg requirement "$requirement" --arg selected "$selected" --argjson warning "$warning" \
    '{requirement: $requirement, selected_version: $selected, retirement_warning: $warning, fresh_home: true, exit_verdict: "passed"}' > "$projected"
  atomic_write "$output" "$projected"
  trap - RETURN
  rm -rf "$tmp_dir"
}

validate_receipt() {
  local source="$1"
  local output="$2"
  local tmp_dir receipt
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN
  receipt="$tmp_dir/receipt.json"
  if [ -d "$source" ]; then
    for slot in before after_retire after_docs_revert hexdocs_root resolver_broad resolver_safe; do
      [ -s "$source/$slot.json" ] || die "missing required evidence slot: $slot"
    done
    jq -n \
      --arg schema "$SCHEMA" \
      --arg workflow_run_url "${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-sztheory/sigra}/actions/runs/${GITHUB_RUN_ID:-local}" \
      --arg workflow_sha "${GITHUB_SHA:-local-test-sha}" \
      --slurpfile before "$source/before.json" \
      --slurpfile after_retire "$source/after_retire.json" \
      --slurpfile after_docs_revert "$source/after_docs_revert.json" \
      --slurpfile hexdocs_root "$source/hexdocs_root.json" \
      --slurpfile resolver_broad "$source/resolver_broad.json" \
      --slurpfile resolver_safe "$source/resolver_safe.json" \
      '{schema: $schema, workflow_run_url: $workflow_run_url, workflow_sha: $workflow_sha,
        before: $before[0], after_retire: $after_retire[0], after_docs_revert: $after_docs_revert[0],
        hexdocs_root: $hexdocs_root[0], resolver_broad: $resolver_broad[0], resolver_safe: $resolver_safe[0]}' > "$receipt"
  else
    cp "$source" "$receipt"
  fi
  LC_ALL=C jq -e --arg schema "$SCHEMA" '
    def nonempty: . != null and . != "" and . != [] and . != {};
    def required($key): if .[$key] | nonempty then . else error("missing required evidence slot: " + $key) end;
    if .schema != $schema then error("unexpected evidence schema") else . end |
    required("workflow_run_url") | required("workflow_sha") |
    required("before") | required("after_retire") | required("after_docs_revert") |
    required("hexdocs_root") | required("resolver_broad") | required("resolver_safe") |
    if .hexdocs_root.classification != "current_1_5" then error("root docs are not current_1_5") else . end |
    if (.resolver_broad.selected_version != "1.20.0" or .resolver_broad.retirement_warning != true or .resolver_broad.fresh_home != true) then error("invalid broad resolver receipt") else . end |
    if ((.resolver_safe.selected_version | test("^1\\.5\\.[0-9]+$")) | not) or .resolver_safe.retirement_warning != false or .resolver_safe.fresh_home != true then error("invalid safe resolver receipt") else . end |
    if [paths(scalars) as $p | ($p[-1] | tostring | test("(secret|token|authorization|credential|api.?key|request)"; "i")) or (getpath($p) | tostring | test("(bearer |hex_[a-z0-9]|api[_-]?key=)"; "i"))] | any then error("credential-shaped evidence is forbidden") else . end
  ' "$receipt" > "$tmp_dir/validated.json" || die "evidence receipt failed validation"
  atomic_write "$output" "$tmp_dir/validated.json"
  trap - RETURN
  rm -rf "$tmp_dir"
}

usage() {
  echo "usage: $0 {capture <slot> <output>|classify-root <output>|resolver <broad|safe> <output>|validate <source> <output>}" >&2
}

case "${1:-}" in
  capture) [ "$#" = 3 ] || { usage; exit 2; }; capture_snapshot "$2" "$3" ;;
  classify-root) [ "$#" = 2 ] || { usage; exit 2; }; classify_root "$2" ;;
  resolver) [ "$#" = 3 ] || { usage; exit 2; }; resolver_receipt "$2" "$3" ;;
  validate) [ "$#" = 3 ] || { usage; exit 2; }; validate_receipt "$2" "$3" ;;
  *) usage; exit 2 ;;
esac
