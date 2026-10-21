#!/usr/bin/env bash
# Does a cache volume keep its contents between two separate pipelines in the same job?
# Each call busts the exec cache, so both really run and append to the volume.
source "$(dirname "$0")/lib.sh"
preflight

append() {
  dag "volume-$1" "container | from alpine:3.22 | with-mounted-cache /c \$(cache-volume in-job-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT) | with-env-variable BUST $1 | with-exec -- sh -c 'echo $1 >> /c/log; wc -l < /c/log' | stdout"
}

first=$(append one); second=$(append two)
[[ "${second// /}" == "2" ]] ||
  fail "cache volume within a job" "The second pipeline saw ${second// /} line(s) in the volume, expected 2 (first saw ${first// /})."
pass "cache volume within a job" "The second pipeline saw both writes: the volume persists across pipelines in one engine."
