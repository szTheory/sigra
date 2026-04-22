# Phase 42: Human GA matrix & evidence — Context

**Gathered:** 2026-04-20  
**Status:** Ready for planning

<domain>

## Phase boundary

Deliver **GA-02..GA-05** per `.planning/REQUIREMENTS.md`: residual **human** verification (email clients, live Google OAuth, clean-machine getting-started) with honest **Executed / Waived / Blocked** records, plus the **consolidated v1.4 GA artifact** and **targeted** updates to `docs/uat-ci-coverage.md` when the **machine vs human boundary** actually moves.

**In scope:** Process, evidence layout, waiver discipline, maintainer-facing docs under `.planning/` and `docs/`, pointers to CI and existing v1.3-style evidence patterns.

**Out of scope:** GA-01 product implementation (Phase **41** — link to its proof only); **AUD-*** audit conversion (Phases **43–45**); net-new auth features.

</domain>

<decisions>

## Implementation decisions

### D-42-01 — GA-05 artifact & evidence tree (two-layer, least surprise)

- **Canonical matrix (single file):** `.planning/v1.4-GA-UAT.md` is the **one** milestone-visible table for v1.4 GA posture (same spirit as **D-38-08** / `v1.3-HUMAN-UAT.md`). **Do not** split the matrix into multiple peer files until editing friction forces it; if navigation is needed, add **only** `.planning/uat-evidence/v1.4/INDEX.md` as a hub — the matrix stays authoritative.
- **Versioned evidence tree:** `.planning/uat-evidence/v1.4/` with subfolders by theme (`GA-02/`, `GA-03/`, `GA-04/`, optional `GA-01-pointer/` for links only). Each folder holds **small** `README.md` / `EVIDENCE.md` / `steps.md` / `waiver.md` patterns consistent with v1.3 — **pointers and transcripts**, not raw log dumps unless necessary.
- **Release-line naming:** Prefer **`v1.4/`** under `uat-evidence` with **patch-level** sub-notes when a hotfix re-proves a subset (e.g. `GA-03/hotfix-…md`). Avoid a sole `latest/` symlink as canonical; pin **Hex version + git SHA** in the matrix header and per row (**D-38-P01**).
- **Column layout:** **Reuse** v1.3 master columns (**D-38-09**): `Requirement | Status | Date | Owner | Environment | Evidence_link | Expiry | Notes`. **Extend minimally** with:
  - **`CI_substitute`** — workflow/job or test path that carries machine intent (may be “N/A” for pure-human rows).
  - **`Surface`** — `lib` | `generator` | `host` | `docs` so downstream readers do not confuse library guarantees with host-owned wiring.
- **Public / private boundary:** Keep the **full** matrix + evidence under `.planning/`. Distill **CHANGELOG** / HexDocs to a **one-line pointer** (“Human GA: see `v1.4-GA-UAT.md`”) — matches Elixir OSS norms (changelog + security notes as the user-facing spine).
- **GA-01 row:** Single **Executed** pointer row — links to Phase 41 proof (`backup_code_rotation_test.exs`, `example_unit_smoke`, optional Playwright shell) and **does not** re-run rotation proof in Phase 42.

### D-42-02 — GA-02 / GA-03: automation-first, human as sampled truth

- **Default posture:** **Execute-by-default** (**D-38-01**); waivers are **exceptional**, **dated**, **owned**, **risk-stated**, **compensating**, **time-bounded** (**D-38-02..04**).
- **GA-02 (email visual QA):**
  - **Machine baseline (always on):** Treat existing **HTML structure tests** (`EmailsSecurityHtmlTest`, `EmailsLifecycleHtmlTest`, `example_unit_smoke`) as the **regression spine** — same class of assurance as Rails **ActionMailer previews** / **Swoosh local**: fast maintainer DX, catches structural breakage, **not** a claim about all MUAs.
  - **Human trigger:** Run **Gmail + Outlook + Apple Mail** (or documented substitutes) on **release boundaries** and whenever **email HTML/CSS/layout** or **multipart structure** changes materially — not every copy tweak.
  - **Waiver compensation:** Accept **Litmus / Email on Acid / screenshot bundles** **only** alongside **(a)** CI HTML snapshot diff for the same change, **(b)** explicit **residual risk** (spam tab, dark mode, clipping), **(c)** **expiry_or_next_trigger** when drift is likely. **Never** claim “triple-client verified” from screenshots alone.
- **GA-03 (live Google OAuth):**
  - **Machine baseline:** Keep **MockStrategy / contract tests** and **library OAuth tests** as the deterministic proof of **protocol handling** your code owns (state, PKCE, callback shape) — aligned with **NIST 800-63C RP** thinking: automate what tokens and metadata **must** satisfy.
  - **Human trigger:** **Live Google** smoke on a **dedicated test OAuth client** for **each minor/major** (and patch if OAuth/HTTP/TLS/JWT deps change). Checklist lives in versioned docs (e.g. `scripts/uat/` or `docs/...`) — **not** tribal GCP lore.
  - **Waiver:** Permitted for **intermediate** branches only if it links **last pinned live run** + **diff since**; **no GA tag** without fresh live smoke **or** a formal **Waived** row with vendor/policy infeasibility + compensation (stand-in IdP evidence for redirect/error paths per **D-38-13** spirit).
- **Honesty rule:** Separate **“crypto / protocol correctness”** (mostly CI) from **“trust UX + IdP policy reality”** (human + narrow). OWASP-style **email-channel** risks favor **token semantics and user-notice** evidence in CI; human mail clients validate **recognition and rendering** — state both in GA prose to avoid checkbox theater.

### D-42-03 — GA-04: clean-machine protocol (30 min, witness-biased)

- **Default method:** **Synchronous 30-minute witnessed run** — reviewer executes **only** `guides/introduction/getting-started.md` steps (one **lane** per session: greenfield **or** example-first **or** generator blessed-path — **do not** interleave without the doc explicitly promising it).
- **Reviewer bar:** Must **not** have **merged to Sigra** in the agreed cooling window (**30–90 days** — pick one value in PLAN.md based on team size). Not the doc author; not “muscle memory” on the generator.
- **Witness role:** Timestamp stalls; **does not** drive the keyboard except to answer **doc-level** blockers; if the reviewer deviates from the doc to “fix forward,” the run is **SUCCESS WITH DEVIATION** and deviations are listed — not silent success.
- **Evidence minimum:** Start/end timestamps (timezone); **environment fingerprint** (OS, Elixir/OTP, Postgres, Node if assets); **ordered command log**; **friction table** (step / expected / actual / class `doc|env|product` / owner); outcome **SUCCESS | BLOCKED | SUCCESS WITH DEVIATION**.
- **Async variant (allowed when scheduling blocks):** Only with **terminal transcript** (or `asciinema`-class log) + **“first failure wins”** (stop at first mismatch; no undocumented fixes) + same friction table. Otherwise async is **not** admissible as GA-04 proof.
- **Recording:** Video **optional** unless failures are non-deterministic; prefer transcript + screenshots; apply **D-38-P04** redaction for paths/tokens.

### D-42-04 — `docs/uat-ci-coverage.md`: edit when the machine boundary moves

- **Hard rule (primary):** Edit **`docs/uat-ci-coverage.md`** when merge-blocking **CI substitutes** change — new/renamed/removed **required** job, new test module closing a SEED row, or an intentional **policy** change to what “machine-closed” means. This matches ROADMAP criterion (3) **without** tying every GA-05 attestation tweak to doc churn.
- **Hygiene rule (secondary):** At **milestone close** / before **Hex tag**, run a **short drift pass**: job names in doc vs `.github/workflows/ci.yml` vs branch protection; fix renames even when SEED semantics are unchanged.
- **Single source of truth split:** **`ci.yml` + branch protection** = enforcement truth; **`uat-ci-coverage.md`** = human-readable **SEED → CI → residual** map + honesty about what humans still own; **`v1.4-GA-UAT.md`** = **Executed/Waived/Blocked** + dates + evidence links. GA-05 **does not** duplicate full job lists — it **links** rows to the coverage doc and to `.planning/uat-evidence/`.
- **Anti-footguns:** Do not mark residual empty because CI is green; do not imply Litmus or HTML tests **eliminated** MUA variance; do not let GA-05 become a second workflow definition.

### D-42-05 — Cohesion with Phase 38 and product vision

- **Carry forward unchanged unless v1.4 explicitly narrows scope:** **D-38-P01..P08** (reproducibility, waiver fields, PII discipline, fail-closed on security-adjacent surfaces, contributor scripts under `scripts/uat/` where applicable).
- **Sigra-specific:** Prefer **`test/example`** + documented **`mix phx.new` + install** lanes exactly where **REQUIREMENTS.md** demands fresh-host proof — same split as v1.3 between **daily harness** and **greenfield trigger**.
- **DX principle:** A new maintainer answers in **~60 seconds**: which GA rows moved for this release, where is proof, what is still human-residual — achieved by **one matrix file + versioned evidence tree + stable links to CI runs with run IDs**.

### Claude's discretion

- Exact cooling-window days for GA-04 reviewers (within 30–90).
- Whether v1.4 evidence uses `GA-xx/` folder names vs requirement-id folders — must stay consistent within the milestone.
- Optional `asciinema` vs raw shell transcript for async GA-04.

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — **GA-02..GA-05** (v1.4 SEED-001 residuals)
- `.planning/ROADMAP.md` — Phase 42 row + success criteria
- `.planning/PROJECT.md` — v1.4 GA + audit narrative

### Prior locked context (carry-forward)

- `.planning/phases/38-human-ga-uat-gate/38-CONTEXT.md` — UAT matrix discipline, waiver schema, evidence layout (**D-38-***)
- `.planning/phases/41-backup-codes-ga-product-closure/41-CONTEXT.md` — **GA-01** closure patterns; rotation + CI proof ownership

### Canonical examples & harness

- `.planning/v1.3-HUMAN-UAT.md` — table shape reference for v1.4 matrix
- `.planning/uat-evidence/v1.3.0/INDEX.md` — evidence tree pattern
- `docs/uat-ci-coverage.md` — SEED ↔ CI ↔ residual map (edit per **D-42-04**)
- `.github/workflows/ci.yml` — merge-blocking job ground truth
- `scripts/uat/RUNBOOK.md` — optional human alignment for example stack
- `guides/introduction/getting-started.md` — **GA-04** target doc

### OWASP / standards (rationale anchors — not duplicate requirements)

- OWASP ASVS authentication / V2 themes — email as **weak channel** vs token semantics (inform waiver honesty, not replace project REQ IDs)
- NIST SP 800-63C implementation resources — **RP** validation mindset for federation (**GA-03** machine vs live split)

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- `test/example/test/example/accounts/emails_*_html_test.exs` — GA-02 machine baseline (structure, CTAs, footers)
- `test/example/test/example_web/smoke/backup_code_rotation_test.exs` — GA-01 cryptographic proof (link from matrix, do not re-execute in 42)
- `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts` — browser shell / UX residual
- `scripts/ci/getting-started-contract.sh` — GA-08-style doc contract; extend narrative for **GA-04** human timing alongside, not conflated with, machine checks

### Established patterns

- v1.3 human UAT: matrix in `.planning/` + evidence subtree + waiver files — **reuse** for v1.4 paths
- `CHANGELOG.md` one-line human GA pointer — keep for v1.4 tag

### Integration points

- Phase **43+** planners should treat **GA-05** as closed before claiming v1.4 “GA complete” for audit workstreams
- Release captain updates **`docs/uat-ci-coverage.md`** when CI graph changes; GA owner updates **matrix + evidence** on every human run

</code_context>

<specifics>

## Specific ideas

- Subagent research consensus: **two-layer** (single matrix + `uat-evidence/v1.4/`) balances **Hex-ecosystem** expectations (lean public surface, detailed maintainer artifacts) with **Django-checklist** / **Stripe-quickstart** clarity — without **Auth0-style** PDF theater.
- Elixir idioms emphasized: **changelog + docs + SECURITY** as user spine; **mix/test** as proof spine; human GA as **sampled** truth for MUA and live IdP drift.

</specifics>

<deferred>

## Deferred ideas

- Public-facing “deployment checklist” page distillation from GA matrix — post-v1.4 marketing/docs (**REQUIREMENTS.md** “Future”)
- Optional scheduled **GitHub Actions** with manual approval for Litmus-class runs — only if maintainer burden warrants automation beyond current CI

### Reviewed todos (not folded)

- None — `todo.match-phase` returned no matches.

</deferred>

---

*Phase: 42-human-ga-matrix-evidence*  
*Context gathered: 2026-04-20*
