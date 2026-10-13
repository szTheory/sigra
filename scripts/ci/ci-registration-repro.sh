#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ci-registration-repro.sh --create-revision --output <freeze.json>
  ci-registration-repro.sh --prepare-revision <freeze.json> --evidence <evidence.json>
  ci-registration-repro.sh --run-revision <freeze.json> --slot <id> --output <evidence.json>
  ci-registration-repro.sh --create-infrastructure-retry --freeze <prior-freeze> --evidence <halted-evidence> --review <review.json> --output <retry-freeze> --reservation <reservation.json>
  ci-registration-repro.sh --refresh-infrastructure-retry --freeze <unused-retry-freeze> --output <new-retry-freeze>
  ci-registration-repro.sh --verify-diagnostic <evidence.json> --revision
  ci-registration-repro.sh --run-recovery <freeze.json> --output <new-evidence.json>
  ci-registration-repro.sh --verify-diagnostic <evidence.json>
  ci-registration-repro.sh --run-frozen <freeze.json> --output <evidence.json>
  ci-registration-repro.sh --diagnose-setup --output <evidence.json>
  ci-registration-repro.sh --verify-controls <evidence.json>
  ci-registration-repro.sh --verify-acceptance <evidence.json>
  ci-registration-repro.sh <mode> --help
USAGE
}

for arg in "$@"; do
  if [[ "$arg" == --help ]]; then usage; exit 0; fi
done

MODE="${1:-}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PHASE_DIR="$ROOT/.planning/phases/253-fix-flaky-ci-and-preserve-required-checks"
FREEZE=""
OUTPUT=""
case "$MODE" in
  --create-revision)
    [[ "${2:-}" == --output && -n "${3:-}" && -z "${4:-}" ]] || { usage >&2; exit 2; }
    OUTPUT="${3}"
    ;;
  --prepare-revision)
    FREEZE="${2:-}"
    [[ -n "$FREEZE" && "${3:-}" == --evidence && -n "${4:-}" && -z "${5:-}" ]] || { usage >&2; exit 2; }
    OUTPUT="${4}"
    ;;
  --run-revision)
    FREEZE="${2:-}"
    [[ -n "$FREEZE" && "${3:-}" == --slot && -n "${4:-}" && "${5:-}" == --output && -n "${6:-}" && -z "${7:-}" ]] || { usage >&2; exit 2; }
    SLOT="${4}"
    OUTPUT="${6}"
    ;;
  --create-infrastructure-retry)
    [[ "${2:-}" == --freeze && -n "${3:-}" && "${4:-}" == --evidence && -n "${5:-}" && "${6:-}" == --review && -n "${7:-}" && "${8:-}" == --output && -n "${9:-}" && "${10:-}" == --reservation && -n "${11:-}" && -z "${12:-}" ]] || { usage >&2; exit 2; }
    FREEZE="${3}"; RETRY_EVIDENCE="${5}"; REVIEW="${7}"; OUTPUT="${9}"; RESERVATION="${11}"
    ;;
  --refresh-infrastructure-retry)
    FREEZE="${3:-}"
    [[ "${2:-}" == --freeze && -n "$FREEZE" && "${4:-}" == --output && -n "${5:-}" && -z "${6:-}" ]] || { usage >&2; exit 2; }
    OUTPUT="${5}"
    ;;
  --run-frozen)
    FREEZE="${2:-}"
    [[ "${3:-}" == --output && -n "${4:-}" ]] || { usage >&2; exit 2; }
    OUTPUT="${4}"
    ;;
  --run-recovery)
    FREEZE="${2:-}"
    [[ "${3:-}" == --output && -n "${4:-}" ]] || { usage >&2; exit 2; }
    OUTPUT="${4}"
    ;;
  --verify-diagnostic)
    OUTPUT="${2:-}"
    if [[ "${3:-}" == --revision ]]; then REVISION=true; [[ -z "${4:-}" ]] || { usage >&2; exit 2; }
    else [[ -n "$OUTPUT" && -z "${3:-}" ]] || { usage >&2; exit 2; }; fi
    ;;
  --diagnose-setup)
    [[ "${2:-}" == --output && -n "${3:-}" && -z "${4:-}" ]] || { usage >&2; exit 2; }
    OUTPUT="${3}"
    ;;
  --verify-controls|--verify-acceptance)
    OUTPUT="${2:-}"
    [[ -n "$OUTPUT" ]] || { usage >&2; exit 2; }
    ;;
  *) usage >&2; exit 2 ;;
esac
if [[ -n "$FREEZE" && "$FREEZE" != /* ]]; then FREEZE="$ROOT/$FREEZE"; fi
if [[ -n "$OUTPUT" && "$OUTPUT" != /* ]]; then OUTPUT="$ROOT/$OUTPUT"; fi

if [[ "$MODE" == --create-revision ]]; then
  exec node "$ROOT/scripts/ci/ci-registration-recovery.mjs" --create-revision --output "$OUTPUT"
fi

if [[ "$MODE" == --create-infrastructure-retry ]]; then
  [[ "$FREEZE" != /* ]] && FREEZE="$ROOT/$FREEZE"
  [[ "$RETRY_EVIDENCE" != /* ]] && RETRY_EVIDENCE="$ROOT/$RETRY_EVIDENCE"
  [[ "$REVIEW" != /* ]] && REVIEW="$ROOT/$REVIEW"
  [[ "$OUTPUT" != /* ]] && OUTPUT="$ROOT/$OUTPUT"
  [[ "$RESERVATION" != /* ]] && RESERVATION="$ROOT/$RESERVATION"
  exec node "$ROOT/scripts/ci/ci-registration-recovery.mjs" --create-infrastructure-retry --freeze "$FREEZE" --evidence "$RETRY_EVIDENCE" --review "$REVIEW" --output "$OUTPUT" --reservation "$RESERVATION"
fi

if [[ "$MODE" == --refresh-infrastructure-retry ]]; then
  [[ "$FREEZE" != /* ]] && FREEZE="$ROOT/$FREEZE"
  [[ "$OUTPUT" != /* ]] && OUTPUT="$ROOT/$OUTPUT"
  exec node "$ROOT/scripts/ci/ci-registration-recovery.mjs" --refresh-infrastructure-retry --freeze "$FREEZE" --output "$OUTPUT"
fi

if [[ "$MODE" == --prepare-revision ]]; then
  exec node "$ROOT/scripts/ci/ci-registration-recovery.mjs" --prepare-revision "$FREEZE" --evidence "$OUTPUT"
fi

if [[ "$MODE" == --run-revision ]]; then
  exec node "$ROOT/scripts/ci/ci-registration-recovery.mjs" --run-revision "$FREEZE" --slot "$SLOT" --output "$OUTPUT"
fi

if [[ "$MODE" == --run-recovery ]]; then
  exec node "$ROOT/scripts/ci/ci-registration-recovery.mjs" --run-recovery "$FREEZE" --output "$OUTPUT"
fi

if [[ "$MODE" == --verify-diagnostic ]]; then
  if [[ "${REVISION:-false}" == true ]]; then
    exec node "$ROOT/scripts/ci/ci-registration-recovery.mjs" --verify-diagnostic "$OUTPUT" --revision
  fi
  exec node "$ROOT/scripts/ci/ci-registration-recovery.mjs" --verify-diagnostic "$OUTPUT"
fi

if [[ "$MODE" == --diagnose-setup ]]; then
  exec node "$ROOT/scripts/ci/ci-registration-setup-diagnostic.mjs" --root "$ROOT" --output "$OUTPUT"
fi

if [[ "$MODE" != --run-frozen ]]; then
  # The halted runner has no producer for verified browser/control receipts.
  # Claims in a caller-written JSON file are diagnostics, never acceptance.
  echo "$MODE: native browser and control receipts validation is not implemented; registration acceptance remains unverified" >&2
  exit 3
fi

# The original registration freeze exhausted its allowance. Recovery browser work
# must use a new committed freeze and a separate evidence ledger.
echo 'the original registration freeze is exhausted; use --run-recovery with a new recovery freeze' >&2
exit 3

[[ -f "$FREEZE" ]] || { echo "missing freeze: $FREEZE" >&2; exit 2; }
HEAD="$(git -C "$ROOT" rev-parse HEAD)"
EXPECTED_HEAD="$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1])).source.checkout_head)' "$FREEZE")"
[[ "$HEAD" == "$EXPECTED_HEAD" ]] || { echo "checkout mismatch: expected $EXPECTED_HEAD, found $HEAD" >&2; exit 3; }
git -C "$ROOT" diff --quiet && git -C "$ROOT" diff --cached --quiet || { echo 'tracked checkout changes are not allowed' >&2; exit 3; }
HELPER_BLOB="$(git -C "$ROOT" hash-object test/example/priv/playwright/tests/admin-eval.spec.ts)"
EXPECTED_HELPER="$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1])).source.historical_helper_blob)' "$FREEZE")"
[[ "$HELPER_BLOB" == "$EXPECTED_HELPER" ]] || { echo "helper identity mismatch: $HELPER_BLOB" >&2; exit 3; }
WORKFLOW_BLOB="$(git -C "$ROOT" rev-parse HEAD:.github/workflows/ci.yml)"
EXPECTED_WORKFLOW="$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1])).source.workflow_blob)' "$FREEZE")"
[[ "$WORKFLOW_BLOB" == "$EXPECTED_WORKFLOW" ]] || { echo "workflow identity mismatch: $WORKFLOW_BLOB" >&2; exit 3; }

if [[ -f "$OUTPUT" ]]; then
  node - "$OUTPUT" <<'NODE'
const fs = require('node:fs');
const path = process.argv[2];
const evidence = JSON.parse(fs.readFileSync(path, 'utf8'));
if (evidence.status !== 'running') throw new Error(`refusing to overwrite terminal evidence: ${evidence.status}`);
evidence.attempts.push(...evidence.projects.map((project) => ({
  ...project,
  classification: 'diagnosed_runner_infrastructure_failure',
  diagnosis: 'The launcher process was not retained and the shared Mix build was compiled for a different port.'
})));
evidence.projects = [];
evidence.limits.observedInvocations += evidence.attempts.length;
fs.writeFileSync(path, JSON.stringify(evidence, null, 2) + '\n');
NODE
fi

mkdir -p "$(dirname "$OUTPUT")"
OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sigra-253-registration.XXXXXX")"
OUT_DIR="$(cd "$OUT_DIR" && pwd -P)"
CHECKOUT="$OUT_DIR/checkout"
mkdir "$CHECKOUT"
START_EPOCH="$(date +%s)"
STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
PROJECT_RESULTS='[]'
PIDS=()
cleanup() {
  local pid
  for pid in "${PIDS[@]:-}"; do kill "$pid" 2>/dev/null || true; done
}
trap cleanup EXIT INT TERM

git clone --quiet --shared --no-checkout "$ROOT" "$CHECKOUT/repo"
git -C "$CHECKOUT/repo" checkout --quiet --detach "$EXPECTED_HEAD"
export HEX_HOME="$OUT_DIR/hex"
mkdir -p "$HEX_HOME"
PW="$CHECKOUT/repo/test/example/priv/playwright"
cd "$PW"
npm ci
PW_VERSION="$(./node_modules/.bin/playwright --version | awk '{print $2}')"
[[ "$PW_VERSION" == "1.59.1" ]] || { echo "Playwright version mismatch: $PW_VERSION" >&2; exit 4; }
cd "$CHECKOUT/repo/test/example"
MIX_ENV=dev mix deps.get --check-locked
ECTO_VERSION="$(MIX_ENV=dev mix deps | awk '$1 == "*" && $2 == "ecto_sql" {version=$3} END {print version}')"
LIVEVIEW_VERSION="$(MIX_ENV=dev mix deps | awk '$1 == "*" && $2 == "phoenix_live_view" {version=$3} END {print version}')"

NOW="$(date -u +%Y%m%dT%H%M%SZ)"
for project in admin-eval admin-eval-mobile admin-eval-dark; do
  ELAPSED=$(( $(date +%s) - START_EPOCH ))
  (( ELAPSED < 1200 )) || { echo '20-minute signature budget reached' >&2; break; }
  case "$project" in
    admin-eval) PORT=25311 ;;
    admin-eval-mobile) PORT=25312 ;;
    admin-eval-dark) PORT=25313 ;;
  esac
  DB="sigra_253_${NOW//[^a-zA-Z0-9]/}_${project//-/_}_$$"
  APP_LOG="$OUT_DIR/${project}.app.log"
  TEST_LOG="$OUT_DIR/${project}.test.log"
  TRACE_DIR="$PW/test-results"
  rm -rf "$TRACE_DIR"
  export PGHOST=127.0.0.1 PGPORT=58624 PGUSER=postgres PGPASSWORD=postgres PGDATABASE="$DB"
  export PORT SIGRA_EXAMPLE_BIND=127.0.0.1
  export MIX_BUILD_PATH="$CHECKOUT/repo/test/example/_build/$project"
  (cd "$CHECKOUT/repo/test/example" && MIX_ENV=dev mix ecto.setup) >"$OUT_DIR/${project}.db.log" 2>&1
  (cd "$CHECKOUT/repo/test/example" && exec env MIX_ENV=dev mix phx.server) >"$APP_LOG" 2>&1 &
  APP_PID=$!
  PIDS+=("$APP_PID")
  URL="http://127.0.0.1:$PORT"
  READY=false
  if curl --silent --show-error --fail --max-time 2 --retry 90 --retry-all-errors \
    --retry-delay 0 --retry-max-time 90 "$URL/" -o /dev/null 2>/dev/null; then
    READY=true
  fi
  TEST_EXIT=125
  if [[ "$READY" == true ]]; then
    set +e
    CI=true SIGRA_EXAMPLE_URL="$URL" SIGRA_PLAYWRIGHT_JSON="$OUT_DIR/${project}.report.json" \
      "$PW/node_modules/.bin/playwright" test tests/admin-eval.spec.ts \
        --project="$project" --grep='render bundle: board-mg-9/populated' \
        --retries=0 --trace=retain-on-failure >"$TEST_LOG" 2>&1
    TEST_EXIT=$?
    set -e
  else
    printf 'App server did not become HTTP-ready at %s\n' "$URL" >"$TEST_LOG"
  fi
  kill "$APP_PID" 2>/dev/null || true
  wait "$APP_PID" 2>/dev/null || true
  PIDS=()
  cp -R "$TRACE_DIR" "$OUT_DIR/${project}.test-results" 2>/dev/null || true
  (cd "$CHECKOUT/repo/test/example" && MIX_ENV=dev mix ecto.drop --quiet) >"$OUT_DIR/${project}.drop.log" 2>&1 || true
  node - "$OUTPUT" "$project" "$PORT" "$DB" "$READY" "$TEST_EXIT" "$APP_LOG" "$TEST_LOG" "$OUT_DIR/${project}.report.json" "$OUT_DIR/${project}.test-results" "$PW_VERSION" "$ECTO_VERSION" "$LIVEVIEW_VERSION" "$OUT_DIR" <<'NODE'
const fs = require('node:fs');
const crypto = require('node:crypto');
const [out, project, port, database, ready, exit, appLog, testLog, report, artifacts, playwright, ecto, liveview, root] = process.argv.slice(2);
let evidence;
if (fs.existsSync(out)) evidence = JSON.parse(fs.readFileSync(out, 'utf8'));
else evidence = {
  schema_version: 'sigra.phase253.registration-evidence/v1',
  status: 'running',
  source: { checkoutHead: 'de53d1c80f4a67b73a5e5078959c2c88ad75abe8', helperBlob: '6540493e78121f134867445dffc7010afcd85815', workflowBlob: 'dcc36d0df055f9b11f4de36252cb6b3d0f6c8c85' },
  startedAt: new Date().toISOString(), projects: [], controls: {}, attempts: [],
  limits: { maxInvocations: 10, maxMinutesPerSignature: 20, maxMinutesTotal: 60, observedInvocations: 0 }
};
const hash = (path) => fs.existsSync(path) ? crypto.createHash('sha256').update(fs.readFileSync(path)).digest('hex') : null;
const artifactNames = fs.existsSync(artifacts) ? fs.readdirSync(artifacts, { recursive: true }).filter((name) => /trace\.zip$/.test(name)) : [];
evidence.projects.push({
  project, port: Number(port), database, serverReady: ready === 'true', testExitCode: Number(exit),
  originalOutcome: Number(exit) === 0 ? 'passed' : 'failed', appLogPath: appLog, appLogSha256: hash(appLog),
  testLogPath: testLog, testLogSha256: hash(testLog), reportPath: fs.existsSync(report) ? report : null,
  reportSha256: hash(report), traceFiles: artifactNames, toolchain: { playwright, ectoSql: ecto, phoenixLiveView: liveview }
});
evidence.limits.observedInvocations += 1;
evidence.status = 'running';
fs.writeFileSync(out, JSON.stringify(evidence, null, 2) + '\n');
NODE
  OUTPUT_STATE="$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1])).status)' "$OUTPUT")"
  if [[ "$OUTPUT_STATE" == running ]]; then
    node -e 'const fs=require("fs");const p=process.argv[1];const x=JSON.parse(fs.readFileSync(p));fs.writeFileSync(p,JSON.stringify(x,null,2)+"\n")' "$OUTPUT"
  fi
done

END_EPOCH="$(date +%s)"
node - "$OUTPUT" "$STARTED_AT" "$END_EPOCH" "$START_EPOCH" <<'NODE'
const fs = require('node:fs');
const path = process.argv[2];
const evidence = JSON.parse(fs.readFileSync(path, 'utf8'));
const elapsed = Number(process.argv[3]) - Number(process.argv[4]);
evidence.completedAt = new Date().toISOString();
evidence.durationSeconds = elapsed;
evidence.status = evidence.projects.length === 3 && evidence.projects.every((p) => p.originalOutcome === 'passed') ? 'not_reproduced' : 'diagnosis_incomplete';
evidence.requirements = { 'CIREL-01': 'unsatisfied' };
evidence.diagnosis = { cause: 'unknown', claim: 'The bounded current-source run does not explain the retained historical failure.' };
fs.writeFileSync(path, JSON.stringify(evidence, null, 2) + '\n');
NODE
echo "registration reproduction status: $(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1])).status)' "$OUTPUT")"
