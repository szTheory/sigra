#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT/scripts/ci/verify-library-routing-evidence.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PR="$TMP/pr.json"
SCAFFOLD="$TMP/scaffold.json"

write_valid() {
  jq -n '{
    schema_version:"sigra.library-partitions-evidence/v1",
    repository:"szTheory/sigra",
    pr:{number:234},
    run:{id:4005,url:"https://github.com/szTheory/sigra/actions/runs/4005",event:"pull_request",attempt:1,head_sha:"cccccccccccccccccccccccccccccccccccccccc",conclusion:"success"},
    owner:{id:501,name:"Library tests shard",status:"completed",conclusion:"success",skipped:false},
    aggregate:{id:502,name:"Library tests",status:"completed",conclusion:"success",skipped:false},
    artifacts:[
      {id:601,name:"library-partitions-4005-1",file:"sigra-library-partitions.json",sha256:"1111111111111111111111111111111111111111111111111111111111111111"},
      {id:602,name:"library-partition-1-timings-4005-1",file:"sigra-library-1-timings.json",sha256:"2222222222222222222222222222222222222222222222222222222222222222"},
      {id:603,name:"library-partition-2-timings-4005-1",file:"sigra-library-2-timings.json",sha256:"3333333333333333333333333333333333333333333333333333333333333333"}
    ],
    partitions:{execution_mode:"sequential",ordinary_universe_count:20,manifest_counts:[10,10],test_counts:[40,42],durations_ms:[12000,18000],conclusions:["success","success"],exit_statuses:[0,0]},
    protected_invariants:{library_tests_aggregate_sha256:"04308ef8fb56acc65c5730630e1fd3e926da6804068db07f6f15636c2a0890cb",sole_pr_owner:"MIX_ENV=test mix ci",fast_01_verifier:"source_complete_offline_attestation_verified",gate_05_verifier:"offline_attestation_verified"},
    commands:{rate_limit:"gh api rate_limit --jq '\''.resources.core | {remaining,reset}'\''",watch:"gh run watch 4005 --repo szTheory/sigra --compact --interval 60 --exit-status",summary:"gh run view 4005 --repo szTheory/sigra --json databaseId,event,headSha,conclusion,attempt,url,jobs",artifacts:["gh run download 4005 --repo szTheory/sigra --name library-partitions-4005-1","gh run download 4005 --repo szTheory/sigra --name library-partition-1-timings-4005-1","gh run download 4005 --repo szTheory/sigra --name library-partition-2-timings-4005-1"]},
    supersession:{
      plan04_status:"empirically superseded (failed evidence retained)",
      forbidden_predicates:["install_not_dominant","ordinary-vs-scaffold comparable"],
      plan10_run_ids:[34466384009,34466384470,34467186749,34467189602,34468109536,34468110161],
      recovery_attempts:[
        {candidate:1,implementation_sha:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",tree_id:"9999999999999999999999999999999999999999",pr_run:{id:4001,attempt:1},dispatch_run:{id:4002,attempt:1},classification:"external_transient",diagnostic_refs:["https://github.com/szTheory/sigra/actions/runs/4001"]},
        {candidate:2,implementation_sha:"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",tree_id:"9999999999999999999999999999999999999999",pr_run:{id:4003,attempt:1},dispatch_run:{id:4004,attempt:1},classification:"external_transient",diagnostic_refs:["https://github.com/szTheory/sigra/actions/runs/4004"]},
        {candidate:3,implementation_sha:"cccccccccccccccccccccccccccccccccccccccc",tree_id:"9999999999999999999999999999999999999999",pr_run:{id:4005,attempt:1},dispatch_run:{id:4006,attempt:1},classification:"admitted",diagnostic_refs:[]}
      ]
    }
  }' >"$PR"

  jq -n '{
    schema_version:"sigra.library-install-golden-evidence/v1",
    repository:"szTheory/sigra",
    run:{id:4006,url:"https://github.com/szTheory/sigra/actions/runs/4006",event:"workflow_dispatch",attempt:1,head_sha:"cccccccccccccccccccccccccccccccccccccccc",conclusion:"failure"},
    job:{id:503,name:"Library install golden (non-PR)",status:"completed",conclusion:"success",skipped:false},
    artifacts:[
      {id:604,name:"library-install-golden-4006-1",file:"sigra-library-install-golden.json",sha256:"4444444444444444444444444444444444444444444444444444444444444444"},
      {id:605,name:"library-install-diagnostics-4006-1",file:"sigra-install-golden-diagnostics.json",sha256:"5555555555555555555555555555555555555555555555555555555555555555"}
    ],
    receivers:{paths:["test/sigra/install/features/passkeys_js_test.exs","test/sigra/install/generator_passkeys_opt_out_test.exs","test/sigra/install/golden_diff_test.exs","test/sigra/install/idempotency_test.exs","test/sigra/install/vault_promotion_test.exs","test/upgrade_test.exs"],count:6,duration_ms:57389,exit_status:0,conclusion:"success",prepared_fixture:true,worker_ceiling:2},
    diagnostics:{schema_version:"sigra.install-fixture-diagnostics/v1",variant_count:6,worker_count:2,failed_paths:[],raw_install_duration_ms:57389},
    protected_invariants:{non_pr_events:["schedule","workflow_dispatch"],pr_execution:false,hard_signal:true},
    commands:{rate_limit:"gh api rate_limit --jq '\''.resources.core | {remaining,reset}'\''",watch:"gh run watch 4006 --repo szTheory/sigra --compact --interval 60 --exit-status",summary:"gh run view 4006 --repo szTheory/sigra --json databaseId,event,headSha,conclusion,attempt,url,jobs",artifacts:["gh run download 4006 --repo szTheory/sigra --name library-install-golden-4006-1","gh run download 4006 --repo szTheory/sigra --name library-install-diagnostics-4006-1"]},
    supersession:{failed_run_id:34435818106,ordinary_duration_ms:28671,install_duration_ms:79614,safe_optimization_commits:["1fa788fc","488f4fa1"],bounded_clean_local_range_ms:[56000,78000],final_hard_stop_ms:57389,status:"failed evidence retained"}
  }' >"$SCAFFOLD"
}

expect_pass() { "$VERIFY" "$1" "$2" >/dev/null; }
expect_fail() {
  if "$VERIFY" "$1" "$2" >/dev/null 2>&1; then
    echo "verify-library-routing-evidence.test: expected rejection: $3" >&2
    exit 1
  fi
}

mutate() {
  local source="$1" expression="$2" output="$3"
  jq "$expression" "$source" >"$output"
}

write_valid
expect_pass "$PR" "$SCAFFOLD"

for spec in \
  'pr|.repository="elsewhere/repo"|repository' \
  'pr|.pr.number=0|PR number' \
  'pr|.run.event="push"|PR event' \
  'pr|.run.attempt=2|PR attempt' \
  'pr|.run.head_sha="bad"|PR SHA' \
  'pr|.owner.conclusion="failure"|owner conclusion' \
  'pr|.aggregate.skipped=true|aggregate skipped' \
  'pr|.artifacts[0].id=.artifacts[1].id|artifact ID uniqueness' \
  'pr|.artifacts[0].name="wrong"|artifact name' \
  'pr|.artifacts[0].sha256="bad"|artifact digest' \
  'pr|.partitions.manifest_counts=[19,2]|partition coverage' \
  'pr|.partitions.durations_ms=[1000,2001]|partition ratio' \
  'pr|.partitions.exit_statuses=[0,1]|partition outcome' \
  'pr|.protected_invariants.library_tests_aggregate_sha256="bad"|protected aggregate' \
  'pr|.supersession.plan10_run_ids[0]=1|history substitution' \
  'pr|.supersession.plan10_run_ids|=reverse|history reorder' \
  'pr|.supersession.recovery_attempts=[]|missing recovery history' \
  'pr|.supersession.recovery_attempts[1].classification="admitted"|selective reroll' \
  'pr|.supersession.recovery_attempts[0].classification="deterministic_failure"|deterministic-failure advancement' \
  'pr|.supersession.recovery_attempts[0].diagnostic_refs=[]|missing transient diagnosis' \
  'pr|.supersession.recovery_attempts[1].tree_id="8888888888888888888888888888888888888888"|candidate tree drift' \
  'pr|.supersession.recovery_attempts[1].candidate=3|candidate reorder' \
  'pr|.supersession.recovery_attempts[0].pr_run.attempt=2|candidate rerun' \
  'pr|.supersession.recovery_attempts[2].dispatch_run.id=4005|pair run duplication' \
  'pr|.supersession.recovery_attempts[2].implementation_sha="dddddddddddddddddddddddddddddddddddddddd"|final cross-SHA' \
  'pr|.supersession.recovery_attempts += [.supersession.recovery_attempts[-1]]|over budget' \
  'pr|.supersession.recovery_attempts[0].waived=true|waiver' \
  'pr|.install_not_dominant=true|retired predicate' \
  'pr|.unexpected=true|extra key' \
  'scaffold|.run.event="schedule"|dispatch event' \
  'scaffold|.run.attempt=2|dispatch attempt' \
  'scaffold|.run.head_sha="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"|same implementation SHA' \
  'scaffold|.job.status="queued"|job status' \
  'scaffold|.job.conclusion="failure"|job conclusion' \
  'scaffold|.job.skipped=true|job skipped' \
  'scaffold|.artifacts[1].name="wrong"|diagnostic artifact name' \
  'scaffold|.receivers.count=5|receiver count' \
  'scaffold|.receivers.paths[5]=.receivers.paths[0]|receiver uniqueness' \
  'scaffold|.diagnostics.worker_count=3|worker ceiling' \
  'scaffold|.supersession.failed_run_id=1|failed-history run' \
  'scaffold|.supersession.safe_optimization_commits=[]|safe commits' \
  'scaffold|.comparable=true|retired predicate' \
  'scaffold|.unexpected=true|extra key'; do
  IFS='|' read -r which expression label <<<"$spec"
  write_valid
  target="$TMP/mutated.json"
  if [[ "$which" == pr ]]; then
    mutate "$PR" "$expression" "$target"
    expect_fail "$target" "$SCAFFOLD" "$label"
  else
    mutate "$SCAFFOLD" "$expression" "$target"
    expect_fail "$PR" "$target" "$label"
  fi
done

printf 'verify-library-routing-evidence.test: PASS\n'
