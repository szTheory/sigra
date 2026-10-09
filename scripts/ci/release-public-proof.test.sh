#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ROOT}/scripts/ci/release-public-proof.sh"
TMP="$(mktemp -d)"
PASS=0
FAIL=0
trap 'rm -rf "$TMP"' EXIT
pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

new_fixture() {
  local name="$1"
  FIXTURE="${TMP}/${name}"
  mkdir -p "${FIXTURE}/bin" "${FIXTURE}/source" "${FIXTURE}/archive"
  FIXTURE_MAIN_SHA="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  FIXTURE_SOURCE_SHA="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  FIXTURE_CI_SHA="cccccccccccccccccccccccccccccccccccccccc"
  FIXTURE_BLOB_SHA="dddddddddddddddddddddddddddddddddddddddd"
  FIXTURE_CHECKSUM="eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
  PROOF_CASE="positive"
  export FIXTURE FIXTURE_MAIN_SHA FIXTURE_SOURCE_SHA FIXTURE_CI_SHA FIXTURE_BLOB_SHA FIXTURE_CHECKSUM PROOF_CASE

  jq -n \
    --arg source "$FIXTURE_SOURCE_SHA" \
    --arg ci "$FIXTURE_CI_SHA" \
    --arg blob "$FIXTURE_BLOB_SHA" \
    '{schema_version:1,release_run_id:"11111",release_run_attempt:3,
      release_run_url:"https://github.com/szTheory/sigra/actions/runs/11111",
      workflow_name:"Release Please",workflow_url:"https://github.com/szTheory/sigra/actions/workflows/release-please.yml",
      source_event:"push",version:"1.6.0",tag:"v1.6.0",source_sha:$source,
      release_started_at:"2026-10-09T04:00:00Z",release_completed_at:"2026-10-09T04:04:59Z",
      gate:{run_id:"22222",url:"https://github.com/szTheory/sigra/actions/runs/22222",
        ci_run_id:22222,ci_run_url:"https://github.com/szTheory/sigra/actions/runs/22222",
        verdict:"pass",head_sha:$source,attempts:96,
        started_at:"2026-10-09T03:40:00Z",completed_at:"2026-10-09T03:50:00Z"},
      publish:{outcome:"published",started_at:"2026-10-09T03:51:00Z",completed_at:"2026-10-09T03:52:00Z"},
      terminal_verdict:"success",failure:null,observer_run:null,stages:{}}' \
    > "${FIXTURE}/archive/release-result.json"
  (
    cd "${FIXTURE}/archive"
    zip -q "${FIXTURE}/release-result.zip" release-result.json
  )

  cat > "${FIXTURE}/bin/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
proof_case="${PROOF_CASE:-positive}"
wrong_sha="ffffffffffffffffffffffffffffffffffffffff"
ci_sha="$FIXTURE_SOURCE_SHA"
ci_path=".github/workflows/ci.yml"
ci_conclusion="success"
ci_attempt=2
  ci_detail_attempt=2
  ci_run_response_id=22222
job_name="ci-gate"
job_sha="$FIXTURE_SOURCE_SHA"
job_attempt=2
job_conclusion="success"
  release_head="$FIXTURE_SOURCE_SHA"
release_path=".github/workflows/release-please.yml"
release_conclusion="success"
release_attempt=3
  release_detail_attempt=3
case "$proof_case" in
    package-tag-wrong-source) release_head="$wrong_sha" ;;
  release-run-wrong-head) release_head="$wrong_sha" ;;
  release-run-wrong-workflow) release_path=".github/workflows/ci.yml" ;;
  release-run-failed) release_conclusion="failure" ;;
  bad-annotated-target) release_head="$wrong_sha" ;;
  release-attempt-mismatch) release_detail_attempt=2 ;;
  ci-wrong-workflow|source-ci-wrong-workflow) ci_path=".github/workflows/other.yml" ;;
  ci-wrong-head|source-ci-wrong-head) ci_sha="$wrong_sha"; job_sha="$wrong_sha" ;;
  ci-run-wrong-id) ci_run_response_id=99999 ;;
  ci-failed) ci_conclusion="failure" ;;
  ci-attempt-mismatch) ci_detail_attempt=1 ;;
  ci-gate-missing) job_name="unit-tests" ;;
  ci-gate-wrong-head) job_sha="$wrong_sha" ;;
  ci-gate-attempt-mismatch) job_attempt=1 ;;
  ci-gate-failed) job_conclusion="failure" ;;
esac
if [[ "${1:-}" == auth && "${2:-}" == status ]]; then
  [[ "${GH_AUTH_FAIL:-0}" == 0 ]] || exit 1
  exit 0
fi
[[ "${1:-}" == api && $# -ge 2 ]] || exit 2
endpoint="$2"
case "$endpoint" in
  rate_limit)
    printf '{"resources":{"core":{"remaining":5000,"reset":1791554107}}}\n'
    ;;
  repos/szTheory/sigra/commits/main)
    jq -n --arg sha "$FIXTURE_MAIN_SHA" '{sha:$sha,html_url:("https://github.com/szTheory/sigra/commit/"+$sha)}'
    ;;
  repos/szTheory/sigra/git/ref/tags/v1.6.0)
    tag_type="commit"
    tag_sha="$FIXTURE_SOURCE_SHA"
    if [[ "$proof_case" == annotated-tag || "$proof_case" == bad-annotated-target ]]; then
      tag_type="tag"
      tag_sha="9999999999999999999999999999999999999999"
    elif [[ "$proof_case" == package-tag-wrong-source ]]; then
      tag_sha="$wrong_sha"
    fi
    jq -n --arg type "$tag_type" --arg sha "$tag_sha" '{ref:"refs/tags/v1.6.0",object:{type:$type,sha:$sha}}'
    ;;
  repos/szTheory/sigra/git/tags/9999999999999999999999999999999999999999)
    tag_target="$FIXTURE_SOURCE_SHA"
    [[ "$proof_case" != bad-annotated-target ]] || tag_target="ffffffffffffffffffffffffffffffffffffffff"
    jq -n --arg sha "$tag_target" '{object:{type:"commit",sha:$sha}}'
    ;;
  repos/szTheory/sigra/actions/runs\?head_sha=*)
    jq -n --arg sha "$release_head" --arg path "$release_path" --arg conclusion "$release_conclusion" --argjson attempt "$release_attempt" \
      '{workflow_runs:[{id:11111,run_attempt:$attempt,head_sha:$sha,path:$path,event:"push",status:"completed",conclusion:$conclusion,html_url:"https://github.com/szTheory/sigra/actions/runs/11111",run_started_at:"2026-10-09T04:00:00Z"}]}'
    ;;
  repos/szTheory/sigra/actions/runs/11111/attempts/*)
    jq -n --arg sha "$release_head" --arg path "$release_path" --arg conclusion "$release_conclusion" --argjson attempt "$release_detail_attempt" \
      '{id:11111,run_attempt:$attempt,head_sha:$sha,path:$path,event:"push",status:"completed",conclusion:$conclusion,html_url:"https://github.com/szTheory/sigra/actions/runs/11111"}'
    ;;
  repos/szTheory/sigra/actions/runs/11111/artifacts)
    [[ "$proof_case" != artifact-unavailable ]] || exit 1
    [[ "$proof_case" != artifact-malformed-list ]] || { printf '{malformed json\n'; exit 0; }
    duplicate=false
    [[ "$proof_case" != duplicate-artifact ]] || duplicate=true
    jq -n --argjson duplicate "$duplicate" '
      {artifacts:([{id:33333,name:"release-result-1.6.0-11111",expired:false,archive_download_url:"https://api.github.com/repos/szTheory/sigra/actions/artifacts/33333/zip"}] +
        (if $duplicate then [{id:33334,name:"release-result-1.6.0-11111",expired:false,archive_download_url:"https://api.github.com/repos/szTheory/sigra/actions/artifacts/33334/zip"}] else [] end))}'
    ;;
  repos/szTheory/sigra/actions/artifacts/33333/zip)
    cat "$FIXTURE/release-result.zip"
    ;;
  repos/szTheory/sigra/actions/runs/*/attempts/*/jobs)
    [[ "${MISSING_SOURCE_CI:-0}" == 0 ]] || exit 1
    jq -n --arg name "$job_name" --arg sha "$job_sha" --arg conclusion "$job_conclusion" --argjson attempt "$job_attempt" \
      '{jobs:[{id:22223,name:$name,head_sha:$sha,run_attempt:$attempt,status:"completed",conclusion:$conclusion,html_url:"https://github.com/szTheory/sigra/actions/runs/22222/job/22223"}]}'
    ;;
  repos/szTheory/sigra/actions/runs/*/attempts/*)
    [[ "${MISSING_SOURCE_CI:-0}" == 0 ]] || exit 1
    jq -n --arg sha "$ci_sha" --arg path "$ci_path" --arg conclusion "$ci_conclusion" --argjson attempt "$ci_detail_attempt" \
      '{id:22222,run_attempt:$attempt,head_sha:$sha,path:$path,status:"completed",conclusion:$conclusion,html_url:"https://github.com/szTheory/sigra/actions/runs/22222"}'
    ;;
  repos/szTheory/sigra/actions/runs/*)
    [[ "${MISSING_SOURCE_CI:-0}" == 0 ]] || exit 1
    jq -n --arg sha "$ci_sha" --arg path "$ci_path" --arg conclusion "$ci_conclusion" --argjson attempt "$ci_attempt" --argjson id "$ci_run_response_id" \
      '{id:$id,run_attempt:$attempt,head_sha:$sha,path:$path,status:"completed",conclusion:$conclusion,html_url:("https://github.com/szTheory/sigra/actions/runs/"+($id|tostring))}'
    ;;
  repos/szTheory/sigra/contents/*\?ref=*)
    content_path="${endpoint#repos/szTheory/sigra/contents/}"
    content_path="${content_path%%\?ref=*}"
    content_sha="$FIXTURE_SOURCE_SHA"
    [[ "$proof_case" != source-content-wrong-commit ]] || content_sha="$wrong_sha"
    [[ "$proof_case" != source-content-wrong-path ]] || content_path="other.ex"
    jq -n --arg sha "$FIXTURE_BLOB_SHA" --arg source "$content_sha" --arg path "$content_path" \
      '{path:$path,sha:$sha,html_url:("https://github.com/szTheory/sigra/blob/"+$source+"/"+$path)}'
    ;;
  repos/szTheory/sigra/pulls\?state=open\&base=main\&per_page=100)
    jq -n --arg sha "$FIXTURE_MAIN_SHA" '[{number:302,state:"open",head:{ref:"release-please--branches--main",sha:"ffffffffffffffffffffffffffffffffffffffff"},base:{ref:"main",sha:$sha},html_url:"https://github.com/szTheory/sigra/pull/302"}]'
    ;;
  *) echo "unexpected gh endpoint" >&2; exit 2 ;;
esac
GH
  chmod +x "${FIXTURE}/bin/gh"

  cat > "${FIXTURE}/bin/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  "rev-parse HEAD") printf '%s\n' "$FIXTURE_MAIN_SHA" ;;
  "status --porcelain=v1 -uall") exit 0 ;;
  *) echo "unexpected git query" >&2; exit 2 ;;
esac
GIT
  chmod +x "${FIXTURE}/bin/git"

  cat > "${FIXTURE}/bin/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail
output=""
url=""
effective=""
proof_case="${PROOF_CASE:-positive}"
wrong_sha="ffffffffffffffffffffffffffffffffffffffff"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output) output="$2"; shift 2 ;;
    -w|--write-out) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
[[ -n "$output" && -n "$url" ]] || exit 2
effective="$url"
case "$url" in
  https://hex.pm/api/packages/sigra/releases/1.6.0)
    [[ "$proof_case" != hex-unavailable ]] || exit 22
    hex_version="1.6.0"
    [[ "$proof_case" != hex-wrong-version ]] || hex_version="1.5.9"
    jq -n --arg checksum "$FIXTURE_CHECKSUM" --arg version "$hex_version" '{version:$version,html_url:("https://hex.pm/packages/sigra/"+$version),checksum:$checksum}' > "$output"
    ;;
  https://hexdocs.pm/sigra/1.6.0/Sigra.html)
    [[ "$proof_case" != docs-unavailable ]] || exit 22
    source_href="https://github.com/sztheory/sigra/blob/v1.6.0/lib/sigra.ex#L1"
    if [[ "$proof_case" == source-href-wrong-tag ]]; then source_href="https://github.com/sztheory/sigra/blob/v1.5.9/lib/sigra.ex#L1"; fi
    if [[ "$proof_case" == source-href-wrong-path ]]; then source_href="https://github.com/sztheory/sigra/blob/v1.6.0/lib/other.ex#L1"; fi
    printf '<html><a href="%s">View Source</a></html>\n' "$source_href" > "$output"
    effective="https://sigra.hexdocs.pm/1.6.0/Sigra.html"
    [[ "$proof_case" != docs-wrong-version ]] || effective="https://sigra.hexdocs.pm/1.5.9/Sigra.html"
    ;;
  https://github.com/sztheory/sigra/blob/v1.6.0/lib/sigra.ex\#L1)
    : > "$output"
    case "$proof_case" in
      source-redirect-wrong-commit) effective="https://github.com/szTheory/sigra/blob/$wrong_sha/lib/sigra.ex#L1" ;;
      source-redirect-wrong-path) effective="https://github.com/szTheory/sigra/blob/$FIXTURE_SOURCE_SHA/lib/other.ex#L1" ;;
      source-redirect-wrong-tag) effective="https://github.com/szTheory/sigra/blob/v1.5.9/lib/sigra.ex#L1" ;;
      *) effective="$url" ;;
    esac
    ;;
  *) echo "unexpected URL" >&2; exit 2 ;;
esac
    printf '200\n%s\n' "$effective"
CURL
  chmod +x "${FIXTURE}/bin/curl"
  export ENV_FIXTURE_SOURCE_SHA="$FIXTURE_SOURCE_SHA"
}

run_helper() {
  local preflight="$1" receipt="$2"
  set +e
  (
    cd "$FIXTURE/source"
    PATH="${FIXTURE}/bin:${PATH}" \
      FIXTURE_MAIN_SHA="$FIXTURE_MAIN_SHA" \
      FIXTURE_SOURCE_SHA="$FIXTURE_SOURCE_SHA" \
      FIXTURE_CI_SHA="$FIXTURE_CI_SHA" \
      FIXTURE_BLOB_SHA="$FIXTURE_BLOB_SHA" \
      FIXTURE_CHECKSUM="$FIXTURE_CHECKSUM" \
      PROOF_CASE="$PROOF_CASE" \
      MISSING_SOURCE_CI="${MISSING_SOURCE_CI:-0}" \
      bash "$SCRIPT" --version 1.6.0 --preflight "$preflight" --output "$receipt"
  ) > "${FIXTURE}/run.log" 2>&1
  RC=$?
  set -e
}

rebuild_archive() {
  rm -f "$FIXTURE/release-result.zip"
  (cd "$FIXTURE/archive" && zip -q "$FIXTURE/release-result.zip" release-result.json)
}

mutate_artifact() {
  local updated="$FIXTURE/archive/release-result.updated.json"
  jq "$@" "$FIXTURE/archive/release-result.json" > "$updated"
  mv "$updated" "$FIXTURE/archive/release-result.json"
  rebuild_archive
}

add_archive_member() {
  local member="$1" contents="$2"
  printf '%s' "$contents" > "$FIXTURE/archive/${member##*/}"
  (cd "$FIXTURE/archive" && zip -q "$FIXTURE/release-result.zip" "$member")
  rm -f "$FIXTURE/archive/${member##*/}"
}

add_traversal_member() {
  printf '%s' 'untrusted path member' > "$FIXTURE/traversal.txt"
  (cd "$FIXTURE/archive" && zip -q "$FIXTURE/release-result.zip" ../traversal.txt)
  rm -f "$FIXTURE/traversal.txt"
}

replace_with_json_symlink() {
  local json_target
  json_target="$(jq -cn --arg source "$FIXTURE_SOURCE_SHA" \
    '{schema_version:1,release_run_id:"11111",release_run_attempt:3,
      release_run_url:"https://github.com/szTheory/sigra/actions/runs/11111",workflow_name:"Release Please",
      source_event:"push",version:"1.6.0",tag:"v1.6.0",source_sha:$source,
      gate:{verdict:"pass",run_id:"22222",ci_run_id:22222,head_sha:$source,
        ci_run_url:"https://github.com/szTheory/sigra/actions/runs/22222"},
      publish:{outcome:"published"},terminal_verdict:"success",failure:null}')"
  rm -f "$FIXTURE/archive/release-result.json" "$FIXTURE/release-result.zip"
  ln -s "$json_target" "$FIXTURE/archive/release-result.json"
  (cd "$FIXTURE/archive" && zip -q -y "$FIXTURE/release-result.zip" release-result.json)
}

assert_blocked_case() {
  local name="$1" expected="$2"
  shift 2
  new_fixture "$name"
  PROOF_CASE="$name"
  MISSING_SOURCE_CI=0
  export PROOF_CASE MISSING_SOURCE_CI
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --missing-source-ci)
        MISSING_SOURCE_CI=1
        export MISSING_SOURCE_CI
        shift
        ;;
      --artifact-filter)
        local filter
        shift
        filter="$1"
        shift
        mutate_artifact "$@" "$filter"
        set --
        ;;
      --archive)
        local archive_mode
        shift
        archive_mode="$1"
        shift
        case "$archive_mode" in
          malformed-json)
            printf '{not json\n' > "$FIXTURE/archive/release-result.json"
            rebuild_archive
            ;;
          extra-member) add_archive_member notes.txt 'extra archive member' ;;
          traversal-member) add_traversal_member ;;
          json-symlink) replace_with_json_symlink ;;
          *) fail "unknown archive fixture mode: $archive_mode"; return 1 ;;
        esac
        ;;
      *) fail "unknown fixture option: $1"; return 1 ;;
    esac
  done
  local preflight="$FIXTURE/preflight.json" receipt="$FIXTURE/receipt.json"
  run_helper "$preflight" "$receipt"
  if [[ "$RC" -ne 0 ]] && [[ ! -e "$receipt" ]] && \
    grep -Fq "release-public-proof: BLOCKED: ${expected}" "$FIXTURE/run.log" && \
    jq -e --arg id "$expected" '.verdict=="blocked" and (.blockers|index($id)!=null) and any(.checks[]; .id==$id and .status=="blocked")' "$preflight" >/dev/null 2>&1; then
    pass "$name is blocked at $expected without a success receipt"
  else
    fail "$name did not block at $expected: rc=$RC $(cat "$FIXTURE/run.log")"
  fi
}

assert_diagnostic_is_inert() {
  new_fixture artifact-diagnostic
  PROOF_CASE=positive
  export PROOF_CASE
  local payload="artifact diagnostic \$(touch ${FIXTURE}/command-executed) \`touch ${FIXTURE}/command-executed\`"
  mutate_artifact --arg diagnostic "$payload" '.terminal_verdict="failure" | .failure={stage:"publish-hex",diagnostic:$diagnostic}'
  local preflight="$FIXTURE/preflight.json" receipt="$FIXTURE/receipt.json"
  run_helper "$preflight" "$receipt"
  if [[ "$RC" -ne 0 && ! -e "$receipt" && ! -e "$FIXTURE/command-executed" ]] && \
    grep -Fq 'release-public-proof: BLOCKED: release_artifact_identity' "$FIXTURE/run.log" && \
    ! grep -Fq "$payload" "$FIXTURE/run.log" "$preflight"; then
    pass "arbitrary artifact diagnostics remain inert and out of failure evidence"
  else
    fail "artifact diagnostics executed, leaked, or produced a receipt: rc=$RC $(cat "$FIXTURE/run.log")"
  fi
}

assert_shell_payload_is_not_projected() {
  new_fixture shell-payload
  PROOF_CASE=positive
  export PROOF_CASE
  local marker="$FIXTURE/command-executed"
  local payload="\$(touch ${marker}) \`touch ${marker}\` ; | \${HOME}"
  mutate_artifact --arg payload "$payload" '.diagnostic=$payload | .metadata={runner_message:$payload}'
  local preflight="$FIXTURE/preflight.json" receipt="$FIXTURE/receipt.json"
  run_helper "$preflight" "$receipt"
  if [[ "$RC" -eq 0 && ! -e "$marker" ]] && \
    jq -e --arg payload "$payload" '
      (keys|sort|join(",")) == "hex,observed_at,package,package_source_ci,package_source_sha,release_artifact,release_run,schema,source_reference,tag,verdict,version,versioned_docs_url" and
      ([..|strings|select(.==$payload)]|length)==0 and
      (has("final_main_sha")|not) and (has("final_main_ci")|not) and (has("release_receipt_commit")|not)
    ' "$receipt" >/dev/null; then
    pass "shell-like artifact values stay inert and success uses only the explicit receipt allowlist"
  else
    fail "shell-like artifact value executed or escaped receipt allowlisting: rc=$RC $(cat "$FIXTURE/run.log")"
  fi
}

assert_credentials_are_rejected_without_leaking() {
  new_fixture artifact-credentials
  PROOF_CASE=positive
  export PROOF_CASE
  local canary="secret-canary-DO-NOT-PRINT"
  mutate_artifact --arg canary "$canary" '.credentials={api_key:$canary, nested:{auth_token:$canary}}'
  local preflight="$FIXTURE/preflight.json" receipt="$FIXTURE/receipt.json"
  run_helper "$preflight" "$receipt"
  if [[ "$RC" -ne 0 && ! -e "$receipt" ]] && \
    grep -Fq 'release-public-proof: BLOCKED: release_artifact_identity' "$FIXTURE/run.log" && \
    ! grep -Fq "$canary" "$FIXTURE/run.log" "$preflight"; then
    pass "credential-shaped artifact keys are rejected without exposing their values"
  else
    fail "credential-shaped artifact data passed or leaked: rc=$RC $(cat "$FIXTURE/run.log")"
  fi
}

echo "Test A: one exact-source public release join produces a sanitized receipt"
new_fixture positive
PREFLIGHT="${FIXTURE}/preflight.json"
RECEIPT="${FIXTURE}/receipt.json"
run_helper "$PREFLIGHT" "$RECEIPT"
if [[ "$RC" -eq 0 ]] && \
  jq -e --arg sha "$FIXTURE_SOURCE_SHA" --arg ci "$FIXTURE_CI_SHA" \
    '.verdict == "ready" and all(.checks[]; .status == "pass")' "$PREFLIGHT" >/dev/null && \
  jq -e --arg sha "$FIXTURE_SOURCE_SHA" --arg ci "$FIXTURE_CI_SHA" \
    '.schema == 1 and .verdict == "passed" and .package_source_sha == $sha and
     .package_source_ci.run_id == "22222" and .package_source_ci.attempt == 2 and
     .package_source_ci.head_sha == $sha and .package_source_ci.ci_gate_conclusion == "success" and
     .source_reference.resolved_commit_sha == $sha and .source_reference.path == "lib/sigra.ex" and
     (.final_main_sha == null) and (.release_receipt_commit == null)' "$RECEIPT" >/dev/null; then
  pass "tag, artifact, exact-source ci-gate, Hex, docs, and source destination join"
else
  fail "positive release proof was rejected or incomplete: rc=$RC $(cat "${FIXTURE}/run.log")"
fi

echo "Test B: missing package-source CI writes blocked preflight and no success receipt"
new_fixture missing-source-ci
MISSING_SOURCE_CI=1
export MISSING_SOURCE_CI
PREFLIGHT="${FIXTURE}/preflight.json"
RECEIPT="${FIXTURE}/receipt.json"
run_helper "$PREFLIGHT" "$RECEIPT"
unset MISSING_SOURCE_CI
if [[ "$RC" -ne 0 ]] && \
  jq -e '.verdict == "blocked" and any(.checks[]; .id == "package_source_ci" and .status == "blocked")' "$PREFLIGHT" >/dev/null && \
  [[ ! -e "$RECEIPT" ]]; then
  pass "missing exact-source CI remains blocked without a receipt"
else
  fail "missing source CI passed or did not persist a blocked preflight: rc=$RC $(cat "${FIXTURE}/run.log")"
fi

echo "Test B2: annotated tags resolve to their exact commit target"
new_fixture annotated-tag
PROOF_CASE=annotated-tag
export PROOF_CASE
PREFLIGHT="${FIXTURE}/preflight.json"
RECEIPT="${FIXTURE}/receipt.json"
run_helper "$PREFLIGHT" "$RECEIPT"
if [[ "$RC" -eq 0 ]] && jq -e --arg sha "$FIXTURE_SOURCE_SHA" '.verdict=="passed" and .package_source_sha==$sha' "$RECEIPT" >/dev/null; then
  pass "annotated tag object resolves to the package source commit"
else
  fail "valid annotated tag was rejected or changed identity: rc=$RC $(cat "${FIXTURE}/run.log")"
fi

echo "Test C: release-run, artifact, tag, package, and source-CI identity mismatches fail closed"
assert_blocked_case release-run-wrong-head release_run
assert_blocked_case release-run-wrong-workflow release_run
assert_blocked_case release-run-failed release_run
assert_blocked_case release-attempt-mismatch release_run_attempt
assert_blocked_case artifact-unavailable release_artifact
assert_blocked_case artifact-malformed-list release_artifact
assert_blocked_case duplicate-artifact release_artifact
assert_blocked_case package-tag-wrong-source release_artifact_identity
assert_blocked_case bad-annotated-target release_artifact_identity
assert_blocked_case artifact-wrong-run-id release_artifact_identity --artifact-filter '.release_run_id="99999"'
assert_blocked_case artifact-wrong-attempt release_artifact_identity --artifact-filter '.release_run_attempt=2'
assert_blocked_case artifact-wrong-source release_artifact_identity --artifact-filter '.source_sha="ffffffffffffffffffffffffffffffffffffffff"'
assert_blocked_case artifact-wrong-version release_artifact_identity --artifact-filter '.version="1.5.9"'
assert_blocked_case artifact-wrong-tag release_artifact_identity --artifact-filter '.tag="v1.5.9"'
assert_blocked_case source-ci-wrong-workflow package_source_ci
assert_blocked_case source-ci-wrong-head package_source_ci
assert_blocked_case ci-run-wrong-id package_source_ci
assert_blocked_case ci-failed package_source_ci
assert_blocked_case ci-attempt-mismatch package_source_ci
assert_blocked_case ci-gate-missing package_source_ci
assert_blocked_case ci-gate-wrong-head package_source_ci
assert_blocked_case ci-gate-attempt-mismatch package_source_ci
assert_blocked_case ci-gate-failed package_source_ci
assert_blocked_case source-ci-missing package_source_ci --missing-source-ci
assert_blocked_case hex-unavailable hex_release
assert_blocked_case hex-wrong-version hex_release
assert_blocked_case docs-unavailable versioned_hexdocs
assert_blocked_case docs-wrong-version versioned_hexdocs
assert_blocked_case source-href-wrong-tag rendered_source_reference
assert_blocked_case source-redirect-wrong-tag rendered_source_reference
assert_blocked_case source-redirect-wrong-commit rendered_source_reference
assert_blocked_case source-redirect-wrong-path rendered_source_reference
assert_blocked_case source-content-wrong-commit rendered_source_reference
assert_blocked_case source-content-wrong-path rendered_source_reference

echo "Test D: artifact bytes remain inert, credential-free, and regular-file only"
assert_blocked_case artifact-malformed-json release_artifact --archive malformed-json
assert_blocked_case artifact-extra-member release_artifact --archive extra-member
assert_blocked_case artifact-traversal-member release_artifact --archive traversal-member
assert_blocked_case artifact-json-symlink release_artifact --archive json-symlink
assert_credentials_are_rejected_without_leaking
assert_diagnostic_is_inert
assert_shell_payload_is_not_projected

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
