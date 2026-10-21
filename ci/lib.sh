# shellcheck shell=bash
# Shared helpers for the probe jobs. Each job asks one question and ends with a single
# PASS or FAIL line in the step summary that says what was measured, so a red job reads
# as "this does not work here, because..." rather than as a stack trace to dig through.
set -Eeuo pipefail

: "${GITHUB_STEP_SUMMARY:=/dev/stderr}"

# fail and dag exit with this code once they have reported, so the trap below stays quiet
# for failures that already explain themselves.
REPORTED=3

# set -e would otherwise end a job silently on any command we did not anticipate failing.
on_unexpected_error() {
  local code=$? line=$1 cmd=$2
  (( code == REPORTED )) && exit "$REPORTED"
  summary "### ❌ FAIL: unexpected error" "" "\`$cmd\` exited $code at ${BASH_SOURCE[1]}:$line." ""
  echo "::error title=unexpected error::'$cmd' exited $code at ${BASH_SOURCE[1]}:$line"
  exit "$REPORTED"
}
trap 'on_unexpected_error $LINENO "$BASH_COMMAND"' ERR
EXPECTED_DAGGER_VERSION="v$(sed -n 's/^dagger = "\(.*\)"/\1/p' mise.toml)"
# Upper bound on any single dagger call. A cold engine start takes ~20s on ubuntu-latest;
# the limit exists so a hung CLI ends in a FAIL that says so, instead of a cancelled job.
DAGGER_CALL_TIMEOUT_SECONDS=${DAGGER_CALL_TIMEOUT_SECONDS:-300}
LOG_DIR="${RUNNER_TEMP:-/tmp}/probe-logs"
mkdir -p "$LOG_DIR"

summary() { printf '%s\n' "$@" >> "$GITHUB_STEP_SUMMARY"; }

pass() {
  summary "### ✅ PASS: $1" "" "$2" ""
  echo "PASS: $1: $2"
}

# A measurement worth keeping that is not itself a verdict, such as a size or a duration.
note() {
  summary "$1" ""
  echo "NOTE: $1"
}

# Neither pass nor fail: the run could not answer the question yet, and says why.
baseline() {
  summary "### ⚪ BASELINE: $1" "" "$2" ""
  echo "BASELINE: $1: $2"
}

fail() {
  summary "### ❌ FAIL: $1" "" "$2" ""
  echo "::error title=$1::$2"
  exit "$REPORTED"
}

# Runs a Dagger shell pipeline and prints its stdout. On failure, the job fails with the
# tail of Dagger's own log in the summary, so the reason is visible without opening logs.
dag() {
  local name=$1 pipeline=$2
  local log="$LOG_DIR/$name.log" code=0
  timeout "$DAGGER_CALL_TIMEOUT_SECONDS" dagger --progress=plain -c "$pipeline" 2> "$log" < /dev/null || code=$?
  if (( code == 124 )); then
    fail "dagger pipeline '$name' hung" "No result after ${DAGGER_CALL_TIMEOUT_SECONDS}s (DAGGER_CALL_TIMEOUT_SECONDS). Last log line: $(tail -n 1 "$log")"
  elif (( code != 0 )); then
    summary "### ❌ FAIL: dagger pipeline '$name' errored" "" '```' "$(tail -n 25 "$log")" '```'
    echo "::error title=dagger pipeline '$name' errored::see the step summary for Dagger's log tail"
    exit "$REPORTED"
  fi
}

# Every job first proves it is testing the Dagger it claims to, with the nag silenced.
preflight() {
  local version_output actual code=0
  version_output=$(timeout "$DAGGER_CALL_TIMEOUT_SECONDS" dagger version 2>&1 < /dev/null) || code=$?
  (( code == 124 )) &&
    fail "dagger version" "'dagger version' hung for ${DAGGER_CALL_TIMEOUT_SECONDS}s. It needs no engine, so the CLI itself is stuck on this runner."
  (( code == 0 )) ||
    fail "dagger version" "'dagger version' itself failed (exit $code): $version_output"
  actual=$(awk '{print $2}' <<< "$version_output")
  [[ "$actual" == "$EXPECTED_DAGGER_VERSION" ]] ||
    fail "dagger version" "Expected $EXPECTED_DAGGER_VERSION (pinned in mise.toml), got '$actual'. Is mise on PATH?"
  [[ -n "${DAGGER_NO_NAG:-}" ]] ||
    fail "mise env" "DAGGER_NO_NAG is unset: mise-action did not export mise.toml [env]."
}

now() { date +%s; }
