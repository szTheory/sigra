---
phase: quick-260528-nwa
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - guides/recipes/companion-libs/threadline.md
  - guides/recipes/companion-libs/accrue.md
  - guides/flows/audit-logging.md
autonomous: true
requirements: [RC-01, CR-01]
must_haves:
  truths:
    - "An adopter who copy-pastes the threadline.md forwarders block gets a working DB-based forwarder (no silent forward errors)"
    - "The threadline.md forwarders block matches the example app's key set (module/id/dispatch/repo)"
    - "Every Sigra.Audit.log call in the docs uses the real log/2 (action, opts) signature"
    - "No HTTP/network framing remains for the DB-based Threadline 0.5+ forwarder"
    - "mix docs --warnings-as-errors exits 0"
  artifacts:
    - path: "guides/recipes/companion-libs/threadline.md"
      provides: "Correct forwarders config (repo:) + DB-based failure-mode framing"
      contains: "repo: MyApp.Repo"
    - path: "guides/recipes/companion-libs/accrue.md"
      provides: "log_audit/2 example using real Sigra.Audit.log/2 signature"
      contains: "Sigra.Audit.log("
    - path: "guides/flows/audit-logging.md"
      provides: "Custom-event example using real Sigra.Audit.log/2 signature"
      contains: "Sigra.Audit.log(\"billing.subscription.upgraded\""
  key_links:
    - from: "guides/recipes/companion-libs/threadline.md forwarders block"
      to: "lib/sigra/audit/forwarders/threadline.ex:241 (repo = Keyword.get(opts, :repo))"
      via: "repo: key in forwarder opts"
      pattern: "repo:\\s*MyApp\\.Repo"
---

<objective>
Fix two adopter-facing copy-paste defects in shipped Sigra docs, surfaced by the
v1.29 SUITE-INTEGRATION milestone audit (.planning/v1.29-MILESTONE-AUDIT.md):

- **RC-01 (BLOCKER):** `threadline.md` tells adopters to paste `endpoint:`/`api_key:`
  forwarder keys and omits the required `repo:` key. The forwarder's inline path reads
  ONLY `repo:` (threadline.ex:241) and Threadline 0.5+ returns `{:error, :missing_repo}`
  without it → silent `[:sigra,:audit,:forward,:error]` on every audit event. Failure-mode
  #4 also describes HTTP/network errors that do not exist on the DB-based 0.5+ path.
- **CR-01 (tech debt):** Two docs call non-existent `Sigra.Audit.log` arities — `accrue.md:81`
  calls `log/1` with a map, `audit-logging.md:93` calls a config-first `log/3`. The only
  public log functions are `log/2 (action, opts)`, `log_safe/2`, `log_safe/3`.

Purpose: An adopter who copy-pastes from these docs gets working code, not silent
failures or compile/runtime errors against APIs that do not exist.

Output: Three corrected guide files. Docs-only — NO library code changes (the forwarder
contract and the `Sigra.Audit` public API are both correct; the docs are wrong).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/v1.29-MILESTONE-AUDIT.md
@.planning/todos/pending/2026-05-28-audit-log-config-first-api-gap.md

<interfaces>
<!-- Verified facts from the audit. Executor should NOT re-investigate the code. -->

The CORRECT forwarder config shape (test/example/config/config.exs:52-63) — match this key set:
```elixir
forwarders: [
  [
    module: Sigra.Audit.Forwarders.Threadline,
    id: :default,
    dispatch: :auto,
    # Threadline 0.5+ is DB-based; writes audit_actions via repo: — no HTTP
    # endpoint or api_key required.
    repo: Example.Repo
  ]
]
```

The forwarder inline path (lib/sigra/audit/forwarders/threadline.ex:241, 290-307):
- Reads ONLY `repo = Keyword.get(opts, :repo)`. Never reads `:endpoint` / `:api_key`.
- Calls `threadline.record_action(name, call_opts)` where call_opts = `[repo:, status:, correlation_id:]`.
- `{:error, :missing_repo}` is a handled return when `:repo` is absent.
- The prose pin `lib/sigra/audit/forwarders/threadline.ex:290-307` is CORRECT — leave it as-is.
- The version pin "Validated against threadline ~> 0.5" (lines 1,5,28) is CORRECT — leave it as-is.

The ONLY public Sigra.Audit log functions (lib/sigra/audit.ex):
- `log/2 (action, opts)` — action string + keyword list. (THE one to use in custom-event docs.)
- `log_safe/2`, `log_safe/3` — no-op-friendly variants.
- There is NO `log/1` and NO config-first `log/3`.
- `Sigra.Audit.multi/4` / `log_multi` exists (already used correctly in audit-logging.md:113).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix RC-01 — threadline.md forwarders block + failure modes + prereqs</name>
  <files>guides/recipes/companion-libs/threadline.md</files>
  <action>
    Three edits, all in guides/recipes/companion-libs/threadline.md:

    1. **Forwarders config block (lines ~62-69, "Sigra-side config block").** Replace the
       two lines `endpoint: System.get_env("THREADLINE_ENDPOINT")` and
       `api_key: System.get_env("THREADLINE_API_KEY")` with a single `repo: MyApp.Repo`
       line, so the entry's key set becomes module/dispatch/id/repo — matching
       test/example/config/config.exs:52-63. Use `MyApp.Repo` (recipe placeholder
       convention), NOT `Example.Repo`. Add a short inline comment mirroring the example:
       Threadline 0.5+ is DB-based; writes via `repo:` — no HTTP endpoint or api_key needed.
       Drop the trailing comma fix-up so the keyword list stays valid Elixir.

    2. **Prerequisites "Environment variables are set" bullet (lines ~38-40).** This bullet
       claims the forwarder reads `THREADLINE_ENDPOINT` and `THREADLINE_API_KEY` via
       `System.get_env/1`. That is false for 0.5+ (DB-based). Rewrite the bullet to state
       that Threadline 0.5+ persists audit actions through the same Ecto repo (`repo:`),
       so there are no Threadline-specific endpoint/api_key secrets to manage for the
       forwarder — confirm the repo from Threadline's bootstrap is the one passed as `repo:`.
       Do not invent new env-var requirements.

    3. **Failure modes #4 (lines ~115-121, "Network or transient failure on :async path").**
       Rewrite for DB framing: Threadline 0.5/0.6 is DB-based, there is no HTTP path.
       Reframe as transient DB failures (DB connection errors, repo temporarily unavailable,
       transient Postgres failures). Keep the existing, correct mechanics: retried by
       `Sigra.Workers.AuditForward` with `max_attempts: 5` + exponential backoff; after
       retries exhaust, the Oban job moves to `discarded` and a
       `[:sigra, :audit, :forward, :error]` telemetry event is emitted; the originating
       auth operation is never rolled back and the Sigra `AuditEvent` row is not deleted.
       Update the section heading to drop "Network" (e.g. "Transient DB failure on :async path").

    Leave UNCHANGED (verified correct): the version pins on lines 1, 5, 28
    ("threadline ~> 0.5"); the prose code pin "lib/sigra/audit/forwarders/threadline.ex:290-307"
    on line 74; failure modes #1, #2, #3, #5; the Non-goals and See-also sections.
  </action>
  <verify>
    grep -n "endpoint:\|api_key:\|THREADLINE_ENDPOINT\|THREADLINE_API_KEY\|HTTP timeout\|Network or transient" guides/recipes/companion-libs/threadline.md returns nothing;
    grep -n "repo: MyApp.Repo" guides/recipes/companion-libs/threadline.md returns the forwarders line;
    grep -n "threadline.ex:290-307" guides/recipes/companion-libs/threadline.md still present (pin unchanged).
  </verify>
  <done>
    The forwarders block key set is module/dispatch/id/repo with `repo: MyApp.Repo`
    (matching the example app); no `endpoint:`/`api_key:`/`THREADLINE_ENDPOINT`/
    `THREADLINE_API_KEY` references remain anywhere in the file; failure-mode #4 and the
    env-var prerequisite describe DB/transient framing with no HTTP language; version pin
    and the threadline.ex:290-307 prose pin are unchanged.
  </done>
</task>

<task type="auto">
  <name>Task 2: Fix CR-01 — real Sigra.Audit.log/2 signature in accrue.md + audit-logging.md</name>
  <files>guides/recipes/companion-libs/accrue.md, guides/flows/audit-logging.md</files>
  <action>
    Two edits — align both docs to the real `log/2 (action, opts)` API. This closes the
    doc-only side of the tracked todo
    (.planning/todos/pending/2026-05-28-audit-log-config-first-api-gap.md, Option B).
    Do NOT add a config-first `log/3` to the library — that is the deferred Option A.

    1. **accrue.md `log_audit/2` example (line 81).** Currently:
       `Sigra.Audit.log(event_map |> Map.put(:actor_id, user.id))` — a non-existent `log/1`
       map call. Rewrite to the real `log/2 (action, opts)` form: an action string plus a
       keyword list. Use an action string consistent with the accrue.md narrative (seat /
       billing context), e.g. `"billing.seat.added"`, passing keyword opts like
       `actor_id: user.id, actor_type: "user", metadata: %{...}`. Bridge the incoming
       `event_map` sensibly into opts (e.g. spread relevant fields into `metadata:` and pull
       any action/target from it) so the example still reads as forwarding the Accrue event.
       Keep the surrounding `@impl Accrue.Auth def log_audit(user, event_map)` shape and the
       two explanatory comments (source-of-truth note + event-type filtering pointer).
       If the surrounding prose at the `log_audit/2 note` block (lines ~95-98) implies any
       config-first or map-first signature, correct it; otherwise leave it.

    2. **audit-logging.md "Writing custom events" example (line 93).** Currently:
       `Sigra.Audit.log(config, "billing.subscription.upgraded", actor_id: ..., ...)` — a
       non-existent config-first `log/3`. Drop the leading `config` argument so it reads
       `Sigra.Audit.log("billing.subscription.upgraded", actor_id: ..., actor_type: ..., ...)`.
       Preserve all the existing opts (actor_id, actor_type, target_id, target_type, metadata).
       Scan the surrounding prose (the "What Sigra gives you" `Sigra.Audit.log` bullet on
       line 7, the reserved-prefix paragraph on line 105, and the Related list on line 193)
       and confirm none of it claims a config-first `log/3` signature; the line-7 and line-105
       references say `log` / `log/2` and are fine — leave the correct `Sigra.Audit.multi/4`
       / `log_multi` example (lines 107-120) UNCHANGED (that one is already correct).
  </action>
  <verify>
    grep -nE "Sigra\.Audit\.log\(config," guides/flows/audit-logging.md returns nothing (no config-first log/3);
    grep -nE "Sigra\.Audit\.log\(event_map|Sigra\.Audit\.log\([a-z_]+ \|>" guides/recipes/companion-libs/accrue.md returns nothing (no map-first log/1);
    grep -n 'Sigra.Audit.log("billing.subscription.upgraded"' guides/flows/audit-logging.md returns the corrected line;
    grep -n "Sigra.Audit.log(\"" guides/recipes/companion-libs/accrue.md returns the corrected log_audit line.
  </verify>
  <done>
    accrue.md line 81 uses `Sigra.Audit.log("<action>", actor_id:, actor_type:, metadata:)`
    (real log/2, action string + keyword list, no `log/1` map call); audit-logging.md line 93
    uses `Sigra.Audit.log("billing.subscription.upgraded", ...)` with no leading config arg
    (no config-first `log/3`); surrounding prose makes no config-first claims; the
    `Sigra.Audit.multi/4` example is unchanged.
  </done>
</task>

<task type="auto">
  <name>Task 3: Verification gate — docs build clean + banned-phrase + key-set match</name>
  <files>guides/recipes/companion-libs/threadline.md, guides/recipes/companion-libs/accrue.md, guides/flows/audit-logging.md</files>
  <action>
    Run the verification gate over the three edited files. No code edits in this task —
    if any check fails, return to Task 1/Task 2 and fix, then re-run.

    1. Docs build: `mix docs --warnings-as-errors` must exit 0 (no Postgres needed for docs).
    2. Banned-phrase grep over the three edited files must return zero matches:
       "seamlessly", "just works", "production-ready out of the box", "the recommended way".
    3. Confirm the threadline.md forwarders block now contains the same key set as the
       example app config: module, id, dispatch, repo (and no endpoint/api_key).
  </action>
  <verify>
    <automated>mix docs --warnings-as-errors</automated>
    grep -rniE "seamlessly|just works|production-ready out of the box|the recommended way" guides/recipes/companion-libs/threadline.md guides/recipes/companion-libs/accrue.md guides/flows/audit-logging.md returns zero lines;
    grep -nE "module:|id:|dispatch:|repo:" guides/recipes/companion-libs/threadline.md shows all four keys present in the forwarders block.
  </verify>
  <done>
    `mix docs --warnings-as-errors` exits 0; banned-phrase grep returns zero across all
    three files; the threadline.md forwarders block key set matches the example
    (module/id/dispatch/repo, no endpoint/api_key).
  </done>
</task>

</tasks>

<verification>
- `mix docs --warnings-as-errors` exits 0.
- No `endpoint:`/`api_key:`/`THREADLINE_ENDPOINT`/`THREADLINE_API_KEY`/HTTP-failure language
  anywhere in threadline.md; forwarders block uses `repo: MyApp.Repo`.
- No `Sigra.Audit.log/1` (map) or config-first `log/3` calls remain in any of the three files.
- Banned-phrase grep returns zero across the three edited files.
- No files under lib/ were modified (docs-only change).
</verification>

<success_criteria>
- An adopter copy-pasting the threadline.md forwarders block gets a DB-based forwarder that
  works (passes `repo:`), not silent forward errors.
- All `Sigra.Audit.log` examples in the docs use the real `log/2 (action, opts)` signature.
- Failure-mode and prerequisite framing for Threadline matches the DB-based 0.5+ reality.
- RC-01 (BLOCKER) and the doc-only side of CR-01 are closed; the deferred config-first
  `log/3` library work remains tracked in the pending todo (Option A, untouched).
</success_criteria>

<output>
Create `.planning/quick/260528-nwa-fix-rc-01-in-guides-recipes-companion-li/260528-nwa-SUMMARY.md` when done.
</output>
