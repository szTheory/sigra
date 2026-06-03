#!/bin/bash
REGRESSION_FILES=$(find .planning/phases/ -name "*-VERIFICATION.md" ! -path "*150*" 2>/dev/null | xargs grep -hoE "test/[^ ]*_test\.exs" | sort -u | tr '\n' ' ')
if [ -n "$REGRESSION_FILES" ]; then
  mix test $REGRESSION_FILES
else
  echo "No regression files found from prior verifications."
fi