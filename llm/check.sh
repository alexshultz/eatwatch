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

grep -F -q 'projects/Apple-OS27-Design-Guidelines' README.md \
  || fail "README does not name the design-guidelines note"
grep -F -q 'projects/Apple-OS27-Design-Guidelines' AGENTS.md \
  || fail "AGENTS.md does not name the design-guidelines note"
grep -F -q 'projects/Apple-OS27-Design-Guidelines' llm/01-rules.md \
  || fail "01-rules does not name the design-guidelines note"

[ -f EatWatch/AppIcon.icon/icon.json ] || fail "iPhone icon package is missing"
[ -f EatWatchWatch/AppIcon.icon/icon.json ] || fail "watch icon package is missing"
[ -f EatWatch/AppIcon.icon/Assets/Clock.png ] || fail "iPhone clock layer is missing"
[ -f EatWatchWatch/AppIcon.icon/Assets/Clock.png ] || fail "watch clock layer is missing"
cmp -s EatWatch/AppIcon.icon/icon.json EatWatchWatch/AppIcon.icon/icon.json \
  || fail "the two icon.json files disagree"
cmp -s EatWatch/AppIcon.icon/Assets/Clock.png EatWatchWatch/AppIcon.icon/Assets/Clock.png \
  || fail "the two clock layers disagree"
if [ -e EatWatch/Assets.xcassets/AppIcon.appiconset ] \
  || [ -e EatWatchWatch/Assets.xcassets/AppIcon.appiconset ] \
  || [ -e Supporting/restore-icons.sh ] \
  || [ -e Supporting/AppIcon.base64 ]; then
  fail "the flat icon path is back"
fi

for gone in BalanceCard.swift Metric.swift TodayReading.swift RecentDays.swift; do
  if [ -e "EatWatch/$gone" ]; then
    fail "EatWatch/$gone is back"
  fi
done

grep -F -q 'List {' EatWatch/TodayView.swift || fail "Today is not a List"
grep -F -q '.font(.largeTitle)' EatWatch/TodayView.swift || fail "Today weight is not largeTitle"
if grep -F -q '.scaled(by:' EatWatch/TodayView.swift EatWatchWatch/WatchTodayView.swift; then
  fail "a weight uses scaled(by:)"
fi

shrink=$(grep -R -n --include='*.swift' -F 'minimumScaleFactor' EatWatch EatWatchWatch || true)
if [ -n "$shrink" ]; then
  printf '%s\n' "$shrink" >&2
  fail "Swift shrinks text with minimumScaleFactor"
fi

if grep -R -n --include='*.swift' -F 'accessibilityLabel("Weight chart")' EatWatch EatWatchWatch; then
  fail "a chart is one accessibility element"
fi
grep -F -q 'accessibilityLabel("Trend,' EatWatch/ChartPlot.swift \
  || fail "ChartPlot does not label the trend"
grep -F -q 'accessibilityLabel("Goal band")' EatWatch/ChartPlot.swift \
  || fail "ChartPlot does not label the goal band"
grep -F -q 'accessibilityLabel("Trend,' EatWatchWatch/WatchChartView.swift \
  || fail "watch chart does not label the trend"
if grep -F -q '.chartXAxis(.hidden)' EatWatchWatch/WatchChartView.swift; then
  fail "watch chart hides the horizontal axis"
fi

contrast=$(grep -F -c '"appearance" : "contrast"' \
  EatWatch/Assets.xcassets/AccentColor.colorset/Contents.json || true)
[ "$contrast" -eq 2 ] || fail "accent color contrast appearances are $contrast, want 2"

printf 'check: ok\n'
