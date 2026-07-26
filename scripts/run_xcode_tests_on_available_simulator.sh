#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

simulators_json="$(xcrun simctl list devices available --json)"

device_name="$(
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
puts candidate.fetch("name")
RUBY
)"

echo "Running tests on simulator: ${device_name}"

xcodebuild test \
  -project "$ROOT_DIR/mdreader.xcodeproj" \
  -scheme mdreader \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=${device_name}" \
  -derivedDataPath "$ROOT_DIR/DerivedData" \
  CODE_SIGNING_ALLOWED=NO
