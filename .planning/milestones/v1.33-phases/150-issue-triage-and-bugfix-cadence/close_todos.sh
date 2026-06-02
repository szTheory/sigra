#!/bin/bash
PHASE_NUM="150"
PENDING_DIR=".planning/todos/pending"
COMPLETED_DIR=".planning/todos/completed"
mkdir -p "$COMPLETED_DIR"

CLOSED=()
for TODO_FILE in "$PENDING_DIR"/*.md; do
  [ -f "$TODO_FILE" ] || continue
  RP=$(awk '/^---/{c++;next} c==1 && /^resolves_phase:/{print $2;exit} c==2{exit}' "$TODO_FILE" 2>/dev/null || true)
  if [ "$RP" = "$PHASE_NUM" ] || [ "$RP" = "\"$PHASE_NUM\"" ]; then
    mv "$TODO_FILE" "$COMPLETED_DIR/"
    CLOSED+=("$(basename "$TODO_FILE")")
  fi
done

if [ ${#CLOSED[@]} -gt 0 ]; then
  gsd-sdk query commit "docs(phase-150): auto-close ${#CLOSED[@]} todo(s) resolved by this phase" --files .planning/todos/completed/ .planning/STATE.md || true
  echo "◆ Closed ${#CLOSED[@]} todo(s) resolved by Phase 150:"
  for f in "${CLOSED[@]}"; do echo "  ✓ $f"; done
fi