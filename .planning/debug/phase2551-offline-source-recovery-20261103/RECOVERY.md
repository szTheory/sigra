# Phase 255.1 offline source recovery

The frozen sources were retained. They were created in a separate local Git
object store; the fresh-policy preflight used that store, while the collector's
native-inventory validator read only the main checkout. Its error established
an object lookup mismatch, not lost source or failed CI.

## Exact inputs

- Control: `de7d80d67de7c9f57e0a67cff90b36620c384f01`.
- Candidate: `856c02bbd0dac83a29e388a0644d0fd51839b38f`.
- Frozen base: `970055abcf1ee4e8b5d8ebcf79de0eeecf4f223d`.
- Retained store and bundle: `.planning/execution/255.1/protected-delivery-scope/task14-clean-source-refreeze-20261101-retry04/objects.git`
  and its sibling `CLEAN-SOURCES.bundle`.
- Bundle SHA-256: `6445464d34bbc3afb9fd4016705369dbdea44cb465179ee8863e09367b72e3e7`.

`baseline.json` records the unchanged production native-inventory function
failing both roles with root-only lookup and passing all five owners per role
with only the exact retained store added to object lookup. It also records raw
commit SHA-1 verification, zero missing reachable objects, identical regenerated
archives, original archive commit headers, exact reviewed environment-helper
checks and hashes of the old proposal/approval/contract/ledger/verification.

The independent Git review found both exact commits in four retained scoped
stores, each with 24,899 reachable objects and none missing through its existing
root alternate. The retry04 connectivity checks passed. Linked worktrees share
the root object database and cannot fix its one-way lookup. The bounded clone
search was not a claim about the entire filesystem.

## Minimal repair and verification

The receipt-matching local bundle was imported into the root object database
with `git bundle unbundle`, then **new local** recovery refs were created for
the two exact commits. This copied existing objects; it did not reconstruct
commits, move an old branch, modify an approval, change orchestration code, or
publish anything. The new refs keep the recovered objects reachable for later
local work. `import-receipt.json` retains exact command results and ref read-back.

The sandbox's default root Git write was blocked. The local import then used a
narrow `require_escalated` request and automatic approval permitted it. The
parent's cancellation of root import arrived after the command had completed;
the parent was informed immediately. No further root Git writes, commits or
ref changes were made. Objects and new refs were retained rather than deleting
them after the cancellation.

Replay the read-only checks with:

```sh
python3 -B .planning/debug/phase2551-offline-source-recovery-20261103/verify.py --stage recovered
```

This command completed successfully and wrote `recovered.json` exclusively.
Root lookup passes both roles; exact source/archive identity and all captured
old proposal/approval/contract/ledger/verification hashes are unchanged. The
ten linked source-closure artifacts are unchanged. All 46,305 preexisting root
refs have the same names/values and exactly the two new recovery refs were
added. The script never invokes the preparation controller or a transport.
It deliberately refuses to overwrite existing evidence output.

## Hosted work remains stopped

This remedy repairs a local prerequisite only. The old invocation's stop,
deadline, counters, approval and no-retry rule remain unchanged. Plan 06 remains
halted, Plan 07 remains blocked, and no GSD execution command is authorized by
this local recovery. Exact cache restore/useful-work evidence is still missing;
candidate preparation and all twenty performance pairs are still unproved.

Any later hosted request needs a distinct, concrete preparation proposal using
these same exact recovered sources, not a rebuild or nearby replacement. Reuse
only the original registered control run/attempt/PR for read-only acquisition,
conditionally permit at most one candidate workload after that evidence passes,
and bind the actual current orchestration bytes, fresh deadlines, request/runner/
storage ceilings, immutable history and real consent in a new namespace. Keep
measurement, publication, merge, retries, cache seeding and release changes out
of that scope. Constructing such a proposal locally is separate from accepting
or executing it; this artifact grants no new hosted authority.

## Prevention

Run the collector's actual native-inventory preflight for **both roles with the
same default Git lookup** before offering any future source-bound proposal.
Top-level source checks against a separate store alone do not prove the collector
can read it. Keep exact frozen sources reachable through scoped local refs and
retain the original bundle/manifest/native proof. Do not convert this remedy
into another numbered repair plan or rewrite historical source inventories.
