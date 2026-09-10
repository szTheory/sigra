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
    run:{id:4001,url:"https://github.com/szTheory/sigra/actions/runs/4001",event:"pull_request",attempt:1,head_sha:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",conclusion:"success"},
    owner:{id:501,name:"Library tests shard",status:"completed",conclusion:"success",skipped:false},
    aggregate:{id:502,name:"Library tests",status:"completed",conclusion:"success",skipped:false},
    artifacts:[
      {id:601,name:"library-partitions-4001-1",file:"sigra-library-partitions.json",sha256:"1111111111111111111111111111111111111111111111111111111111111111"},
      {id:602,name:"library-partition-1-timings-4001-1",file:"sigra-library-1-timings.json",sha256:"2222222222222222222222222222222222222222222222222222222222222222"},
      {id:603,name:"library-partition-2-timings-4001-1",file:"sigra-library-2-timings.json",sha256:"3333333333333333333333333333333333333333333333333333333333333333"}
    ],
    partitions:{execution_mode:"sequential",ordinary_universe_count:20,manifest_counts:[10,10],test_counts:[40,42],durations_ms:[12000,18000],conclusions:["success","success"],exit_statuses:[0,0]},
    protected_invariants:{library_tests_aggregate_sha256:"04308ef8fb56acc65c5730630e1fd3e926da6804068db07f6f15636c2a0890cb",sole_pr_owner:"MIX_ENV=test mix ci",fast_01_verifier:"source_complete_offline_attestation_verified",gate_05_verifier:"offline_attestation_verified"},
    commands:{rate_limit:"gh api rate_limit --jq '\'' .resources.core | {remaining,reset}'\''"},
    supersession:{plan04_status:"empirically superseded (failed evidence retained)",forbidden_predicates:["install_not_dominant","ordinary-vs-scaffold comparable"]}
  }' | sed "s/' \.resources/'.resources/" >"$PR"

  jq -n '{
    schema_version:"sigra.library-install-golden-evidence/v1",
    repository:"szTheory/sigra",
    run:{id:4002,url:"https://github.com/szTheory/sigra/actions/runs/4002",event:"workflow_dispatch",attempt:1,head_sha:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",conclusion:"failure"},
    job:{id:503,name:"Library install golden (non-PR)",status:"completed",conclusion:"success",skipped:false},
    artifacts:[
      {id:604,name:"library-install-golden-4002-1",file:"sigra-library-install-golden.json",sha256:"4444444444444444444444444444444444444444444444444444444444444444"},
      {id:605,name:"library-install-diagnostics-4002-1",file:"sigra-install-golden-diagnostics.json",sha256:"5555555555555555555555555555555555555555555555555555555555555555"}
    ],
    receivers:{paths:["test/a_test.exs","test/b_test.exs","test/c_test.exs","test/d_test.exs","test/e_test.exs","test/f_test.exs"],count:6,duration_ms:57389,exit_status:0,conclusion:"success",prepared_fixture:true,worker_ceiling:2},
    diagnostics:{schema_version:"sigra.install-fixture-diagnostics/v1",variant_count:6,worker_count:2,failed_paths:[],raw_install_duration_ms:57389},
    protected_invariants:{non_pr_events:["schedule","workflow_dispatch"],pr_execution:false,hard_signal:true},
    commands:{rate_limit:"gh api rate_limit --jq '\''.resources.core | {remaining,reset}'\''"},
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
  'pr|.partitions.manifest_counts=[19,1]|partition coverage' \
  'pr|.partitions.durations_ms=[1000,2001]|partition ratio' \
  'pr|.partitions.exit_statuses=[0,1]|partition outcome' \
  'pr|.protected_invariants.library_tests_aggregate_sha256="bad"|protected aggregate' \
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
