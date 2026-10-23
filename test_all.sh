#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
root_dir="$PWD"

command_log="$(mktemp "${TMPDIR:-/tmp}/cross-bluetooth-tests.XXXXXX")"
trap 'rm -f "$command_log"' EXIT

run_logged() {
  local status
  if "$@" 2>&1 | tee "$command_log" | awk '
    /^[0-9][0-9]:[0-9][0-9] / ||
    /^Test (Suite|Case|suite|case) / ||
    /^Testing (started|passed|failed)/ ||
    /^[[:space:]]*Executed [0-9]+ tests?/ ||
    /^\*\* TEST / {
      print
      fflush()
    }
  '; then
    return 0
  else
    status=$?
    printf '\nCommand failed (exit %s):' "$status" >&2
    printf ' %q' "$@" >&2
    printf '\nFull output:\n' >&2
    cat "$command_log" >&2
    return "$status"
  fi
}

if command -v fvm >/dev/null 2>&1; then
  flutter=(fvm flutter)
elif command -v flutter >/dev/null 2>&1; then
  flutter=(flutter)
else
  echo "Flutter is required. Install FVM or add flutter to PATH." >&2
  exit 1
fi

if [[ "$(uname -s)" != Darwin ]]; then
  echo "Running all tests requires macOS with Xcode and an iOS simulator." >&2
  exit 1
fi

# Match Flutter's default JDK selection when using Android Studio on macOS.
if [[ -z "${JAVA_HOME:-}" && -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi

if [[ -n "${IOS_DESTINATION:-}" ]]; then
  ios_destination="$IOS_DESTINATION"
else
  simulator_id="$(
    xcrun simctl list devices available |
      sed -nE '/iPhone|iPad/s/.*\(([[:xdigit:]-]{36})\).*/\1/p' |
      sed -n '1p'
  )"
  if [[ -z "$simulator_id" ]]; then
    echo "No iOS simulator is available. Install one in Xcode or set IOS_DESTINATION." >&2
    exit 1
  fi
  ios_destination="platform=iOS Simulator,id=$simulator_id"
fi

echo "==> Flutter plugin tests"
run_logged "${flutter[@]}" test --reporter expanded

cd "$root_dir/example"
echo "==> Flutter example tests"
run_logged "${flutter[@]}" test --reporter expanded

echo "==> Android unit tests"
run_logged "${flutter[@]}" build apk --config-only
(
  cd android
  run_logged ./gradlew :cross_bluetooth_api:testDebugUnitTest --console=plain
)
echo "==> Android unit tests passed"

echo "==> iOS tests ($ios_destination)"
run_logged "${flutter[@]}" build ios --config-only --simulator
run_logged xcodebuild test \
  -workspace "$root_dir/example/ios/Runner.xcworkspace" \
  -scheme Runner \
  -configuration Debug \
  -destination "$ios_destination" \
  -only-testing:RunnerTests \
  CODE_SIGNING_ALLOWED=NO

echo "==> All tests passed"
