#!/usr/bin/env bash
# Does a step cached in an earlier workflow run get reused in this one? The pipeline is
# identical in every run, and prints the time it actually executed: a timestamp older than
# this job means the result came from an earlier run's cache.
#
# Also appends this run to a cache volume, to see whether cache volumes survive with it.
#
# Usage: cache-across-runs.sh <label> [<restored: true|false>]
source "$(dirname "$0")/lib.sh"
preflight
label=$1
restored=${2:-n/a}

job_start=$(now)
executed_at=$(dag across "container | from alpine:3.22 | with-env-variable PROBE_KEY across-runs-v1 | with-exec -- sh -c 'sleep 20; date +%s' | stdout")
secs=$(( $(now) - job_start ))

runs_seen=$(dag volume "container | from alpine:3.22 | with-mounted-cache /c \$(cache-volume across-runs-v1) | with-env-variable BUST $GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT | with-exec -- sh -c 'echo $GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT >> /c/runs; wc -l < /c/runs' | stdout")
detail="state restored: $restored. Cache volume has seen ${runs_seen// /} run(s), this one included."

if (( executed_at < job_start )); then
  pass "cache across runs ($label)" "HIT: result executed $(( job_start - executed_at ))s before this job started, returned in ${secs}s. $detail"
elif [[ "$restored" == "false" ]]; then
  summary "### ⚪ BASELINE: cache across runs ($label)" "" "No saved engine state to restore, so this run seeds the cache. Re-run the workflow to measure. $detail" ""
else
  fail "cache across runs ($label)" "MISS: the step re-executed in this job (${secs}s). $detail"
fi
