#!/usr/bin/env bash
# Does a second identical pipeline in the same job reuse the first one's result? The busting
# value is unique per run attempt, so the first call is always fresh and only the second can hit.
source "$(dirname "$0")/lib.sh"
preflight

pipeline="container | from alpine:3.22 | with-env-variable BUST $GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT | with-exec -- sh -c 'sleep 20; date +%s%N' | stdout"

start=$(now); first=$(dag first "$pipeline"); first_secs=$(( $(now) - start ))
start=$(now); second=$(dag second "$pipeline"); second_secs=$(( $(now) - start ))

[[ "$first" == "$second" ]] ||
  fail "cache within a job" "MISS: the second run re-executed (outputs $first vs $second, ${first_secs}s then ${second_secs}s)."
pass "cache within a job" "HIT: identical output, ${first_secs}s fresh then ${second_secs}s cached (the step sleeps 20s)."
