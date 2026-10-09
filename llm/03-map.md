# Code map

Source root: `/Users/alex/Projects/EatWatch`.

`EatWatchCore` is a local Swift package (tools 6.4, language mode Swift 6, iOS 27, macOS 27, watchOS 27). The app targets depend on it. New Swift files in `EatWatchCore/Sources/EatWatchCore/` are picked up by SwiftPM. The app and watch folders are synchronized Xcode groups, so a new Swift file there is picked up too. `Supporting/` is not a synchronized group. A new file there needs a `project.pbxproj` reference if Xcode must see it.

## Change this, then that

| Task | Start here |
| --- | --- |
| Trend math | `TrendEngine.swift`, `TrendMath` |
| What is stored | `DayRecord.swift`, `PlanRecord.swift`, `LogStore.swift` |
| Health read or write | `HealthKitJournal.swift`, `HealthLog.swift` |
| CSV | `CSVLog.swift`, `SettingsView.swift` |
| Visible sentences that include the app name | `AppName.swift` and `Supporting/AppName.xcconfig` |
| iCloud open and refresh | `EatWatchSession.swift`, `EatWatchCloud.swift` |
| iPhone, iPad, Mac UI | `EatWatch/` |
| Watch UI | `EatWatchWatch/` |
| Tests | `EatWatchCore/Tests/EatWatchCoreTests/` |

## Package files

| File | Owns |
| --- | --- |
| `AppName.swift` | Display-name lookup and the fixed user-facing sentences. `ExerciseRung`. |
| `Day.swift` | Calendar day with no time of day. `Day.gregorian` uses the current time zone. |
| `WeighIn.swift` | `WeighIn`, `TrendPoint`, `DailyPoint`. |
| `DayRecord.swift` | SwiftData day row and duplicate reconcile. |
| `PlanRecord.swift` | SwiftData plan row and duplicate reconcile. |
| `LogStore.swift` | Load, save, import, delete, legacy JSON, Health overlay, analysis publish. Store URL. |
| `EatWatchSession.swift` | Open the container, wire observers, save and delete through Health. |
| `HealthLog.swift` | `HealthDayReading`, `HealthLogMerge`, `HealthJournal`. |
| `HealthKitJournal.swift` | HealthKit. Wrapped in `canImport(HealthKit)`. |
| `CSVLog.swift` | Template, export, parse. |
| `TrendEngine.swift` | Trend, variance, slope, calorie conversion. |
| `PlanMath.swift` | Goal rate, goal date, calorie gap, BMI band. |
| `AppSettings.swift` | Plan editing and the device lock. |
| `WeightUnit.swift` | Pounds, kilograms, stones, energy units, number parsing. |
| `MeasureFormat.swift` | Display strings. |
| `ICloudSyncState.swift` | The Settings sentence for the current account status. |
| `SampleLog.swift` | Demo series. Not the user's log. |
| `EatWatchCloud.swift` | Container identifier constant. |

## App files that hold behavior, not just layout

| File | Owns |
| --- | --- |
| `EatWatch/RootView.swift` | Tabs, lock, refresh on active. |
| `EatWatch/SettingsView.swift` | Units, height, lock, Health button, CSV, delete-all, import agreement. |
| `EatWatch/EntrySheet.swift` | Create and edit a day. Rung stepper uses `ExerciseRung.range`. |
| `EatWatch/TodayView.swift` | Navigation title is `AppName.display`. |
| `EatWatch/LogRow.swift`, `TodayReading.swift` | Show flag, rung, and note. |
| `EatWatchWatch/WatchEntryView.swift` | Watch editor. Preserves the note. |
| `Supporting/AppName.xcconfig` | The one display-name setting. Included by the project Debug and Release configurations. |
| `Supporting/BackgroundModes.plist` | `remote-notification` only. |
| `EatWatch.entitlements` | HealthKit plus the iCloud container. iPhone, iPad, and Mac. |
| `EatWatchWatch/EatWatchWatch.entitlements` | HealthKit only. |
| `EatWatch.xcodeproj/project.pbxproj` | Both targets, display name, usage strings, deployment 27. |

## Tests

Run from `EatWatchCore` with `swift test`. As of 2026-10-08, 31 tests passed.

| File | Covers |
| --- | --- |
| `TrendTests.swift` | 10 percent update, gaps, slope, rung and flag not affecting the trend. |
| `PlanAndCSVTests.swift` | Plan math, BMI, online CSV, template, flag round-trip, rung 48 vs 49, quoted notes, headerless rows. |
| `HealthLogTests.swift` | Health weight overlay, Health-only day, no row when Health has no weight, overlay not stored. |
| `SyncTests.swift` | Save, delete, import, duplicate day, one-time legacy import, plan keeper, `ResultsObserver`. |

`testDisplayNameAgreementUsesSaves` locks the word `saves` in `AppName.importSavedLine`.

## UI copy that must keep the display name

Do not hardcode `EatWatch` in a sentence the user reads. Use `AppName.display` or one of the `AppName` sentence properties. Sentences that already do this include the import agreement, the Health detail lines, the lock reason, the About paragraph, the delete warnings, the Plan "four weights" line, and the export filenames.

The export footnote names The Hacker's Diet Online on purpose. Do not substitute the app's display name there.
