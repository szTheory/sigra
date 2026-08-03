#!/usr/bin/env bash
# Hermetic contract for the fixed FAST-01 remeasurement collector.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COLLECTOR="$ROOT/scripts/ci/capture-fast-01-remeasurement.sh"

fail() { echo "capture-fast-01-remeasurement.test: FAIL: $*" >&2; exit 1; }
[[ -x "$COLLECTOR" ]] || fail "collector missing or not executable"
grep -Fq 'git show -s --format=%ct "$CUTOFF_SHA"' "$COLLECTOR" || fail "cutoff instant is not compared canonically"
grep -Fq 'CUTOFF_EPOCH="1785771372"' "$COLLECTOR" || fail "fixed cutoff epoch drifted"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"

make_runs() {
  local count="$1" duration_base="$2" output="$3"
  jq -n --argjson count "$count" --argjson base "$duration_base" '
    [range(0; $count) | {
      id: (1000 + .), event: "pull_request", conclusion: (if . % 3 == 0 then "failure" elif . % 3 == 1 then "cancelled" else "success" end),
      created_at: "2026-08-03T15:36:13Z",
      updated_at: ("2026-08-03T15:" + ((36 + (($base + .) / 60 | floor)) | tostring | if length == 1 then "0" + . else . end) + ":" + (($base + .) % 60 | tostring | if length == 1 then "0" + . else . end) + "Z"),
      html_url: ("https://github.com/szTheory/sigra/actions/runs/" + (1000 + . | tostring))
    }]' >"$output"
}

cat >"$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "api" && "$2" == "rate_limit" ]]; then
  jq -n --argjson remaining "${FAKE_REMAINING:-500}" --arg reset "2030-01-01T00:00:00Z" '{resources:{core:{remaining:$remaining,reset:$reset}}}'
  exit 0
fi
endpoint="$2"
if [[ "${FAKE_HTTP:-}" == "403" || "${FAKE_HTTP:-}" == "429" ]]; then exit 1; fi
page="${endpoint##*page=}"
if [[ "$page" != "1" ]]; then jq -n '{total_count: (env.FAKE_RUNS | fromjson | length), workflow_runs: []}'; exit 0; fi
jq -n --argjson runs "$FAKE_RUNS" '{total_count: ($runs|length), workflow_runs:$runs}'
EOF
chmod +x "$TMP/bin/gh"

run_readiness() {
  local count="$1"
  local out="$TMP/out-$count.json"
  make_runs "$count" 719 "$TMP/runs.json"
  local before after endpoint
  before="$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)"
  PATH="$TMP/bin:$PATH" FAKE_RUNS="$(cat "$TMP/runs.json")" "$COLLECTOR" --readiness "$out"
  after="$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)"
  endpoint="$(jq -r '.window.endpoint' "$out")"
  [[ "$endpoint" > "$before" || "$endpoint" == "$before" ]] || fail "endpoint predates invocation"
  [[ "$endpoint" < "$after" || "$endpoint" == "$after" ]] || fail "endpoint follows invocation"
  jq -e --arg expected "$(if (( count < 10 )); then echo insufficient_population; else echo ready; fi)" --argjson count "$count" '
    .schema_version == "sigra.fast-01-remeasurement-readiness/v1" and
    .authority == "readiness_only" and .endpoint_source == "collector_current_utc" and
    .status == $expected and .eligible_pr_run_count == $count and
    .statistics == null and .verdict == null and (.runs | length) == .eligible_pr_run_count
  ' "$out" >/dev/null || fail "readiness schema/status mismatch for n=$count"
}

for n in 0 1 9 10 11; do run_readiness "$n"; done

# A concurrent push run is outside the declared PR population and may still be
# in progress.  Its null conclusion must not suppress valid readiness, whereas
# the same malformed state on a PR row remains fail-closed.
make_runs 10 719 "$TMP/runs.json"
jq '. + [{id: 9999, event: "push", conclusion: null, created_at: "2026-08-03T15:36:13Z", updated_at: "2026-08-03T15:36:14Z", html_url: "https://example.test/9999"}]' "$TMP/runs.json" >"$TMP/mixed.json"
PATH="$TMP/bin:$PATH" FAKE_RUNS="$(cat "$TMP/mixed.json")" "$COLLECTOR" --readiness "$TMP/mixed-out.json"
jq -e '.eligible_pr_run_count == 10 and .status == "ready"' "$TMP/mixed-out.json" >/dev/null || fail "in-progress push poisoned PR readiness"
jq '.[0].conclusion = null' "$TMP/runs.json" >"$TMP/malformed-pr.json"
if PATH="$TMP/bin:$PATH" FAKE_RUNS="$(cat "$TMP/malformed-pr.json")" "$COLLECTOR" --readiness "$TMP/malformed-pr-out.json" >/dev/null 2>&1; then
  fail "collector accepted malformed pull_request row"
fi

make_runs 10 719 "$TMP/runs.json"
for bad in '--endpoint 2030-01-01T00:00:00Z' 'extra'; do
  if PATH="$TMP/bin:$PATH" FAKE_RUNS="$(cat "$TMP/runs.json")" FAST_01_ENDPOINT=2030-01-01T00:00:00Z "$COLLECTOR" --readiness "$TMP/adversary.json" $bad >/dev/null 2>&1; then
    fail "local interface accepted caller-controlled argument: $bad"
  fi
done

if PATH="$TMP/bin:$PATH" FAKE_REMAINING=250 FAKE_RUNS="$(cat "$TMP/runs.json")" "$COLLECTOR" --readiness "$TMP/rate.json" >/dev/null 2>&1; then
  fail "collector accepted core remaining at 250"
fi
if PATH="$TMP/bin:$PATH" FAKE_HTTP=429 FAKE_RUNS="$(cat "$TMP/runs.json")" "$COLLECTOR" --readiness "$TMP/http.json" >/dev/null 2>&1; then
  fail "collector accepted 429"
fi

echo "capture-fast-01-remeasurement.test: PASS"
