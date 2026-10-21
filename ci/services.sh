#!/usr/bin/env bash
# Can a pipeline reach a service container that Dagger starts, by hostname, on this runner?
source "$(dirname "$0")/lib.sh"
preflight

start=$(now)
out=$(dag service "container | from alpine:3.22 | with-service-binding web \$(container | from nginx:1.29-alpine | with-exposed-port 80 | as-service) | with-exec -- wget -qO- http://web | stdout")
secs=$(( $(now) - start ))

grep -q "Welcome to nginx" <<< "$out" ||
  fail "service binding" "Reached http://web but did not get the nginx welcome page. First line: $(head -n 1 <<< "$out")"
pass "service binding" "alpine fetched the nginx welcome page from a Dagger service at http://web in ${secs}s."
