#!/bin/sh
# Greppable rules from llm/01-rules.md. Run from anywhere: sh llm/check.sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

fail() {
  printf 'check: %s\n' "$1" >&2
  exit 1
}

hits=$(grep -R -n --include='*.swift' -F 'fatPercent' \
  EatWatch EatWatchWatch EatWatchCore/Sources EatWatchCore/Tests || true)
if [ -n "$hits" ]; then
  printf '%s\n' "$hits" >&2
  fail "Swift contains fatPercent"
fi

grep -F -q 'saves imported data to the' EatWatchCore/Sources/EatWatchCore/AppName.swift \
  || fail "AppName.importSavedLine does not say saves imported data"

grep -F -q 'public static let range = 1...48' EatWatchCore/Sources/EatWatchCore/AppName.swift \
  || fail "ExerciseRung.range is not 1...48"

if grep -F -q 'icloud-container' EatWatchWatch/EatWatchWatch.entitlements; then
  fail "watch entitlement names an iCloud container"
fi
grep -F -q 'com.apple.developer.healthkit' EatWatchWatch/EatWatchWatch.entitlements \
  || fail "watch entitlement is missing HealthKit"

grep -F -q 'iCloud.com.alexshultz.EatWatch' EatWatch.entitlements \
  || fail "iPhone entitlements file is missing the iCloud container"

count() {
  grep -F -c -- "$1" EatWatch.xcodeproj/project.pbxproj || true
}

iphone=$(count 'CODE_SIGN_ENTITLEMENTS = EatWatch.entitlements;')
watch=$(count 'CODE_SIGN_ENTITLEMENTS = EatWatchWatch/EatWatchWatch.entitlements;')
[ "$iphone" -eq 2 ] || fail "iPhone/iPad/Mac CODE_SIGN_ENTITLEMENTS count is $iphone, want 2"
[ "$watch" -eq 2 ] || fail "watch CODE_SIGN_ENTITLEMENTS count is $watch, want 2"

if grep -F -q 'CODE_SIGNING_ALLOWED = NO' EatWatch.xcodeproj/project.pbxproj; then
  fail "CODE_SIGNING_ALLOWED is NO"
fi

namecount=$(count 'INFOPLIST_KEY_CFBundleName = "$(APP_DISPLAY_NAME)";')
[ "$namecount" -ge 4 ] || fail "CFBundleName is not set from APP_DISPLAY_NAME on every configuration"

grep -F -q 'enableCloud: Bool = true' EatWatchCore/Sources/EatWatchCore/EatWatchSession.swift \
  || fail "EatWatchSession.open no longer defaults CloudKit on"

watch_off=$(grep -R -n --include='*.swift' -F 'enableCloud: false' EatWatchWatch || true)
if [ -n "$watch_off" ]; then
  printf '%s\n' "$watch_off" >&2
  fail "watch app turns CloudKit off"
fi
grep -F -q 'EatWatchSession.open' EatWatchWatch/EatWatchWatchApp.swift \
  || fail "watch app does not call EatWatchSession.open"

printf 'check: ok\n'
