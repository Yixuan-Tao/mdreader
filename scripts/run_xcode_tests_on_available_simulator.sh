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
sleep 15

rm -rf "$ROOT_DIR/TestResults.xcresult"

xcodebuild test \
  -project "$ROOT_DIR/mdreader.xcodeproj" \
  -scheme mdreader \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "id=${device_udid}" \
  -destination-timeout 120 \
  -resultBundlePath "$ROOT_DIR/TestResults.xcresult" \
  -derivedDataPath "$ROOT_DIR/DerivedData" \
  CODE_SIGNING_ALLOWED=NO
