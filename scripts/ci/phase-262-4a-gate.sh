#!/usr/bin/env bash
set -euo pipefail

# Phase 262 Plan 03: blocking evidence for the 4a support slice.
# This runner is fail-closed: its report starts failed, each check is recorded
# only after exit zero, and status becomes passed only after every check passes.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

HEX_HOME="/private/tmp/sigra-phase262-hex-home"
export HEX_HOME
REPORT="$ROOT/.planning/phases/262-words-and-layout/262-4A-GATE.json"
mkdir -p "$(dirname "$REPORT")"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sigra-phase262-4a.XXXXXX")"
LOG_DIR="$WORK_DIR/logs"
RESULTS_FILE="$WORK_DIR/results.tsv"
CATALOG_RAW_DIR="$WORK_DIR/catalog-raw"
mkdir -p "$LOG_DIR" "$CATALOG_RAW_DIR"
: > "$RESULTS_FILE"

SERVER_PID=""
SERVER_LOG="$LOG_DIR/example-server.log"
SERVER_URL="http://127.0.0.1:4011"

cleanup() {
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

CMD_LIBRARY_SUPPORT="HEX_HOME=$HEX_HOME MIX_ENV=test mix test test/sigra/admin/components_test.exs test/sigra/doctor_test.exs test/sigra/mix/tasks/doctor_task_test.exs test/sigra/install/asset_parity_test.exs:280 test/sigra/install/asset_parity_test.exs:329 test/sigra/install/asset_parity_test.exs:334"
CMD_SUPPORT_LIVEVIEW="cd test/example && HEX_HOME=$HEX_HOME MIX_ENV=test mix test --include example_app test/example_web/live/admin_user_index_live_test.exs test/example_web/live/admin_user_show_live_test.exs test/example_web/live/admin_user_sessions_live_test.exs"
CMD_ENUMERATION="cd test/example && HEX_HOME=$HEX_HOME MIX_ENV=test mix test --include example_app test/example_web/enumeration_parity_test.exs"
CMD_CONTRAST="HEX_HOME=$HEX_HOME MIX_ENV=test mix test test/sigra/brand/css_contrast_test.exs test/sigra/brand/contrast_pairs_test.exs"
CMD_GLOSSARY="HEX_HOME=$HEX_HOME MIX_ENV=test mix test test/sigra/brand/copy_contract_test.exs test/sigra/admin/glossary_test.exs test/sigra/brand/vocabulary_docs_test.exs"
CMD_COPY_INVENTORY="HEX_HOME=$HEX_HOME MIX_ENV=test mix test test/sigra/brand/copy_inventory_test.exs"
CMD_CSS_CONFORMANCE="bash scripts/ci/admin-css-conformance.sh"
CMD_PREVIOUS_RELEASE="HEX_HOME=$HEX_HOME MIX_ENV=test mix test test/sigra/install/old_admin_css_compatibility_test.exs"
CMD_CATALOG_CAPTURE="cd test/example && HEX_HOME=$HEX_HOME MIX_ENV=test SIGRA_CATALOG_RAW_DIR=$CATALOG_RAW_DIR mix test --include example_app test/example_web/catalog_test.exs && cd ../.. && HEX_HOME=$HEX_HOME MIX_ENV=test SIGRA_BRAND_CATALOG=after SIGRA_CATALOG_RAW_DIR=$CATALOG_RAW_DIR mix test test/sigra/brand/catalog_test.exs"
LIGHT_CATALOG_DIFF_LOG="$LOG_DIR/normalized_light_catalog_diff.log"
DARK_CATALOG_DIFF_LOG="$LOG_DIR/normalized_dark_catalog_diff.log"
CATALOG_DIFF_COMMAND="bash scripts/brand/catalog-diff.sh test/fixtures/brand/before tmp/catalog-after"
CMD_LIGHT_CATALOG_DIFF="$CATALOG_DIFF_COMMAND > '$LIGHT_CATALOG_DIFF_LOG' && rg -q '^\+\+\+ after/tier1-library-admin/user_sessions_live--empty\.html$' '$LIGHT_CATALOG_DIFF_LOG' && rg -q '^\+\+\+ after/tier1-library-admin/user_sessions_live--populated\.html$' '$LIGHT_CATALOG_DIFF_LOG' && rg -q '^\+\+\+ after/tier1-library-admin/user_show_live--active\.html$' '$LIGHT_CATALOG_DIFF_LOG' && rg -q '^\+\+\+ after/tier1-library-admin/user_show_live--locked\.html$' '$LIGHT_CATALOG_DIFF_LOG' && rg -q '^\+\+\+ after/tier1-library-admin/user_show_live--scheduled_deletion\.html$' '$LIGHT_CATALOG_DIFF_LOG' && rg -q '^\+\+\+ after/tier1-library-admin/user_show_live--unconfirmed\.html$' '$LIGHT_CATALOG_DIFF_LOG' && rg -q '^\+\+\+ after/tier1-library-admin/users_index_live--populated\.html$' '$LIGHT_CATALOG_DIFF_LOG' && cat '$LIGHT_CATALOG_DIFF_LOG'"
CMD_DARK_CATALOG_DIFF="$CATALOG_DIFF_COMMAND > '$DARK_CATALOG_DIFF_LOG' && rg -q '^\+\+\+ after/tier1-library-admin/user_sessions_live--empty\.html$' '$DARK_CATALOG_DIFF_LOG' && rg -q '^\+\+\+ after/tier1-library-admin/user_sessions_live--populated\.html$' '$DARK_CATALOG_DIFF_LOG' && rg -q '^\+\+\+ after/tier1-library-admin/user_show_live--active\.html$' '$DARK_CATALOG_DIFF_LOG' && rg -q '^\+\+\+ after/tier1-library-admin/user_show_live--locked\.html$' '$DARK_CATALOG_DIFF_LOG' && rg -q '^\+\+\+ after/tier1-library-admin/user_show_live--scheduled_deletion\.html$' '$DARK_CATALOG_DIFF_LOG' && rg -q '^\+\+\+ after/tier1-library-admin/user_show_live--unconfirmed\.html$' '$DARK_CATALOG_DIFF_LOG' && rg -q '^\+\+\+ after/tier1-library-admin/users_index_live--populated\.html$' '$DARK_CATALOG_DIFF_LOG' && cat '$DARK_CATALOG_DIFF_LOG'"
CMD_PLAYWRIGHT_PREFLIGHT="test -x test/example/priv/playwright/node_modules/.bin/playwright && rg -q 'retries: 0' test/example/priv/playwright/playwright.config.ts && ! rg -n 'page\\.waitForTimeout|waitForTimeout' test/example/priv/playwright/tests/admin-user-operations.spec.ts test/example/priv/playwright/tests/admin-modal-interaction.spec.ts"
CMD_SERVER_START="HEX_HOME=$HEX_HOME MIX_ENV=dev PORT=4011 mix phx.server (background; GET $SERVER_URL/ must return HTTP 200)"
CMD_MODAL="cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test --project=chromium tests/admin-modal-interaction.spec.ts --retries=0"
CMD_OVERFLOW="cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test --project=chromium tests/admin-user-operations.spec.ts --grep \"4a support long-content overflow\" --retries=0"
CMD_REFLOW="cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test --project=chromium tests/admin-user-operations.spec.ts --grep \"4a support 320px/200% reflow\" --retries=0"
CMD_THEME_SWITCH="cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test --project=chromium tests/admin-theme.spec.ts --grep \"persists Light, Dark, and System without global DaisyUI theme state\" --retries=0"
CMD_LIGHT_CHECKPOINTS="cd test/example/priv/playwright && SIGRA_PNG_COMPARE_SKIP=1 SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test --project=admin-checkpoints-chromium tests/admin-checkpoints.spec.ts --grep \"captures curated admin review pages across desktop/mobile/dark\" --retries=0"
CMD_LIGHT_DESIGN_AXE="cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test --project=admin-design-chromium tests/admin-design.spec.ts --grep \"axe: full-page WCAG 2.1/2.2 AA on the design gallery\" --retries=0"
CMD_DARK_CHECKPOINTS="cd test/example/priv/playwright && SIGRA_PNG_COMPARE_SKIP=1 SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test --project=admin-checkpoints-dark tests/admin-checkpoints.spec.ts --grep \"captures curated admin review pages across desktop/mobile/dark\" --retries=0"
CMD_DARK_DESIGN_AXE="cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test --project=admin-design-dark tests/admin-design.spec.ts --grep \"axe: full-page WCAG 2.1/2.2 AA on the design gallery\" --retries=0"

write_report() {
  GATE_STATUS="${GATE_STATUS:-failed}" \
  GATE_FAILURE_CHECK="${GATE_FAILURE_CHECK:-}" \
  GATE_FAILURE_EXIT="${GATE_FAILURE_EXIT:-}" \
  GATE_FAILURE_LOG="${GATE_FAILURE_LOG:-}" \
  GATE_WORK_DIR="$WORK_DIR" \
  GATE_RESULTS_FILE="$RESULTS_FILE" \
  GATE_CATALOG_RAW_DIR="$CATALOG_RAW_DIR" \
  GATE_REPORT="$REPORT" \
  GATE_HEX_HOME="$HEX_HOME" \
  GATE_SERVER_URL="$SERVER_URL" \
  GATE_CMD_LIBRARY_SUPPORT="$CMD_LIBRARY_SUPPORT" \
  GATE_CMD_SUPPORT_LIVEVIEW="$CMD_SUPPORT_LIVEVIEW" \
  GATE_CMD_ENUMERATION="$CMD_ENUMERATION" \
  GATE_CMD_CONTRAST="$CMD_CONTRAST" \
  GATE_CMD_GLOSSARY="$CMD_GLOSSARY" \
  GATE_CMD_COPY_INVENTORY="$CMD_COPY_INVENTORY" \
  GATE_CMD_CSS_CONFORMANCE="$CMD_CSS_CONFORMANCE" \
  GATE_CMD_PREVIOUS_RELEASE="$CMD_PREVIOUS_RELEASE" \
  GATE_CMD_CATALOG_CAPTURE="$CMD_CATALOG_CAPTURE" \
  GATE_CMD_LIGHT_CATALOG_DIFF="$CMD_LIGHT_CATALOG_DIFF" \
  GATE_CMD_DARK_CATALOG_DIFF="$CMD_DARK_CATALOG_DIFF" \
  GATE_CMD_PLAYWRIGHT_PREFLIGHT="$CMD_PLAYWRIGHT_PREFLIGHT" \
  GATE_CMD_SERVER_START="$CMD_SERVER_START" \
  GATE_CMD_MODAL="$CMD_MODAL" \
  GATE_CMD_OVERFLOW="$CMD_OVERFLOW" \
  GATE_CMD_REFLOW="$CMD_REFLOW" \
  GATE_CMD_THEME_SWITCH="$CMD_THEME_SWITCH" \
  GATE_CMD_LIGHT_CHECKPOINTS="$CMD_LIGHT_CHECKPOINTS" \
  GATE_CMD_LIGHT_DESIGN_AXE="$CMD_LIGHT_DESIGN_AXE" \
  GATE_CMD_DARK_CHECKPOINTS="$CMD_DARK_CHECKPOINTS" \
  GATE_CMD_DARK_DESIGN_AXE="$CMD_DARK_DESIGN_AXE" \
  python3 - <<'PY'
import json
import os

check_names = [
    "library_support_tests",
    "support_empty_single_liveview",
    "enumeration_parity",
    "contrast",
    "glossary_lexicon",
    "copy_inventory_shrink",
    "css_conformance",
    "previous_release_css_compatibility",
    "normalized_catalog_capture",
    "normalized_light_catalog_diff",
    "normalized_dark_catalog_diff",
    "playwright_tooling",
    "example_server_ready",
    "browser_modal",
    "support_overflow_browser",
    "support_320px_200pct_browser",
    "theme_switch_dom_state",
    "light_axe",
    "dark_axe",
    "normalized_light_catalog_comparison",
    "normalized_dark_catalog_comparison",
]
results = {name: False for name in check_names}
with open(os.environ["GATE_RESULTS_FILE"], encoding="utf-8") as stream:
    for line in stream:
        name, value = line.rstrip("\n").split("\t", 1)
        if name not in results:
            raise SystemExit(f"unknown gate result: {name}")
        results[name] = value == "true"

commands = {
    "library_support_tests": os.environ["GATE_CMD_LIBRARY_SUPPORT"],
    "support_empty_single_liveview": os.environ["GATE_CMD_SUPPORT_LIVEVIEW"],
    "enumeration_parity": os.environ["GATE_CMD_ENUMERATION"],
    "contrast": os.environ["GATE_CMD_CONTRAST"],
    "glossary_lexicon": os.environ["GATE_CMD_GLOSSARY"],
    "copy_inventory_shrink": os.environ["GATE_CMD_COPY_INVENTORY"],
    "css_conformance": os.environ["GATE_CMD_CSS_CONFORMANCE"],
    "previous_release_css_compatibility": os.environ["GATE_CMD_PREVIOUS_RELEASE"],
    "normalized_catalog_capture": os.environ["GATE_CMD_CATALOG_CAPTURE"],
    "normalized_light_catalog_diff": os.environ["GATE_CMD_LIGHT_CATALOG_DIFF"],
    "normalized_dark_catalog_diff": os.environ["GATE_CMD_DARK_CATALOG_DIFF"],
    "playwright_tooling": os.environ["GATE_CMD_PLAYWRIGHT_PREFLIGHT"],
    "example_server_ready": os.environ["GATE_CMD_SERVER_START"],
    "browser_modal": os.environ["GATE_CMD_MODAL"],
    "support_overflow_browser": os.environ["GATE_CMD_OVERFLOW"],
    "support_320px_200pct_browser": os.environ["GATE_CMD_REFLOW"],
    "theme_switch_dom_state": os.environ["GATE_CMD_THEME_SWITCH"],
    "light_axe": "(" + os.environ["GATE_CMD_LIGHT_CHECKPOINTS"] + ") && (" + os.environ["GATE_CMD_LIGHT_DESIGN_AXE"] + ")",
    "dark_axe": "(" + os.environ["GATE_CMD_DARK_CHECKPOINTS"] + ") && (" + os.environ["GATE_CMD_DARK_DESIGN_AXE"] + ")",
    "normalized_light_catalog_comparison": "normalized_light_catalog_diff + theme-switch DOM state test + Light checkpoint and design-gallery axe checks",
    "normalized_dark_catalog_comparison": "normalized_dark_catalog_diff + theme-switch DOM state test + Dark checkpoint and design-gallery axe checks",
}

status = os.environ["GATE_STATUS"]
results["normalized_light_catalog_comparison"] = (
    results["normalized_light_catalog_comparison"]
    and results["normalized_light_catalog_diff"]
    and results["theme_switch_dom_state"]
    and results["light_axe"]
)
results["normalized_dark_catalog_comparison"] = (
    results["normalized_dark_catalog_comparison"]
    and results["normalized_dark_catalog_diff"]
    and results["theme_switch_dom_state"]
    and results["dark_axe"]
)
if status == "passed" and not all(results.values()):
    status = "failed"

failure = None
if os.environ.get("GATE_FAILURE_CHECK"):
    failure = {
        "check": os.environ["GATE_FAILURE_CHECK"],
        "exit_code": int(os.environ.get("GATE_FAILURE_EXIT") or "1"),
        "log": os.environ.get("GATE_FAILURE_LOG") or None,
    }
elif status != "passed":
    failure = {"check": None, "reason": "gate incomplete; no pass has been proven"}

report = {
    "phase": "262",
    "plan": "03",
    "gate": "4a",
    "status": status,
    "checks": results,
    "commands": commands,
    "browser_backstops": {
        "support_overflow_browser": {
            "fixture_id": "support-long-content",
            "test_title": "4a support long-content overflow",
            "test_target": "tests/admin-user-operations.spec.ts",
            "command": commands["support_overflow_browser"],
            "result": results["support_overflow_browser"],
        },
        "support_320px_200pct_browser": {
            "fixture_id": "support-long-content",
            "test_title": "4a support 320px/200% reflow",
            "test_target": "tests/admin-user-operations.spec.ts",
            "command": commands["support_320px_200pct_browser"],
            "result": results["support_320px_200pct_browser"],
        },
    },
    "theme_catalog_comparisons": {
        "html_contract": "The server-rendered admin catalog HTML is theme-invariant; Light and Dark run separate normalized before/after diff commands requiring all seven changed library support snapshots. The example mirror is unchanged and outside this slice; each theme diff is paired with the theme-switch DOM test and matching rendered-page axe checks.",
        "light": {
            "normalized_catalog_diff": results["normalized_light_catalog_diff"],
            "theme_switch_dom_state": results["theme_switch_dom_state"],
            "axe": results["light_axe"],
            "result": results["normalized_light_catalog_comparison"],
        },
        "dark": {
            "normalized_catalog_diff": results["normalized_dark_catalog_diff"],
            "theme_switch_dom_state": results["theme_switch_dom_state"],
            "axe": results["dark_axe"],
            "result": results["normalized_dark_catalog_comparison"],
        },
    },
    "catalog": {
        "before": "test/fixtures/brand/before",
        "after": "tmp/catalog-after",
        "raw_example_capture": os.environ["GATE_CATALOG_RAW_DIR"],
        "comparison_logs": {
            "light": os.path.join(os.environ["GATE_WORK_DIR"], "logs", "normalized_light_catalog_diff.log"),
            "dark": os.path.join(os.environ["GATE_WORK_DIR"], "logs", "normalized_dark_catalog_diff.log"),
        },
        "admin_html_theme_contract": "The server-rendered admin catalog HTML is theme-invariant; the Light and Dark normalized diffs independently require the seven changed library support snapshots. The example mirror is unchanged/outside this slice and is checked by its focused LiveView and enumeration tests.",
        "example_mirror_scope": "unchanged/outside Plan 03; example LiveView and enumeration tests run separately",
    },
    "failure": failure,
}

with open(os.environ["GATE_REPORT"], "w", encoding="utf-8") as stream:
    json.dump(report, stream, indent=2, sort_keys=True)
    stream.write("\n")
PY
}

GATE_STATUS="failed"
write_report

run_check() {
  local check="$1"
  local command="$2"
  shift 2
  local log="$LOG_DIR/${check}.log"
  echo "==> 4a gate: ${check}"
  if "$@" >"$log" 2>&1; then
    printf '%s\ttrue\n' "$check" >> "$RESULTS_FILE"
    write_report
    tail -n 40 "$log"
  else
    local exit_code=$?
    printf '%s\tfalse\n' "$check" >> "$RESULTS_FILE"
    GATE_FAILURE_CHECK="$check"
    GATE_FAILURE_EXIT="$exit_code"
    GATE_FAILURE_LOG="$log"
    write_report
    echo "4a gate failed at ${check} (exit ${exit_code}); report: ${REPORT}; log: ${log}" >&2
    tail -n 100 "$log" >&2
    exit "$exit_code"
  fi
}

run_shell_check() {
  local check="$1"
  local command="$2"
  run_check "$check" "$command" bash -o pipefail -c "$command"
}

start_example_server() {
  if curl --connect-timeout 1 --fail --silent --show-error "$SERVER_URL/" >/dev/null 2>&1; then
    echo "Refusing to use an already-running service at $SERVER_URL; its source cannot be proven by this gate." >&2
    return 1
  fi

  (
    cd "$ROOT/test/example"
    HEX_HOME="$HEX_HOME" MIX_ENV=dev PORT=4011 mix phx.server
  ) >"$SERVER_LOG" 2>&1 &
  SERVER_PID=$!

  for _attempt in $(seq 1 60); do
    if curl --connect-timeout 1 --fail --silent "$SERVER_URL/" >/dev/null 2>&1; then
      echo "Example app ready at $SERVER_URL/ (server PID $SERVER_PID; background log $SERVER_LOG)."
      return 0
    fi
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
      echo "Example app exited before readiness; log: $SERVER_LOG" >&2
      cat "$SERVER_LOG" >&2
      return 1
    fi
    sleep 1
  done

  echo "Example app did not become ready within 60 seconds; log: $SERVER_LOG" >&2
  cat "$SERVER_LOG" >&2
  return 1
}

run_shell_check library_support_tests "$CMD_LIBRARY_SUPPORT"
run_shell_check support_empty_single_liveview "$CMD_SUPPORT_LIVEVIEW"
run_shell_check enumeration_parity "$CMD_ENUMERATION"
run_shell_check contrast "$CMD_CONTRAST"
run_shell_check glossary_lexicon "$CMD_GLOSSARY"
run_shell_check copy_inventory_shrink "$CMD_COPY_INVENTORY"
run_shell_check css_conformance "$CMD_CSS_CONFORMANCE"
run_shell_check previous_release_css_compatibility "$CMD_PREVIOUS_RELEASE"
run_shell_check normalized_catalog_capture "$CMD_CATALOG_CAPTURE"

run_shell_check normalized_light_catalog_diff "$CMD_LIGHT_CATALOG_DIFF"
run_shell_check normalized_dark_catalog_diff "$CMD_DARK_CATALOG_DIFF"

run_shell_check playwright_tooling "$CMD_PLAYWRIGHT_PREFLIGHT"
run_check example_server_ready "$CMD_SERVER_START" start_example_server
run_shell_check browser_modal "$CMD_MODAL"
run_shell_check support_overflow_browser "$CMD_OVERFLOW"
run_shell_check support_320px_200pct_browser "$CMD_REFLOW"
run_shell_check theme_switch_dom_state "$CMD_THEME_SWITCH"
run_shell_check light_axe "($CMD_LIGHT_CHECKPOINTS) && ($CMD_LIGHT_DESIGN_AXE)" bash -o pipefail -c "($CMD_LIGHT_CHECKPOINTS) && ($CMD_LIGHT_DESIGN_AXE)"
run_shell_check dark_axe "($CMD_DARK_CHECKPOINTS) && ($CMD_DARK_DESIGN_AXE)" bash -o pipefail -c "($CMD_DARK_CHECKPOINTS) && ($CMD_DARK_DESIGN_AXE)"

# The server-rendered catalog is deliberately theme-invariant (the admin theme
# is client-side). These paired result fields require both the normalized HTML
# diff and the corresponding Light or Dark browser axe run to pass.
printf 'normalized_light_catalog_comparison\ttrue\n' >> "$RESULTS_FILE"
printf 'normalized_dark_catalog_comparison\ttrue\n' >> "$RESULTS_FILE"
GATE_STATUS="passed"
write_report
echo "4a gate passed; evidence: $REPORT"
