#!/bin/bash
echo "=== INIT ==="
gsd-sdk query init.progress
echo "=== DISCUSS ==="
gsd-sdk query config-get workflow.discuss_mode 2>/dev/null || echo "discuss"
echo "=== ROADMAP ==="
gsd-sdk query roadmap.analyze
echo "=== STATE ==="
gsd-sdk query state-snapshot
echo "=== PROGRESS_BAR ==="
gsd-sdk query progress.bar --raw
echo "=== UAT_AUDIT ==="
gsd-sdk query audit-uat --raw 2>/dev/null
echo "=== PENDING_TODOS ==="
ls -1 .planning/todos/pending/*.md 2>/dev/null | wc -l
echo "=== DEBUG_SESSIONS ==="
(ls -1 .planning/debug/*.md 2>/dev/null || true) | grep -v resolved | wc -l
