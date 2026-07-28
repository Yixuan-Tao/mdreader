#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

simulators_json="$(xcrun simctl list devices available --json)"

device_udid="$(
  SIMULATORS_JSON="$simulators_json" ruby <<'RUBY'
require "json"

input = ENV.fetch("SIMULATORS_JSON")
devices = JSON.parse(input).fetch("devices")

candidate = devices.values.flatten.find do |device|
  device["isAvailable"] &&
    device["name"].to_s.include?("iPhone") &&
    device["state"] != "Shutdown-Unavailable"
end

abort "No available iPhone Simulator found" unless candidate
puts candidate.fetch("udid")
RUBY
)"

device_name="$(
  SIMULATORS_JSON="$simulators_json" DEVICE_UDID="$device_udid" ruby <<'RUBY'
require "json"

devices = JSON.parse(ENV.fetch("SIMULATORS_JSON")).fetch("devices")
candidate = devices.values.flatten.find { |device| device["udid"] == ENV.fetch("DEVICE_UDID") }
puts candidate ? candidate.fetch("name") : ENV.fetch("DEVICE_UDID")
RUBY
)"

echo "Running tests on simulator: ${device_name} (${device_udid})"

xcrun simctl boot "$device_udid" 2>/dev/null || true
xcrun simctl bootstatus "$device_udid" -b || sleep 15

rm -rf "$ROOT_DIR/TestResults.xcresult"
rm -f "$ROOT_DIR/xcodebuild-test.log"
rm -f "$ROOT_DIR/xcodebuild-test.status"

set +e
xcodebuild test \
  -project "$ROOT_DIR/mdreader.xcodeproj" \
  -scheme mdreader \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "id=${device_udid}" \
  -destination-timeout 120 \
  -resultBundlePath "$ROOT_DIR/TestResults.xcresult" \
  -derivedDataPath "$ROOT_DIR/DerivedData" > "$ROOT_DIR/xcodebuild-test.log" 2>&1 &
test_pid="$!"
test_timeout_seconds="${XCODEBUILD_TEST_TIMEOUT_SECONDS:-360}"
test_deadline="$((SECONDS + test_timeout_seconds))"

while kill -0 "$test_pid" 2>/dev/null; do
  if (( SECONDS >= test_deadline )); then
    echo "XCTest timed out after ${test_timeout_seconds} seconds."
    kill "$test_pid" 2>/dev/null || true
    sleep 5
    kill -9 "$test_pid" 2>/dev/null || true
    wait "$test_pid" 2>/dev/null
    echo 124 > "$ROOT_DIR/xcodebuild-test.status"
    break
  fi

  sleep 5
done

if [[ -f "$ROOT_DIR/xcodebuild-test.status" ]]; then
  test_status="$(cat "$ROOT_DIR/xcodebuild-test.status")"
else
  wait "$test_pid"
  test_status="$?"
fi
set -e

if [[ "$test_status" -ne 0 ]]; then
  echo "XCTest failed with exit code ${test_status}. Last 200 xcodebuild log lines:"
  tail -n 200 "$ROOT_DIR/xcodebuild-test.log"
  failure_summary="$(tail -n 80 "$ROOT_DIR/xcodebuild-test.log" | awk '{ if (length($0) > 240) print substr($0, 1, 240) "..."; else print }')"
  if [[ -z "$failure_summary" ]]; then
    failure_summary="$(tail -n 40 "$ROOT_DIR/xcodebuild-test.log")"
  fi

  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    escaped_failure_summary="${failure_summary//'%'/'%25'}"
    escaped_failure_summary="${escaped_failure_summary//$'\n'/'%0A'}"
    escaped_failure_summary="${escaped_failure_summary//$'\r'/'%0D'}"
    echo "::error title=XCTest failure::${escaped_failure_summary}"
  fi

  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "## XCTest failure"
      echo
      echo "Exit code: ${test_status}"
      echo
      echo '```text'
      echo "$failure_summary"
      echo '```'
    } >> "$GITHUB_STEP_SUMMARY"
  fi

  exit "$test_status"
fi
