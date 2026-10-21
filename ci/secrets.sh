#!/usr/bin/env bash
# Does Dagger itself keep a secret out of stdout and its progress log? The value is
# generated here rather than taken from GitHub secrets, so GitHub's own log masking does not
# know it and cannot hide a leak.
source "$(dirname "$0")/lib.sh"
preflight

PROBE_SECRET="probe$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')"
export PROBE_SECRET

out=$(dag secret "container | from alpine:3.22 | with-secret-variable S env://PROBE_SECRET | with-exec -- sh -c 'echo stdout=\$S; echo stderr=\$S >&2' | stdout")

grep -qF "$PROBE_SECRET" <<< "$out" &&
  fail "secret masking" "The plaintext secret appeared in the pipeline's stdout."
grep -qF "$PROBE_SECRET" "$LOG_DIR/secret.log" &&
  fail "secret masking" "The plaintext secret appeared in Dagger's progress log (the container's stderr)."
[[ "$out" == "stdout=***" ]] ||
  fail "secret masking" "No plaintext leak, but stdout was '$out' instead of 'stdout=***': was the secret even set?"
pass "secret masking" "The secret was replaced by *** in both stdout and the progress log."
