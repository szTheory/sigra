# Phase 38 — Technical research (Human GA UAT gate)

**Phase:** 38 — Human GA UAT gate  
**Question:** What do we need to know to PLAN execution of UAT-01 / UAT-02 against SEED-001?

## 1. Source-of-truth stack

| Artifact | Role |
|----------|------|
| `.planning/seeds/SEED-001-v1.0-ga-human-uat-gate.md` | Canonical list of **8** human-only items, breadcrumbs to phase verifiers |
| `.planning/phases/38-human-ga-uat-gate/38-CONTEXT.md` | Locked decisions D-38-P01–P08, D-38-01–13 — **planner must not contradict** |
| `.planning/REQUIREMENTS.md` | **UAT-01**, **UAT-02** — checkboxes close only when evidence + master file exist |
| `scripts/uat/RUNBOOK.md` | Step-by-step environment (Docker Postgres, `test/example`, mailbox preview URL) |
| `test/example/priv/playwright/tests/golden-path.spec.ts` | Automation baseline — waivers must state **delta** from this coverage |

## 2. The eight items (execution grouping)

| # | Theme | Primary host | Automation overlap |
|---|--------|----------------|-------------------|
| 1 | Lockout + suspicious-login **email HTML** (Phase 04) | `test/example` + real mail clients | None for pixel-perfect clients |
| 2 | Seven **account-lifecycle** templates (Phase 08) | Same | None for multi-client HTML |
| 3 | `mix sigra.gen.oauth` in **fresh** Phoenix 1.8 | Greenfield app (D-38-12) | None for generator file count |
| 4 | **Google** OAuth E2E | Greenfield or example + real creds | Playwright may cover happy path — cite gap |
| 5 | Provider linking + last-method **UI** | Browser on example | Partial — human for tooltip/disable |
| 6 | Email-match confirmation **flash + redirect** | Browser | Flow timing |
| 7 | Backup code **regenerate** wiring (Phase 06 TODO check) | Browser MFA path | Verify closed vs open gap |
| 8 | **Clean-machine** `getting-started.md` | Fresh Phoenix + install | None |

**Planning implication:** Plans should not collapse the eight into one task — each row in `v1.3-HUMAN-UAT.md` maps 1:1 to SEED items for traceability.

## 3. Evidence layout (recommended)

Per **D-38-05 / D-38-06**:

```
.planning/uat-evidence/v1.3.0/
  INDEX.md                 # inventory + SHA + waiver links
  item-01-lockout-mail/    # transcripts, redacted screenshots
  item-02-lifecycle-mail/
  ...
  item-08-getting-started/
```

**Text-first:** For each item, prefer `steps.md` or `transcript.txt` with commands + URLs (redacted). Screenshots only where visual density matters.

## 4. Waiver quality bar

Minimum fields per **D-38-03**: `item_id`, `date`, `owner`, `version_sha_anchor`, `reason`, `residual_risk`, `compensating_evidence`, `expiry_or_next_trigger`, `link`.

**Compensation examples:** “Playwright golden-path covers OAuth happy path; human waived Google consent screen — stand-in IdP evidence in `item-04-oauth/stand-in.md`.”

## 5. Environment string (for master table)

Standard tuple to copy into **D-38-09** “Environment” column:

- Elixir/OTP: `elixir -v` output line
- Postgres: image tag or `SELECT version();`
- Sigra: **Hex release or git SHA** of `sigra` dep + repo `git rev-parse HEAD` for path dep
- Host type: `test/example path dep` | `fresh phx.new + mix sigra.install`

## 6. Risks specific to this phase

- **Secret leakage** in mail/OAuth captures — enforce redaction checklist before `git add`.
- **False “Pass”** when only one of three mail clients ran — D-38-04 blocks this unless explicitly documented.
- **Scope creep** into product fixes — item 7 if broken is a **bug ticket**, not a silent UAT pass (per SEED-001 Notes).

---

## Validation Architecture

**Nyquist role:** Phase 38 is predominantly **manual verification** with **grep-able documentation** gates. Automated commands prove repo consistency (paths exist, tables complete); humans prove UX.

### Dimension mapping

| Dimension | How satisfied |
|-----------|----------------|
| 1–2 Scope / correctness | Each SEED row has Executed/Waived/Blocked + evidence link or waiver block |
| 3–5 Test infra | `bash`/`grep` on `.planning/v1.3-HUMAN-UAT.md` + `INDEX.md`; optional `mix test` unchanged |
| 6–7 Security-adjacent | Threat model in plans; redaction checklist artifact; no raw tokens in repo |
| 8 Nyquist | This section + `38-VALIDATION.md` per-task map |

### Feedback commands (executor)

- **Quick:** `grep -E 'Executed|Waived|Blocked' .planning/v1.3-HUMAN-UAT.md | wc -l` — expect **8** lines in status column rows (adjust grep to match table format chosen in Plan 01).
- **Integrity:** `test -f .planning/uat-evidence/v1.3.0/INDEX.md && test -f .planning/v1.3-HUMAN-UAT.md`
- **No secrets:** `! rg -n 'sigra_sk_|Bearer |password=|ARGON2|secret_key' .planning/uat-evidence/` (allowlisted test fixtures in separate grep if needed).

### Wave 0

No new test framework — **existing** `scripts/ci/milestone-verification-gate.sh` or doc-link checks optional in Plan 01 if added to verification block.

---

## Planner handoff

- Produce **two waves minimum:** (1) repo scaffolding + table schema, (2) human execution + population of evidence paths + REQUIREMENTS checkbox updates.
- Every task: `<read_first>` includes `38-CONTEXT.md` and the specific RUNBOOK anchor or SEED section.
- **Do not** mark UAT-01 complete until all eight rows are terminal states (Executed or Waived with full waiver record).

## RESEARCH COMPLETE
