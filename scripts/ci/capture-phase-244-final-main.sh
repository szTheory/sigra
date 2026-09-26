#!/usr/bin/env bash
set -euo pipefail
REPO=szTheory/sigra
SCHEMA=sigra.phase-244-final-main/1
fail(){ echo "capture-phase-244-final-main: FAIL: $*" >&2; exit 1; }
valid(){ jq -e --arg s "$2" --arg v "$SCHEMA" '
def j: (.id|type)=="number" and (.run_id|type)=="number" and .status=="completed" and .conclusion=="success";
def st($n): .step.name==$n and (.step.number|type)=="number" and .step.status=="completed" and .step.conclusion=="success";
.schema_version==$v and .main_sha_before==$s and .main_sha_after==$s and .run.head_sha==$s and .run.status=="completed" and .run.conclusion=="success" and
((.run.event=="workflow_dispatch" and .run.head_branch=="main" and .run.path==".github/workflows/ci.yml" and .dispatch.route=="phase_244_final_main" and .dispatch.inputs=={phase_244_final_main:true,recapture_branch:"",force_fail_probe:false,force_rot_probe:false}) or (.run.event=="push" and .run.head_branch=="main")) and
(.ci_gate|j) and .ci_gate.name=="ci-gate" and
(.example_playwright_shards.admin_behavior|j) and .example_playwright_shards.admin_behavior.name=="Example Playwright shard (admin_behavior)" and (.example_playwright_shards.admin_behavior|st("Run admin behavior browser truth")) and
(.example_playwright_shards.admin_checkpoints|j) and .example_playwright_shards.admin_checkpoints.name=="Example Playwright shard (admin_checkpoints)" and (.example_playwright_shards.admin_checkpoints|st("Run admin checkpoints")) and
(.example_playwright_shards.design_gallery|j) and .example_playwright_shards.design_gallery.name=="Example Playwright shard (design_gallery)" and (.example_playwright_shards.design_gallery|st("Run design gallery behavior and snapshots")) and
(.example_playwright_shards.non_admin_smoke|j) and .example_playwright_shards.non_admin_smoke.name=="Example Playwright shard (non_admin_smoke)" and (.example_playwright_shards.non_admin_smoke|st("Run non-admin example browser smoke")) and
(.example_playwright_shards.demo_showcase|j) and .example_playwright_shards.demo_showcase.name=="Example Playwright shard (demo_showcase)" and (.example_playwright_shards.demo_showcase|st("Run demo showcase")) and
(.example_playwright_smoke|j) and .example_playwright_smoke.name=="Example Playwright smoke (full lifecycle)" and (.example_playwright_smoke|st("Aggregate every Playwright shard result")) and
(.generated_admin_playwright_smoke|j) and .generated_admin_playwright_smoke.name=="Generated admin Playwright smoke" and (.generated_admin_playwright_smoke|st("Run generated admin acceptance smoke")) and
([.ci_gate.id,.example_playwright_shards[].id,.example_playwright_smoke.id,.generated_admin_playwright_smoke.id]|unique|length)==8 and
([.ci_gate.run_id,.example_playwright_shards[].run_id,.example_playwright_smoke.run_id,.generated_admin_playwright_smoke.run_id]|unique|length)==1 and .ci_gate.run_id==.run.id
' "$1" >/dev/null; }
mode=${1:-}; shift || true
if [[ $mode == verify ]]; then
 while (($#)); do case $1 in --receipt) r=$2;shift 2;; --main-sha) s=$2;shift 2;; *) fail "unknown_argument_$1";;esac;done
 [[ -f ${r:-} && ${s:-} =~ ^[0-9a-f]{40}$ ]] || fail verify_arguments_invalid
 valid "$r" "$s" || fail receipt_contract_invalid
 echo "capture-phase-244-final-main: PASS: receipt contract"; exit 0
fi
[[ $mode == capture ]] || fail usage
while (($#)); do case $1 in --run-id) id=$2;shift 2;; --route) route=$2;shift 2;; --not-before) cutoff=$2;shift 2;; --output) out=$2;shift 2;; *) fail "unknown_argument_$1";;esac;done
[[ ${id:-} =~ ^[0-9]+$ && ${route:-} == phase_244_final_main && -n ${cutoff:-} && -n ${out:-} ]] || fail capture_arguments_invalid
[[ -d $(dirname "$out") ]] || fail output_directory_missing
command -v gh >/dev/null || fail gh_not_found; command -v jq >/dev/null || fail jq_not_found
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT INT TERM
api(){ if ! gh api "$2" >"$t/$1.out" 2>"$t/$1.err"; then msg=$(tr '\n' ' ' <"$t/$1.err"); [[ $msg =~ 403|429 ]] && fail "github_rate_limited_stop: $msg"; fail "github_api_request_failed_$1: $msg"; fi; cat "$t/$1.out"; }
rate=$(api rate_limit rate_limit); rem=$(jq -r '.resources.core.remaining // empty' <<<"$rate"); reset=$(jq -r '.resources.core.reset // empty' <<<"$rate")
[[ $rem =~ ^[0-9]+$ && $reset =~ ^[0-9]+$ ]] || fail rate_limit_preflight_malformed; ((rem>250)) || fail "rate_limit_too_low: remaining=$rem reset=$reset"
getmain(){ x=$(api ref "repos/$REPO/git/ref/heads/main"); jq -er '.object.sha|select(test("^[0-9a-f]{40}$"))' <<<"$x" || fail main_ref_malformed; }
before=$(getmain); run=$(api run "repos/$REPO/actions/runs/$id"); jq -e 'type=="object" and (.id|type)=="number"' <<<"$run" >/dev/null || fail run_payload_malformed
[[ $(jq -r .id <<<"$run") == "$id" && $(jq -r .head_sha <<<"$run") == "$before" ]] || fail run_identity_or_sha_mismatch
[[ $(jq -r .status <<<"$run") == completed && $(jq -r .conclusion <<<"$run") == success && $(jq -r .head_branch <<<"$run") == main ]] || fail run_not_successful_main
event=$(jq -r .event <<<"$run"); created=$(jq -r '.created_at // ""' <<<"$run"); [[ -n $created && $created > $cutoff ]] || fail run_predates_disposition
if [[ $event == workflow_dispatch ]]; then inputs=$(jq -c '.inputs//{}' <<<"$run"); [[ $(jq -r .path <<<"$run") == .github/workflows/ci.yml && $(jq -r '.phase_244_final_main//false' <<<"$inputs") == true && $(jq -r '.recapture_branch//""' <<<"$inputs") == "" && $(jq -r '.force_fail_probe//false' <<<"$inputs") == false && $(jq -r '.force_rot_probe//false' <<<"$inputs") == false ]] || fail dispatch_inputs_invalid; elif [[ $event != push ]]; then fail run_event_invalid; fi
echo "$run" >"$t/run.json"; : >"$t/pages"; p=1
while :; do x=$(api p$p "repos/$REPO/actions/runs/$id/jobs?per_page=100&page=$p"); jq -e 'type=="object" and (.total_count|type)=="number" and (.jobs|type)=="array"' <<<"$x" >/dev/null || fail "jobs_page_malformed_$p"; jq -cn --argjson p $p --argjson b "$x" '{page:$p,body:$b}' >>"$t/pages"; n=$(jq '.jobs|length' <<<"$x"); ((n==0)) && break; ((p<10000)) || fail pagination_bound_reached; ((p+=1)); done
jq -s -e 'length>=2 and [.[].page]==[range(1;length+1)] and ([.[].body.total_count]|unique|length)==1 and (.[-1].body.jobs|length)==0 and all(.[0:-1][];(.body.jobs|length)>0)' "$t/pages" >/dev/null || fail pagination_incomplete
total=$(jq -s '.[0].body.total_count' "$t/pages"); jq -s '[.[].body.jobs[]]' "$t/pages" >"$t/jobs"; [[ $(jq length "$t/jobs") == "$total" ]] || fail jobs_total_count_disagreement
jq -e --argjson id "$id" 'all(.[];.run_id==$id and (.id|type)=="number" and .status=="completed" and .conclusion=="success" and (.steps|type)=="array") and ([.[].id]|unique|length)==length' "$t/jobs" >/dev/null || fail jobs_invalid
job(){ jq --arg n "$1" '[.[]|select(.name==$n)]' "$t/jobs" >"$t/$2"; [[ $(jq length "$t/$2") == 1 ]] || fail "job_missing_or_duplicate_$2"; jq -e '.[0].status=="completed" and .[0].conclusion=="success"' "$t/$2" >/dev/null || fail "job_not_success_$2"; }
step(){ jq --arg n "$2" '.[0].steps|[.[]|select(.name==$n)]' "$1" >"$t/$3"; [[ $(jq length "$t/$3") == 1 ]] || fail "step_missing_or_duplicate_$3"; jq -e '.[0].status=="completed" and .[0].conclusion=="success" and (.[0].number|type)=="number"' "$t/$3" >/dev/null || fail "step_not_success_$3"; }
record(){ if [[ -n ${2:-} ]]; then jq --slurpfile s "$2" '.[0]|{id,name,run_id,html_url,status,conclusion,step:($s[0][0]|{name,number,status,conclusion})}' "$1"; else jq '.[0]|{id,name,run_id,html_url,status,conclusion}' "$1"; fi; }
job ci-gate gate
job 'Example Playwright shard (admin_behavior)' admin; step "$t/admin" 'Run admin behavior browser truth' adminstep
job 'Example Playwright shard (admin_checkpoints)' checkpoints; step "$t/checkpoints" 'Run admin checkpoints' checkpointstep
job 'Example Playwright shard (design_gallery)' design; step "$t/design" 'Run design gallery behavior and snapshots' designstep
job 'Example Playwright shard (non_admin_smoke)' nonadmin; step "$t/nonadmin" 'Run non-admin example browser smoke' nonadminstep
job 'Example Playwright shard (demo_showcase)' demo; step "$t/demo" 'Run demo showcase' demostep
job 'Example Playwright smoke (full lifecycle)' smoke; step "$t/smoke" 'Aggregate every Playwright shard result' smokestep
job 'Generated admin Playwright smoke' generated; step "$t/generated" 'Run generated admin acceptance smoke' generatedstep
after=$(getmain); [[ $after == "$before" ]] || fail main_sha_changed_during_collection
jq -n -S --arg schema "$SCHEMA" --arg before "$before" --arg after "$after" --slurpfile run "$t/run.json" --argjson gate "$(record "$t/gate")" --argjson admin "$(record "$t/admin" "$t/adminstep")" --argjson check "$(record "$t/checkpoints" "$t/checkpointstep")" --argjson design "$(record "$t/design" "$t/designstep")" --argjson nonadmin "$(record "$t/nonadmin" "$t/nonadminstep")" --argjson demo "$(record "$t/demo" "$t/demostep")" --argjson smoke "$(record "$t/smoke" "$t/smokestep")" --argjson generated "$(record "$t/generated" "$t/generatedstep")" --argjson rem "$rem" --argjson reset "$reset" '{schema_version:$schema,main_sha_before:$before,main_sha_after:$after,dispatch:{route:"phase_244_final_main",inputs:{phase_244_final_main:true,recapture_branch:"",force_fail_probe:false,force_rot_probe:false}},run:($run[0]|{id,html_url,head_sha,head_branch,event,status,conclusion,created_at,path,inputs}),ci_gate:$gate,example_playwright_shards:{admin_behavior:$admin,admin_checkpoints:$check,design_gallery:$design,non_admin_smoke:$nonadmin,demo_showcase:$demo},example_playwright_smoke:$smoke,generated_admin_playwright_smoke:$generated,rate_limit:{core_remaining:$rem,core_reset:$reset}}' >"$t/receipt" || fail receipt_serialization_failed
valid "$t/receipt" "$before" || fail receipt_self_validation_failed
tmp=$(mktemp "$(dirname "$out")/.phase244.XXXXXX"); cp "$t/receipt" "$tmp"; mv -f "$tmp" "$out"
echo "capture-phase-244-final-main: PASS: run $id at $before"
