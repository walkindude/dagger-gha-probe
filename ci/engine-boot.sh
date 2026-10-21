#!/usr/bin/env bash
# Can Dagger provision its engine on this runner and run one container, and how long does
# a cold start take? Cold means the engine image is pulled and booted from scratch.
source "$(dirname "$0")/lib.sh"
preflight

start=$(now)
out=$(dag boot "container | from alpine:3.22 | with-exec -- echo hello | stdout")
secs=$(( $(now) - start ))

[[ "$out" == "hello" ]] || fail "engine boot" "Pipeline ran but printed '$out' instead of 'hello'."
pass "engine boot" "Engine provisioned and ran alpine in ${secs}s from cold (image pull + engine boot + run)."
