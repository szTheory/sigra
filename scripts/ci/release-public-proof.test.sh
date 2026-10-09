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
  export FIXTURE FIXTURE_MAIN_SHA FIXTURE_SOURCE_SHA FIXTURE_CI_SHA FIXTURE_BLOB_SHA FIXTURE_CHECKSUM

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
    jq -n --arg sha "$FIXTURE_SOURCE_SHA" '{ref:"refs/tags/v1.6.0",object:{type:"commit",sha:$sha}}'
    ;;
  repos/szTheory/sigra/actions/runs\?head_sha=*)
    jq -n --arg sha "$FIXTURE_SOURCE_SHA" '{workflow_runs:[{id:11111,run_attempt:3,head_sha:$sha,path:".github/workflows/release-please.yml",event:"push",status:"completed",conclusion:"success",html_url:"https://github.com/szTheory/sigra/actions/runs/11111",run_started_at:"2026-10-09T04:00:00Z"}]}'
    ;;
  repos/szTheory/sigra/actions/runs/11111/attempts/3)
    jq -n --arg sha "$FIXTURE_SOURCE_SHA" '{id:11111,run_attempt:3,head_sha:$sha,path:".github/workflows/release-please.yml",event:"push",status:"completed",conclusion:"success",html_url:"https://github.com/szTheory/sigra/actions/runs/11111"}'
    ;;
  repos/szTheory/sigra/actions/runs/11111/artifacts)
    printf '{"artifacts":[{"id":33333,"name":"release-result-1.6.0-11111","expired":false,"archive_download_url":"https://api.github.com/repos/szTheory/sigra/actions/artifacts/33333/zip"}]}\n'
    ;;
  repos/szTheory/sigra/actions/artifacts/33333/zip)
    cat "$FIXTURE/release-result.zip"
    ;;
  repos/szTheory/sigra/actions/runs/22222)
    [[ "${MISSING_SOURCE_CI:-0}" == 0 ]] || exit 1
    jq -n --arg sha "$FIXTURE_SOURCE_SHA" '{id:22222,run_attempt:2,head_sha:$sha,path:".github/workflows/ci.yml",status:"completed",conclusion:"success",html_url:"https://github.com/szTheory/sigra/actions/runs/22222"}'
    ;;
  repos/szTheory/sigra/actions/runs/22222/attempts/2)
    [[ "${MISSING_SOURCE_CI:-0}" == 0 ]] || exit 1
    jq -n --arg sha "$FIXTURE_SOURCE_SHA" '{id:22222,run_attempt:2,head_sha:$sha,path:".github/workflows/ci.yml",status:"completed",conclusion:"success",html_url:"https://github.com/szTheory/sigra/actions/runs/22222"}'
    ;;
  repos/szTheory/sigra/actions/runs/22222/attempts/2/jobs)
    [[ "${MISSING_SOURCE_CI:-0}" == 0 ]] || exit 1
    jq -n --arg sha "$FIXTURE_SOURCE_SHA" '{jobs:[{id:22223,name:"ci-gate",head_sha:$sha,run_attempt:2,status:"completed",conclusion:"success",html_url:"https://github.com/szTheory/sigra/actions/runs/22222/job/22223"}]}'
    ;;
  repos/szTheory/sigra/contents/lib/sigra.ex\?ref=*)
    jq -n --arg sha "$FIXTURE_BLOB_SHA" --arg source "$FIXTURE_SOURCE_SHA" '{path:"lib/sigra.ex",sha:$sha,html_url:("https://github.com/szTheory/sigra/blob/"+$source+"/lib/sigra.ex")}'
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
    jq -n --arg checksum "$FIXTURE_CHECKSUM" '{version:"1.6.0",html_url:"https://hex.pm/packages/sigra/1.6.0",checksum:$checksum}' > "$output"
    ;;
  https://hexdocs.pm/sigra/1.6.0/Sigra.html)
    printf '<html><a href="https://github.com/sztheory/sigra/blob/v1.6.0/lib/sigra.ex#L1">View Source</a></html>\n' > "$output"
    effective="https://sigra.hexdocs.pm/1.6.0/Sigra.html"
    ;;
  https://github.com/sztheory/sigra/blob/v1.6.0/lib/sigra.ex\#L1)
    : > "$output"
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
      MISSING_SOURCE_CI="${MISSING_SOURCE_CI:-0}" \
      bash "$SCRIPT" --version 1.6.0 --preflight "$preflight" --output "$receipt"
  ) > "${FIXTURE}/run.log" 2>&1
  RC=$?
  set -e
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

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
