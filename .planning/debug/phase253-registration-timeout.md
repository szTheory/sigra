---
status: diagnosed
trigger: "Phase 253 registration timeout: inspect the original CI failure and Linux replay logs; offline only, no browser or CI run"
created: 2026-10-22
updated: 2026-10-22
goal: offline_diagnosis_only
---

## Symptoms

- Expected: the original admin registration test saves its account, submits the login POST and leaves `/users/register`.
- Actual: original CI run38205503164 attempt1, source4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97, test161 (`admin-eval-dark / board-mg-9/populated`) timed out. The original192-test job continued afterward. Both saved161-test Mac and Linux replays passed.
- Error: `page.waitForURL: Timeout 10000ms exceeded.` Registration request,response and request-failure fields were all null. The archive redactor removed the rest of pageState after finalUrl.
- Timeline: original failure2026-10-12; Linux replay2026-10-22 passed all161 cases in1622.2seconds with no retries/skips.
- Reproduction: the original test order is authenticated in253-registration-order-recovery/recovered-order.json. The replay command is consumed and must not be run again. No browser,app,container,CI or external-network execution is part of this investigation.
- Source of symptoms: the user's current request and already retained original CI/replay records; no new user interview is needed.

## Current Focus

bug_class: intermittent server module-availability failure; immediate failure established,upstream mechanism unconfirmed
hypothesis: development protocol reloading may make Ecto.Queryable unavailable during a LiveView save; source supports this possibility but neither local probe reproduced it.
test: next independent check must trace the actual Phoenix reloader's module deletion,code-path changes and OTP load result alongside query calls. The previous raw purge probes omitted those observations.
expecting: a captured failed load would distinguish reloader overlap from missing/corrupt on-disk code or another module loader failure. Another uninstrumented passing replay would not.
next_action: prepare a traced,isolated Phoenix reloader unit experiment;keep it offline with no app listener,database,browser or CI. Do not repeat the uninstrumented bulk probes or apply a speculative timeout/retry fix.

## Evidence

- Original archive SHA256:95334957b5b05494028ec72be5c95ee00e9ed4328e53fa78b35264c482a5af30.
- Original failed-job.log SHA256:9eb5c33dd861f310f06d3ab5f559c14d05952d09d6203faf668ad478b76c3a0c;34986 lines,including192 `HANDLE EVENT "save"` entries.
- Linux result: `.planning/execution/253-registration-linux/RESULT.json`; native report161passes,0skips/retries; original test161passed. A green replay does not prove a fix.
- Initial Git capture was clean at855897c1c. Historical files and spent allowances remain unchanged.
- The sole GenServer termination follows save161 at original log lines29588–29608. It raises `UndefinedFunctionError` for `Ecto.Queryable.to_query/1`,before any user insert. The stack passes through email uniqueness validation and RegistrationLive.handle_event/3.
- Save160 and162 each have one user insert and one login POST;save161 has neither. The failed generated address encodes dark registration sequence33 and a creation time05:15:36.572UTC,between native test160 ending05:15:36.536 and test161 failing05:15:48.233. This links the crash independently of ordinal counting.
- Locked Phoenix1.8.5 CodeReloader.Server calls purge_modules(consolidation_path) when protocol consolidation is enabled,including after a no-op compile. purge_module runs :code.purge then :code.delete. The original development endpoint enables code_reloader; LiveView save-event handling does not use the HTTP reloader lock.
- Read-only `analyze.py` authenticated both original and Linux logs and checked all registration flows. Original:191successful inserts/POSTs and one crash at161. Linux:161successful inserts/POSTs,including161,and no Queryable exception. See `phase253-registration-timeout/evidence.json`.
- `purge_probe.exs`:2000control calls and40000concurrent query calls passed;all5processes exited normally. `loaded_purge_probe.exs`:2000control calls and400000concurrent schema query calls passed with5000reload/purge cycles;all5processes exited normally. These are local module experiments,not browser runs or CI acceptance. Both actual logs and source scripts are retained.
- Original application logs were flushed later by the failure-dump step. Their05:19:23prefix is the dump time,not a reliable time for the crash itself. The generated address embeds05:15:36.572UTC,inside the native test161 interval.

## Eliminated

- A missed submit click or browser required-field validation as the immediate cause:the original server received save161 with the generated account and then raised the recorded exception.
- A failed login response as the immediate cause:the crash occurred before the user insert and before any login POST.
- The board screenshot/rendering as the immediate cause:registration failed before the test could capture that board.
- A permanently absent Ecto dependency/API:the same server successfully registered160and162,and the locked Ecto3.13.5 exports to_query/1. The observed failure was transient.
- Not eliminated:development reloader overlap,code-path/file availability or other module loading failure. The two passing probes are insufficient to select among them.

## Resolution

root_cause: confirmed immediate failure — RegistrationLive.save crashed in email uniqueness validation because Ecto.Queryable.to_query/1 was unavailable;the account was not inserted and trigger_submit was never set.
upstream_cause: why Ecto.Queryable became unavailable remains unconfirmed;the original log does not include module lifecycle/load tracing.
fix: none
verification: authenticated original log plus independently matched account sequence/time;Linux contrast verified;two local probes passed without reproducing the loader error;no browser or CI execution.
files_changed: debug records and current handoff/state only;no product or workflow change.
phase_status: CIREL-01 and Phase253 remain incomplete;CIREL-02 unchanged.
