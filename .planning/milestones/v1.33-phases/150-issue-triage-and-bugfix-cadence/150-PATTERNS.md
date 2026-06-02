# Phase 150: Issue Triage and Bugfix Cadence - Pattern Map

**Mapped:** 2024-06-01
**Files analyzed:** 3
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `MAINTAINING.md` | documentation | manual process | `docs/release-runbook-v1-0.md` | exact |
| `.github/ISSUE_TEMPLATE/bug_report.md` | template | issue reporting | `docs/release-runbook-v1-0.md` | role-match |

## Pattern Assignments

### `MAINTAINING.md` (documentation, manual process)

**Analog:** `docs/release-runbook-v1-0.md`

**Bugfix Triage Policy Pattern** (lines 103-120):
```markdown
## First 14 Days Hotfix Policy

Scope: first 14 calendar days after public Hex publish of `1.32.0`.

Severity classes:

- `P0`: security-sensitive auth/session/token/MFA/passkey regression.
- `P1`: install/compile/generated-host boot/docs-source-link/package-truth blocker.
- `P2`: serious adopter-blocking regression without workaround.
- `P3`: non-blocking bug or docs polish.

Triage timing:

- `P0` and `P1`: same business day.
- `P2`: within 24 hours.
- `P3`: next planned patch window.
```

**Patch Decision Boundaries Pattern** (lines 135-144):
```markdown
Patch decision boundaries:

- Immediate patch/recovery consideration: `P0`, `P1`, and `P2` without viable workaround.
- `P3` or issues with acceptable workaround: batch into planned patch release.
- Deferred feature ideas remain out of scope during this 14-day window.

Communication posture:

- Keep updates factual and version-specific.
- State impact, workaround status, and next decision checkpoint.
```

---

### `.github/ISSUE_TEMPLATE/bug_report.md` (template, issue reporting)

**Analog:** `docs/release-runbook-v1-0.md` (hotfix intake requirements)

**Minimum Evidence Pattern** (lines 128-133):
```markdown
Minimum evidence for every hotfix intake:

- Repro command and ref.
- Failing run URL or log.
- Affected version(s).
- Workaround status (available/unavailable).
```

---

### `guides/introduction/upgrading-to-v1.x.md` (documentation, process guide)

**Analog:** `guides/introduction/upgrading-to-v1.1.md`

**Template Changes Communication Pattern** (lines 47-53):
```markdown
## 6. Know what changes in the generated app

After a successful upgrade, expect:

- organizations-aware generated surface in the default install posture
- passkey routes under `/users/log_in/passkey`, `/users/mfa/passkey`, and `/users/settings/mfa/passkeys`
- login pages that can present passkey-primary alongside password and magic-link fallback
```

**Upgrade Command Pattern** (lines 28-36):
```markdown
## 3. Run the schema upgrade

For the zero-org path:

    mix sigra.upgrade --yes

For the personal-org backfill path:

    mix sigra.upgrade --backfill-personal-orgs --yes
```

**Analog:** `UPGRADE-v1.2.md`

**Forward Contract / Reserved Fields Pattern** (lines 6-12):
```markdown
## Reserved fields in v1.1

Sigra v1.1 reserves the following fields in generated code so the
v1.2 upgrade can be purely additive:

- `%<YourApp>.Accounts.Scope{impersonating_from: nil}` — populated
  by v1.2 `Sigra.Plug.Impersonation`. Type: `%User{} | nil`.
```

## Shared Patterns

### Communication Posture
**Source:** `docs/release-runbook-v1-0.md`
**Apply to:** Maintainer responses to issues and release notes
```markdown
- Keep updates factual and version-specific.
- State impact, workaround status, and next decision checkpoint.
- Avoid implying unsupported guarantees beyond documented release evidence.
```

## Metadata

**Analog search scope:** `MAINTAINING.md`, `.github/`, `docs/`, `guides/introduction/`
**Files scanned:** 4
**Pattern extraction date:** 2024-06-01
