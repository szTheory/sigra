---
phase: 238-tag-guard-then-tag-deletion
plan: 01
requirement: REL-01
decision: D-17
kind: outward-facing-settings-change-record
---

# Tag ruleset surface — pre-change record and revert value

This file exists so the ruleset-surface change this phase performs is reversible by a
**recorded, known value** rather than by a reconstruction. It is committed **before** any
`POST`/`DELETE` against `repos/szTheory/sigra/rulesets` is issued.

The change itself is authorized by task 1 of this plan (operator answer: **authorized**,
2026-09-16) and by `238-CONTEXT.md` D-01, D-03 and D-17: D-01 records that the harness
permission classifier blocked exactly this call class during discussion, so the write
authorization had to be settled as an explicit execution-time checkpoint rather than assumed;
D-03 specifies the shape of the sibling ruleset this phase creates; D-17 requires this
pre-change record to exist, committed, before the first write.

## PRE-CHANGE STATE — the value to revert to

Captured live at **2026-09-16T19:21:03Z**, before any mutation.

### `gh api repos/szTheory/sigra/rulesets` (the list call)

```json
[
    {
        "id": 14941512,
        "name": "main",
        "target": "branch",
        "source_type": "Repository",
        "source": "szTheory/sigra",
        "enforcement": "active",
        "node_id": "RRS_lACqUmVwb3NpdG9yec5H-MzEzgDj_Ug",
        "_links": {
            "self": {
                "href": "https://api.github.com/repos/szTheory/sigra/rulesets/14941512"
            },
            "html": {
                "href": "https://github.com/szTheory/sigra/rules/14941512"
            }
        },
        "created_at": "2026-04-10T22:16:26.406-04:00",
        "updated_at": "2026-04-10T22:18:58.086-04:00"
    }
]
```

Exactly one ruleset exists: `main`, id `14941512`. The list endpoint's payload omits
`conditions`, `rules`, `bypass_actors` and `current_user_can_bypass` — see the by-id call below
for those fields.

### `gh api repos/szTheory/sigra/rulesets/14941512` (the by-id call)

```json
{
    "id": 14941512,
    "name": "main",
    "target": "branch",
    "source_type": "Repository",
    "source": "szTheory/sigra",
    "enforcement": "active",
    "conditions": {
        "ref_name": {
            "exclude": [],
            "include": [
                "~DEFAULT_BRANCH"
            ]
        }
    },
    "rules": [
        {
            "type": "deletion"
        },
        {
            "type": "non_fast_forward"
        },
        {
            "type": "pull_request",
            "parameters": {
                "required_approving_review_count": 0,
                "dismiss_stale_reviews_on_push": false,
                "required_reviewers": [],
                "require_code_owner_review": false,
                "require_last_push_approval": false,
                "required_review_thread_resolution": true,
                "require_extra_approval_for_unattributed_changes": true,
                "allowed_merge_methods": [
                    "merge",
                    "squash",
                    "rebase"
                ]
            }
        },
        {
            "type": "required_status_checks",
            "parameters": {
                "strict_required_status_checks_policy": true,
                "do_not_enforce_on_create": false,
                "required_status_checks": [
                    {
                        "context": "Library tests"
                    },
                    {
                        "context": "Example unit smoke (ExUnit + ConnTest)"
                    },
                    {
                        "context": "Install smoke (fresh phx.new + sigra.install)"
                    },
                    {
                        "context": "Example HTTP smoke (boot + curl critical routes)"
                    },
                    {
                        "context": "Example Playwright smoke (full lifecycle)"
                    }
                ]
            }
        }
    ],
    "node_id": "RRS_lACqUmVwb3NpdG9yec5H-MzEzgDj_Ug",
    "created_at": "2026-04-10T22:16:26.406-04:00",
    "updated_at": "2026-04-10T22:18:58.086-04:00",
    "bypass_actors": [],
    "current_user_can_bypass": "never",
    "_links": {
        "self": {
            "href": "https://api.github.com/repos/szTheory/sigra/rulesets/14941512"
        },
        "html": {
            "href": "https://github.com/szTheory/sigra/rules/14941512"
        }
    }
}
```

## Revert value and scope

The revert operation for this phase is a `DELETE` against `repos/szTheory/sigra/rulesets/{id}`
for whichever new ruleset id this phase's writes create — never `14941512`. `14941512` is
**never a write target** anywhere in this phase: it is not read-modify-written, not patched,
and not deleted. If everything this phase creates is deleted, the live ruleset list returns to
exactly the single-entry payload recorded above, byte-for-byte.

No home-directory prefix or token material appears in this record — both payloads above were
captured via `gh api`, which reads local credentials without echoing them, and neither payload
contains a filesystem path.
