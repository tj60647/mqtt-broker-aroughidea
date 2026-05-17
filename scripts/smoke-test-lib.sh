#!/bin/bash
set -euo pipefail

cleanup_container() {
  local container_name="$1"
  docker rm -f "$container_name" > /dev/null 2>&1 || true
}

wait_for_subscriber_ready() {
  local container_name="$1"
  local label="$2"
  local startup_delay="${SMOKE_SUBSCRIBER_START_DELAY:-2}"

  sleep "$startup_delay"
  if docker ps --format '{{.Names}}' | grep -qx "$container_name"; then
    return 0
  fi

  echo "❌ FAILURE: $label subscriber container is not running."
  docker logs "$container_name" 2>&1 || true
  return 1
}

wait_for_subscriber_message() {
  local container_name="$1"
  local expected_message="$2"
  local label="$3"
  local check_attempts="${SMOKE_READY_CHECK_ATTEMPTS:-5}"
  local check_delay="${SMOKE_READY_CHECK_DELAY:-1}"
  local attempt

  for attempt in $(seq 1 "$check_attempts"); do
    if docker logs "$container_name" 2>&1 | grep -Fq "$expected_message"; then
      return 0
    fi
    sleep "$check_delay"
  done

  echo "❌ FAILURE: $label subscriber did not receive readiness probe message."
  docker logs "$container_name" 2>&1 | tail -n 50 || true
  return 1
}

publish_with_retry() {
  local max_attempts="${SMOKE_PUBLISH_ATTEMPTS:-5}"
  local retry_delay="${SMOKE_PUBLISH_RETRY_DELAY:-1}"
  local attempt=1
  local output

  while [ "$attempt" -le "$max_attempts" ]; do
    if output="$("$@" 2>&1)"; then
      [ -n "$output" ] && printf '%s\n' "$output"
      return 0
    fi

    printf '%s\n' "$output" >&2

    if ! printf '%s\n' "$output" | grep -qi 'Bad file descriptor'; then
      return 1
    fi

    if [ "$attempt" -lt "$max_attempts" ]; then
      echo "   Publish attempt $attempt/$max_attempts hit transient client error, retrying..."
      sleep "$retry_delay"
    fi
    attempt=$((attempt + 1))
  done

  return 1
}
