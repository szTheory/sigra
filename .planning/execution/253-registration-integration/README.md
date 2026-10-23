# Prepared integration check — not executed

The registration fix `a87664733` passed all nine approved targeted runs. The next missing execution is the five ordinary PR browser selections on that fixed source. The previous normal PR343 run predates the fix; its required-check proof remains valid, but it cannot supply these post-fix browser results.

| Existing group | Frozen tests |
| --- | ---: |
| Admin behavior | 43 |
| Admin checkpoints | 3 |
| Design gallery PR behavior | 42 |
| Non-admin smoke | 16 |
| Demo showcase | 4 |
| Total | 108 |

Selections are extracted from the candidate's actual `ci.yml` selection/execution pairs. Design gallery includes its three authentication setup tests. All selected expected outcomes are passing. Native list-only collection ran in a network-isolated container and started no browser, app or database. That container was removed. An initial import-path preparation error and its exact scripts/log are retained under `stopped-collection-1`; it stopped before collection.

`proposal.json` freezes the source, existing candidate image, PostgreSQL15.19 digest, five commands, complete native inventory, warmup paths, runner files and limits. The image's original source manifest is checked inside every invocation. No source or browser dependency change is proposed.

The proposed execution runs each group once in a fresh app/PostgreSQL pair, with a new browser context per normal test. It keeps serial workers, zero retries and normal test timeouts. It adds first-failure stopping and retains failure traces. Total setup-through-cleanup limit:3600seconds; each group at most1800seconds. Groups run sequentially with private container-only networking and no published host ports. No image downloads, external network, GitHub requests, CI launches or old allowance reuse. A total timeout may leave later groups unrun; it never grants extra time.

The 13 runner tests use fake Docker calls and native-report fixtures. They verify failure stopping/cleanup, fresh database identities, missing/changed tests, skips/retries, source sealing and approval boundaries. The real unapproved `--run` command refuses before reservation or container allocation. Forty-three existing report/control unit tests pass. The affected configuration checks pass with seeds101/202/303 in separate local processes (three tests each). These are development checks, not browser-control acceptance.

The only non-planning differences from the previously verified product `5e13621e5` are `test/example/config/dev.exs` and its new configuration regression test. The normal library implementation, test configuration and gate inputs are unchanged. The added test directly covers both CI flag values, ordinary development and preservation of other configuration. Existing library/gate evidence is retained; this bundle does not claim a new `mix ci` run or hosted PR required-check result.

## Execution boundary

```sh
python3 .planning/execution/253-registration-integration/validate.py --preflight
```

This read-only command is permitted now. The following command requires a new explicit approval of this proposal, recorded against its SHA256 and exact source:

```sh
python3 .planning/execution/253-registration-integration/validate.py --run
```

Approval scope: `five-fresh-local-linux-integration-groups`. The driver requires `approval.json` and reserves the allowance exactly once in `reservation.json` before allocating anything. Never remove a reservation to retry. The prior nine-run approval is consumed and cannot authorize this command. The user's original scope was offline-only; continuing debug does not implicitly approve browsers or CI.

## Still needed afterward

Passing all five groups supplies the missing ordinary PR browser integration coverage. CIREL-01 still needs review/completion of the delayed/missing readiness, broken-wait, collision/fresh-state and failure/pass trace controls, followed by canonical whole-phase verification. The original Plan16 and control-recovery receipts both remain halted; unit tests cannot replace them. Their spent allowances are unchanged, and this proposal does not authorize those browser controls. CIREL-02 remains complete.

These are Linux x64-emulated local runs on an ARM Mac using the documented Erlang workaround and fresh seeded databases. They cannot establish the original hosted module schedule or database snapshot.

Next GSD command after an explicit decision approving this exact bundle: `$gsd-debug continue phase253-registration-timeout`. Phase254 has not started; its readiness remains pending without context/research/plans. After actual253 completion, recheck readiness before `$gsd-discuss-phase 254`.
