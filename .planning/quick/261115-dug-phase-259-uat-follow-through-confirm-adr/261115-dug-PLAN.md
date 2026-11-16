---
phase: quick-261115-dug
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - .planning/decisions/005-brand-adoption-compatibility-policy.md
  - .planning/decisions/006-name-clearance-search-log-and-claims-register.md
  - test/sigra/brand/policy_docs_test.exs
  - test/sigra/brand/name_clearance_test.exs
  - guides/flows/password-reset.md
autonomous: true
requirements: []
estimate:
  tokens: 40000
  raw_tokens: 20000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "ADR 005 decision table: every row (1-9, 11, 12, 14) carries a confirmed status with a date; none says pending"
    - "ADR 006 states both decisions (clear-space, logo-use) as confirmed as recommended by the owner on 2026-11-15, in the header and in each per-decision Status line"
    - "ADR 005 records the SC-4 reading and names the todos that track the registration and passkey sign-in divergences"
    - "guides/flows/password-reset.md Step 1 says the snippet is the corrected shape and that the currently generated view/controller still pass a user struct"
    - "No shipped bytes change: nothing under priv/templates or lib is edited"
    - "mix test test/sigra/brand and test/sigra/guides_dx02_test.exs are green"
  artifacts:
    - path: ".planning/decisions/005-brand-adoption-compatibility-policy.md"
      provides: "confirmed decision table plus SC-4 reading amendment"
    - path: ".planning/decisions/006-name-clearance-search-log-and-claims-register.md"
      provides: "confirmed clear-space and logo-use statuses"
    - path: "guides/flows/password-reset.md"
      provides: "G-259-4 honest note on generated reset request code"
  key_links:
    - from: "test/sigra/brand/policy_docs_test.exs"
      to: ".planning/decisions/005-brand-adoption-compatibility-policy.md"
      via: "owner decision table row statuses"
    - from: "test/sigra/brand/name_clearance_test.exs"
      to: ".planning/decisions/006-name-clearance-search-log-and-claims-register.md"
      via: "status label terms for clear-space and logo-use"
---

<objective>
Phase 259 UAT follow-through, owner direction "follow your recs": (1) record the owner's confirmation of ADR 005 decisions 1-9, 11, 14 and ADR 006's two decisions as recommended, and keep their pinning tests meaningful; (2) record the SC-4 reading in ADR 005; (3) fix gap G-259-4 in the password-reset guide, documentation only.

Purpose: close the open owner-confirmation items without changing any shipped byte, and stop the published guide from implying the generated reset request code is already correct.
Output: edited ADR 005, ADR 006, two brand tests, and one guide paragraph. Do NOT touch 259-UAT.md or 259-VERIFICATION.md (the orchestrator handles them). Do NOT edit anything under priv/templates or lib.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@.planning/decisions/005-brand-adoption-compatibility-policy.md
@.planning/decisions/006-name-clearance-search-log-and-claims-register.md
@test/sigra/brand/policy_docs_test.exs
@test/sigra/brand/name_clearance_test.exs
@guides/flows/password-reset.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Confirm ADR 005 decisions, record the SC-4 reading, and re-pin the policy test</name>
  <files>.planning/decisions/005-brand-adoption-compatibility-policy.md, test/sigra/brand/policy_docs_test.exs</files>
  <read_first>
    - .planning/decisions/005-brand-adoption-compatibility-policy.md (header line 3, table lines 17-30, line 92, "Related decisions" #14 bullet, "Consequences" last bullet, "Revisit triggers")
    - test/sigra/brand/policy_docs_test.exs (the "labels decision 12 confirmed ..." test, about lines 118-140, and @decision_numbers at line 43)
    - .planning/todos/pending/2026-11-13-duplicate-registration-timing-oracle.md
    - .planning/todos/pending/2026-11-13-passkey-options-email-existence-oracle.md
    - .planning/todos/pending/2026-09-15-generated-confirm-routes-unreachable-both-session-states.md
    - .planning/todos/pending/2026-11-14-generated-reset-request-page-mount-and-user-struct-call.md
  </read_first>
  <action>
ADR 005 edits (use Edit, scoped replacements; keep the file's amendment style of ADR 003, dated and in place):

1. Table: for rows 1-9, 11 and 14, replace the Status cell "Recommended default - owner confirmation pending" with exactly "Confirmed as recommended by owner, 2026-11-15". Leave row 12 as "Owner-approved, confirmed 2026-11-13". Keep the column header "Recommended default" (it still describes the Recommended default column's content).
2. Header line 3 Status: reword to "Accepted (policy shape). Every recorded decision is confirmed: decision #12 on 2026-11-13, and decisions 1-9, 11 and 14 as recommended by the owner on 2026-11-15." Must not contain the phrase "owner confirmation pending" or "awaits owner confirmation".
3. Line 92 ("Each decision below is a recommended default awaiting owner confirmation, except where marked."): reword to say each decision was proposed as a recommended default and confirmed as recommended by the owner on 2026-11-15 (decision 12 on 2026-11-13).
4. "Related decisions" #14 bullet: change "is recommended to be the book's prose rule" to state it is the book's prose rule (confirmed 2026-11-15); keep the pointer to ADR 006.
5. "Consequences" last bullet ("Decisions other than #12 remain recommended defaults until the owner confirms them ..."): replace with a sentence that all recorded decisions are confirmed and that a later change is a dated in-place amendment to this record.
6. Append a new final section "## Amendment 2026-11-15: owner confirmation and the SC-4 reading" (after "Revisit triggers"). It must contain two short parts. Part A: on 2026-11-15 the owner confirmed decisions 1-9, 11 and 14 as recommended ("follow your recs"), and the two ADR 006 decisions (clear-space, logo-use); no decision text changed. Part B, the SC-4 reading: SC-4 means "every pre-auth surface has an asserted, honest state"; it does not mean every listed surface is identical. Registration and passkey sign-in options stay registered as known divergences, asserted to still differ, and are listed as not covered in the public docs. They are real account-existence leaks that a zero-shipped-bytes phase cannot fix; the owner's direction is that they are fixed as shipped-byte work before Phase 262, tracked by the existing todos `.planning/todos/pending/2026-11-13-duplicate-registration-timing-oracle.md` (registration; it covers the timing oracle and notes the auto-sign-in versus flash difference is inherent to signing a new account in, so do not promise that part becomes identical) and `.planning/todos/pending/2026-11-13-passkey-options-email-existence-oracle.md` (passkey sign-in options). Also name `.planning/todos/pending/2026-09-15-generated-confirm-routes-unreachable-both-session-states.md` and `.planning/todos/pending/2026-11-14-generated-reset-request-page-mount-and-user-struct-call.md` as the generated-host fixes that go with the same pre-262 shipped-byte work. Do not use the words "v1", "for now", "placeholder" or "simplified" in this section.

Test edit in test/sigra/brand/policy_docs_test.exs, replace the test "labels decision 12 confirmed and every other recorded decision as pending" (rename it to "labels every recorded decision as confirmed with a date and none as pending"). New assertions, keeping the existing `rows` map build and `Map.keys(rows) |> Enum.sort() == Enum.sort(@decision_numbers)` check:
   - `rows["12"]` matches "confirmed" and "2026-11-13" and does not match "pending".
   - For every other row (11 rows, assert `length(others) == 11`), the row text matches "Confirmed as recommended by owner" and "2026-11-15".
   - For every row, `refute text =~ "pending"` (case-insensitive regex ~r/pending/i).
   - Whole-ADR guard: `refute adr =~ "owner confirmation pending"` and `refute adr =~ "awaiting owner confirmation"` and `refute adr =~ "awaits owner confirmation"`, using the full text read earlier in the test (read it once, derive the slice from it).
Also add one small new test in the same describe: the ADR carries the heading "## Amendment 2026-11-15" and the SC-4 reading, asserting `adr =~ "SC-4"`, `adr =~ "asserted, honest state"`, and that it cites `2026-11-13-duplicate-registration-timing-oracle.md` and `2026-11-13-passkey-options-email-existence-oracle.md`. Keep AAA flat style used in the file; ExUnit.Case async stays as is. Use existing helpers (`read!`, `section_slice`, `table_data_rows`, `missing_terms`); do not add dependencies.
  </action>
  <verify>
    <automated>source tmp/db.env && mix test test/sigra/brand/policy_docs_test.exs && mix format --check-formatted test/sigra/brand/policy_docs_test.exs</automated>
  </verify>
  <done>Every ADR 005 table row reads confirmed with a date (12 on 2026-11-13, the other 11 on 2026-11-15); header, line-92 prose and Consequences no longer say pending; the amendment section records the SC-4 reading and todo references; policy_docs_test passes and fails if any row is reverted to pending.</done>
</task>

<task type="auto">
  <name>Task 2: Confirm ADR 006 decisions and re-pin the name-clearance test</name>
  <files>.planning/decisions/006-name-clearance-search-log-and-claims-register.md, test/sigra/brand/name_clearance_test.exs</files>
  <read_first>
    - .planning/decisions/006-name-clearance-search-log-and-claims-register.md (line 3 Status, lines 61, 67, 93 Status lines, Revisit triggers)
    - test/sigra/brand/name_clearance_test.exs (moduledoc lines 10-22, the test at about lines 374-390, and line 177 which is about crosswake_sigra and must stay unchanged)
  </read_first>
  <action>
ADR 006 edits (Edit, scoped):

1. Line 3 Status: keep the "This is a search log and not a clearance ... nothing here is legal advice" sentences exactly; replace only the final sentence "Both decisions in this record are recommended defaults, owner confirmation pending." with "Both decisions in this record (clear-space and logo-use) were confirmed as recommended by the owner on 2026-11-15." Keep the phrase "search log, not clearance" in the title untouched. Do not add any clearance wording (the test bans it), and do not add trademark symbols.
2. The no-trademark-claim decision Status line (about line 61), the clear-space Status (about line 67, "Label: clear-space. Status: ...") and the logo-use Status (about line 93, "Label: logo-use. Status: ..."): each "recommended default, owner confirmation pending" becomes "confirmed as recommended by owner, 2026-11-15". The no-trademark-claim decision is ADR 005 decision 14's counterpart, which the owner confirmed under "follow your recs"; label it the same way and keep its Reversibility line.
3. Leave the "Recommended default:" and "Recommended wording" prose paragraphs as they are (they are the decision text). Leave the crosswake_sigra "maintainer to confirm, pending maintainer confirmation" wording unchanged: that is a separate, still-open fact, and name_clearance_test line ~177 pins it.
4. Append a short dated line under "Revisit triggers" (new final paragraph or sub-note): "Amendment 2026-11-15: the owner confirmed the three decisions above as recommended; no decision text changed." Dated, in place, per ADR 003 style.

Test edits in test/sigra/brand/name_clearance_test.exs:
- Moduledoc line ~17-18: change the bullet to "the example-host limitation, the two decisions and their `confirmed as recommended` status are present;" (reword the surrounding bullet accordingly).
- Replace the test "both decisions carry their labels and the owner-confirmation-pending status" (rename to "both decisions carry their labels and the confirmed-as-recommended status with a date"). Required terms list becomes ["clear-space", "logo-use", "confirmed as recommended by owner, 2026-11-15"]; keep the existing 300 units / 233.75 / logo.clearSpace assertions. Add: `refute String.contains?(content, "owner confirmation pending")`. Add a per-decision check so the status is on each decision's own Status line, not just anywhere in the file: for the lines starting with "Label: clear-space." and "Label: logo-use." assert each contains "confirmed as recommended by owner, 2026-11-15" (find them with `String.split(content, "\n")` and `Enum.find`). Do not touch the crosswake pending-maintainer-confirmation assertion.
Keep AAA structure used in the file.
  </action>
  <verify>
    <automated>source tmp/db.env && mix test test/sigra/brand/name_clearance_test.exs && mix format --check-formatted test/sigra/brand/name_clearance_test.exs</automated>
  </verify>
  <done>ADR 006 header and all three decision Status lines read confirmed with the date; "owner confirmation pending" no longer appears anywhere in ADR 006; the crosswake maintainer-confirmation wording is intact; name_clearance_test passes and would fail on a reverted status.</done>
</task>

<task type="auto">
  <name>Task 3: Fix G-259-4 in the password-reset guide, Step 1</name>
  <files>guides/flows/password-reset.md</files>
  <read_first>
    - guides/flows/password-reset.md (Step 1, the paragraph that begins "The generated context's `deliver_user_reset_password_instructions/2` takes the email address as a string" and ends "Check the call in the code generated into your app.")
    - priv/templates/sigra.install/core/reset_password_live.ex (about line 155, read only) and priv/templates/sigra.install/core/reset_password_controller.ex (about line 24, read only): both call get_user_by_email then pass the user struct
    - test/sigra/brand/claims_docs_test.exs (the "reset instructions call shape" and "planning references" describes; pins listed below)
  </read_first>
  <action>
Edit only the single paragraph that follows the Step 1 code snippet; touch nothing else in the guide, and edit nothing under priv/templates or lib (zero shipped bytes; the generated-host fix lives in the existing todo and ships later).

Rewrite that paragraph so it says, in this order: (a) the snippet above is the corrected shape; the generated context's `deliver_user_reset_password_instructions/2` takes the email address as a string (its only function head requires a binary), so pass the submitted email rather than a looked-up user; (b) a call that looks the account up first and passes the user fails with a `FunctionClauseError` for an address that has an account and returns normally for one that does not, which tells a visitor which addresses are registered (keep this existing sentence); (c) the request view and the request controller that Sigra currently generates into a new app still look the user up with `get_user_by_email` and pass the struct, so a freshly generated app has this defect until the generated code is fixed; (d) a closing instruction to compare the call in the code generated into the reader's app with the snippet and change it to pass the email. Reword around, and replace, the existing closing sentence "Check the call in the code generated into your app." so it is not duplicated.

Constraints so the existing guards stay green (all verified by reading claims_docs_test.exs and copy_contract_test.exs):
- Do not write the literal text `deliver_user_reset_password_instructions(` followed by an argument and a comma anywhere new; refer to the function only as `deliver_user_reset_password_instructions/2` (the call-shape test expects the guide's call arguments to remain exactly ["email", "user.email"]).
- Do not cite planning artifacts: no `.planning`, no "todo", no phase numbers, no registry ids, no `public-surfaces` (the planning-references test flags `.planning` and `public-surfaces`; also keep published prose free of internal references).
- Do not edit the "**Scope of this claim:**" paragraph (tests require it to keep "single attempt", "example application", "generated into your app" and a rate-limit mention).
- Avoid the brand book's "Do not say" vocabulary (the lexicon scan covers guides/flows); use plain words such as "defect", "generated", "compare". Do not use the words "login", "logout" or "signin" in new prose.
- No fenced code blocks and no new code samples; the guide uses indented code, and this change is prose only.
No test pins this paragraph's exact text (grep of test/ for password-reset.md shows only claims_docs_test.exs and guides_dx02_test.exs, which pin the scope paragraph, retired phrases and call arguments), so no test edit is needed.
  </action>
  <verify>
    <automated>source tmp/db.env && mix test test/sigra/brand test/sigra/guides_dx02_test.exs</automated>
  </verify>
  <done>The Step 1 paragraph states the snippet is the corrected shape, that the currently generated view and controller still look the user up with get_user_by_email and pass the struct (FunctionClauseError for a registered address), and tells the reader to compare their generated call; "Check the call in the code generated into your app." appears no more than once and not as a duplicate; git diff shows no change under priv/templates or lib; the whole brand test directory and guides_dx02_test are green.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| docs to adopters | Published guide text is read by adopters who copy its code shape into their own app |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-261115-01 | Information Disclosure | guides/flows/password-reset.md Step 1 | medium | mitigate | Guide states the generated request code still passes a user struct (registered-address FunctionClauseError reveals account existence) and tells the reader to switch to the email argument; enforced by the unchanged call-shape test |
| T-261115-02 | Repudiation | ADR 005/006 status | low | mitigate | Confirmations are dated 2026-11-15 and pinned by tests so a silent revert fails |
| T-261115-SC | Tampering | npm/pip/cargo installs | high | accept | No package installs in this plan; docs and tests only |
</threat_model>

<verification>
- `source tmp/db.env && mix test test/sigra/brand test/sigra/guides_dx02_test.exs` is green (run `scripts/db/up.sh` first if the database is down).
- `mix format --check-formatted test/sigra/brand/policy_docs_test.exs test/sigra/brand/name_clearance_test.exs` passes.
- `git diff --stat` lists only the five files in files_modified; nothing under priv/templates or lib; 259-UAT.md and 259-VERIFICATION.md untouched.
- `grep -c "owner confirmation pending" .planning/decisions/005-brand-adoption-compatibility-policy.md .planning/decisions/006-name-clearance-search-log-and-claims-register.md` reports 0 for both (HEAD baseline is nonzero for both, so this gate is not already passing).
</verification>

<success_criteria>
All owner-confirmed decisions recorded with the 2026-11-15 date, tests pin the new state (confirmed and dated, none pending), the SC-4 reading is recorded with its todo references, G-259-4 is documented in the guide, and the brand test directory is green with zero shipped bytes changed.
</success_criteria>

<output>
Create `.planning/quick/261115-dug-phase-259-uat-follow-through-confirm-adr/261115-dug-SUMMARY.md` when done
</output>
