#!/usr/bin/env bash
# Runs the engine ourselves with its state directory on the host, so the state can be
# carried between workflow runs with actions/cache. A hosted runner is a fresh VM each time,
# and the engine Dagger provisions on its own keeps that state inside the VM.
#
# Usage: persisted-engine.sh start|stop
source "$(dirname "$0")/lib.sh"

STATE_DIR=/var/lib/probe-dagger
ARCHIVE="$RUNNER_TEMP/dagger-state.tar.zst"
ENGINE=probe-engine

case $1 in
start)
  sudo mkdir -p "$STATE_DIR"
  if [[ -f "$ARCHIVE" ]]; then
    t=$(now); sudo tar --zstd -xf "$ARCHIVE" -C "$STATE_DIR"
    note "Restored engine state ($(du -h "$ARCHIVE" | cut -f1) compressed) in $(( $(now) - t ))s."
  fi
  docker run -d --name "$ENGINE" --privileged -v "$STATE_DIR:/var/lib/dagger" \
    "registry.dagger.io/engine:$EXPECTED_DAGGER_VERSION" > /dev/null
  echo "_EXPERIMENTAL_DAGGER_RUNNER_HOST=docker-container://$ENGINE" >> "$GITHUB_ENV"
  ;;
stop)
  # A graceful stop lets the engine flush its metadata, so the archive is not torn.
  docker stop -t 60 "$ENGINE" > /dev/null
  t=$(now)
  sudo tar --zstd -cf "$ARCHIVE" -C "$STATE_DIR" .
  sudo chown "$(id -u):$(id -g)" "$ARCHIVE"
  note "Archived engine state: $(du -h "$ARCHIVE" | cut -f1) compressed in $(( $(now) - t ))s."
  ;;
*)
  fail "persisted-engine.sh" "Unknown command '$1'. Valid commands: start, stop."
  ;;
esac
