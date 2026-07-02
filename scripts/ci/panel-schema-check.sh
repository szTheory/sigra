#!/usr/bin/env bash
# Phase 209-02: Persona-JTBD panel schema validator.
# Usage: bash scripts/ci/panel-schema-check.sh .planning/uat-evidence/v1.42-persona-jtbd/<surface>.md
# Validates:
#   - YAML frontmatter parses (python3 yaml)
#   - surface == filename stem
#   - rubric_version == "1.0"
#   - disposition is one of clean/actionable/blocked
#   - verdicts has all 3 lens keys each with all 3 question keys
#   - findings is a list
#   - markdown body has all 3 lens headings and 3 question subheadings per lens
#   - no bare 0/1/2 in 4th pipe-delimited column of any table row (monotonic-guard false-match prohibition)
set -euo pipefail

FILE="${1:-}"
if [[ -z "$FILE" ]]; then
  echo "panel-schema-check: FAIL: no file argument supplied" >&2
  exit 1
fi

if [[ ! -f "$FILE" ]]; then
  echo "panel-schema-check: FAIL: file not found: $FILE" >&2
  exit 1
fi

STEM=$(basename "$FILE" .md)

fail() {
  echo "panel-schema-check: FAIL [$STEM]: $*" >&2
  exit 1
}

info() {
  echo "panel-schema-check: $*"
}

# ────────────────────────────────────────────────
# 1. Extract YAML frontmatter and markdown body
# ────────────────────────────────────────────────
python3 - "$FILE" "$STEM" <<'PYEOF'
import sys, re, yaml

filepath = sys.argv[1]
stem     = sys.argv[2]

content = open(filepath, encoding="utf-8").read()

# Split frontmatter
fm_match = re.match(r'^---\n(.*?)\n---\n(.*)', content, re.DOTALL)
if not fm_match:
    print(f"panel-schema-check: FAIL [{stem}]: cannot find YAML frontmatter delimiters (--- ... ---)")
    sys.exit(1)

fm_text = fm_match.group(1)
body    = fm_match.group(2)

try:
    fm = yaml.safe_load(fm_text)
except Exception as e:
    print(f"panel-schema-check: FAIL [{stem}]: frontmatter YAML parse error: {e}")
    sys.exit(1)

if not isinstance(fm, dict):
    print(f"panel-schema-check: FAIL [{stem}]: frontmatter must be a YAML mapping")
    sys.exit(1)

# ── surface
if fm.get("surface") != stem:
    print(f"panel-schema-check: FAIL [{stem}]: surface '{fm.get('surface')}' != filename stem '{stem}'")
    sys.exit(1)

# ── rubric_version
if str(fm.get("rubric_version", "")) != "1.0":
    print(f"panel-schema-check: FAIL [{stem}]: rubric_version must be '1.0', got '{fm.get('rubric_version')}'")
    sys.exit(1)

# ── disposition
valid_dispositions = {"clean", "actionable", "blocked"}
if fm.get("disposition") not in valid_dispositions:
    print(f"panel-schema-check: FAIL [{stem}]: disposition '{fm.get('disposition')}' must be one of {sorted(valid_dispositions)}")
    sys.exit(1)

# ── verdicts
required_lenses    = {"platform_admin", "support_investigator", "org_admin"}
required_questions = {"earning_its_place", "ia_muddy", "redundant_coherent_surprising"}
valid_verdicts     = {"keep", "tighten", "kill"}

verdicts = fm.get("verdicts")
if not isinstance(verdicts, dict):
    print(f"panel-schema-check: FAIL [{stem}]: 'verdicts' must be a mapping")
    sys.exit(1)

missing_lenses = required_lenses - set(verdicts.keys())
if missing_lenses:
    print(f"panel-schema-check: FAIL [{stem}]: verdicts missing lens keys: {sorted(missing_lenses)}")
    sys.exit(1)

for lens in required_lenses:
    qs = verdicts.get(lens)
    if not isinstance(qs, dict):
        print(f"panel-schema-check: FAIL [{stem}]: verdicts.{lens} must be a mapping")
        sys.exit(1)
    missing_qs = required_questions - set(qs.keys())
    if missing_qs:
        print(f"panel-schema-check: FAIL [{stem}]: verdicts.{lens} missing question keys: {sorted(missing_qs)}")
        sys.exit(1)
    for q, v in qs.items():
        if q in required_questions and v not in valid_verdicts:
            print(f"panel-schema-check: FAIL [{stem}]: verdicts.{lens}.{q} = '{v}' must be one of {sorted(valid_verdicts)}")
            sys.exit(1)

# ── findings
findings = fm.get("findings")
if not isinstance(findings, list):
    print(f"panel-schema-check: FAIL [{stem}]: 'findings' must be a list (use '[]' for clean surfaces)")
    sys.exit(1)

# ── markdown body: 3 lens sections
required_lens_headings = [
    "## Platform Admin Lens",
    "## Support Investigator Lens",
    "## Org Admin Lens",
]
for heading in required_lens_headings:
    if heading not in body:
        print(f"panel-schema-check: FAIL [{stem}]: markdown body missing lens heading: '{heading}'")
        sys.exit(1)

# ── markdown body: 3 question subheadings per lens (must appear 3 times each)
required_question_headings = [
    "### Earning its place?",
    "### Is the IA muddy?",
    "### Redundant / coherent / least-surprising?",
]
for heading in required_question_headings:
    count = body.count(heading)
    if count < 3:
        print(f"panel-schema-check: FAIL [{stem}]: markdown body has {count}/3 occurrences of question heading: '{heading}'")
        sys.exit(1)

# ── forced-finding floor: every (lens x question) subsection must end with a
#    finding anchor OR the literal NONE token
# Split body by lens section
lens_sections = re.split(r'(?=^## .+ Lens)', body, flags=re.MULTILINE)
NONE_TOKEN = "NONE — searched for:"
for section in lens_sections:
    if not section.strip():
        continue
    # Split by question subheading
    q_sections = re.split(r'(?=^### )', section, flags=re.MULTILINE)
    for qs in q_sections:
        if not qs.strip().startswith("###"):
            continue
        # Must contain a finding reference (file: or component:) or NONE token
        if NONE_TOKEN not in qs:
            # Check for a DOM anchor (file:line pattern or component name)
            if not re.search(r'`[a-z_]+_live\.ex:\d+`|`components\.ex:\d+`|`[a-zA-Z_.]+\.ex:\d+`', qs):
                # Check for generic finding indicators
                if not re.search(r'`[^`]+`|file:|:line|\*\*Finding\*\*', qs):
                    print(f"panel-schema-check: WARN [{stem}]: question section may lack DOM anchor or NONE token — manual review required")

print(f"panel-schema-check: PASS [{stem}]: frontmatter valid")
PYEOF

# ────────────────────────────────────────────────
# 2. Column-4 integer prohibition
#    Reject any table row where the 4th pipe-delimited field is a bare 0, 1, or 2.
#    This protects against false-matching the quality-ledger monotonic guard.
# ────────────────────────────────────────────────
# awk -F'|' on lines starting with '|': extract field 4 (index 4 in 1-based awk)
BAD_COLS=$(awk -F'|' '
  /^\|/ {
    f = $4
    gsub(/^[ \t]+|[ \t]+$/, "", f)
    if (f ~ /^[012]$/) {
      print NR ": " $0
    }
  }
' "$FILE")

if [[ -n "$BAD_COLS" ]]; then
  echo "panel-schema-check: FAIL [$STEM]: bare 0/1/2 found in 4th pipe column (monotonic-guard false-match prohibition):" >&2
  echo "$BAD_COLS" >&2
  exit 1
fi

info "PASS [$STEM]: column-4 integer check clean"
info "PASS [$STEM]: all checks passed"
