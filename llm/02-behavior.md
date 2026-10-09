# Behavior

This is how the app works as of 2026-10-08. Symbol names are the ones in the source. Change the code and this file together.

Quick answers:

- Same day in both places: the trend uses the Health weight. The stored EatWatch row is kept. There is no chooser. Details are under "Health merge".
- The log that syncs is typed and imported days, plus the plan. Health samples are not in it.
- CSV columns are `Date,Weight,Rung,Flag,Comment`. Flag is stored. Rung is 1...48.
- The import agreement's first line uses the word `saves`.

## Two layers

| Layer | What it holds | Survives relaunch | Syncs |
| --- | --- | --- | --- |
| EatWatch log | Days the user typed or imported, plus the plan | Yes, in SwiftData | Yes, CloudKit private database, except the watch |
| Health overlay | Body-mass readings for the trend | Only by reading Health again | Health's own sync, not this app's |

`LogStore` keeps the log in `entries` and the overlay in `healthReadings`. `publishAnalysis` calls `HealthLogMerge.entries` and then `TrendEngine.analyze`. `applyHealth` replaces the overlay and republishes. It does not insert `DayRecord`s.

## Stored day

`DayRecord` fields: `dayISO`, `weightPounds`, `rung`, `flagged`, `note`, `modifiedAt`.

`WeighIn` is the in-memory value. `rung` is kept only when `ExerciseRung.accepted` says it is in `1...48`. `flagged` is the online Flag checkbox. `note` is the Comment, truncated to 500 characters on save.

Identity is the day string `yyyy-MM-dd` (`Day.iso`). CloudKit cannot enforce one row per day. `DayRecord.reconcile` keeps the newer `modifiedAt` and deletes the rest. Ties use `persistentModelID`.

A missing weight, or a weight outside `0 < pounds < 1500` (`WeightInput.isPlausible`), is not a day.

## Plan

`PlanRecord` holds the shared plan: weight unit, energy unit, goal pounds, schedule (`rate` or `date`), pounds per week (negative loses weight), goal date, height in centimeters, `modifiedAt`.

`PlanRecord.keeper` keeps one row. Newer `modifiedAt` wins. If the times match, a row that has a goal or a height beats an empty one, then `persistentModelID` breaks the tie.

The first local plan is stamped `.distantPast` so a later edit from another device wins. Device lock is `UserDefaults` key `eatwatch.lock` and does not sync. Older unit and goal keys in `UserDefaults` are copied once into the plan if no plan row exists yet. Do not also mirror the plan through `NSUbiquitousKeyValueStore`.

Height is for BMI only. Blank height hides BMI. The goal band is 2.5 lb (`TrendMath.goalBandPounds`).

## Trend

`TrendMath.dailyShare` is `0.1`. The first weight is the trend. Each later weigh-in moves the trend by 10 percent of the gap. A day with no weight holds the trend. One pound of trend is 3,500 kilocalories. One kilocalorie is 4.184 kilojoules.

Slope is least-squares of trend against calendar day. It needs four weigh-ins in the window. `preferredSlope` tries 30 days, then 90, then the whole log. Gaps count as time.

Rung, flag, and comment are not inputs. The CSV does not contain trend or variance.

Storage constants, from the old FatWatch math: 0.45359237 kilograms per pound, 14 pounds per stone.

## Health merge

`HealthLogMerge.entries`:

- Start from the log.
- For each Health day with a plausible weight, overwrite `weightPounds` on that day.
- If the log has no row, add an in-memory `WeighIn` with that weight and empty rung, flag, and note.
- A Health day with no weight does nothing.
- Rung, flag, and note on an existing log row stay.

`HealthKitJournal.readings` queries `HKQuantityType.bodyMass` only. Samples are sorted earliest first. The first sample for a local calendar day wins. Later samples that day are ignored.

`saveEntry` runs only when sharing body mass is authorized. It deletes body-mass samples this app wrote for that calendar day (`HKSource.default()` plus that day's start), then saves one sample at `day.date()` with `HKMetadataKeyWasUserEntered`.

`deleteEntry` deletes those authored samples only. Scale samples stay. Swipe-delete is offered only for days that exist in the EatWatch store. Delete-all clears EatWatch rows and leaves other Health sources.

Saving in the edit sheet writes the stored EatWatch weight into Health. The trend still uses the earliest Health sample that day. An earlier scale sample keeps winning on screen. The edit sheet keeps showing the stored EatWatch weight, because it loads `LogStore.weighIn`, not the merged point.

The entry sheet explains a Health-only day: Health already has a weight in the trend, it is not in the EatWatch log, and a weight typed there becomes the user's own entry.

CSV import does not write rows back to Health.

## CSV

Online column order, also the template:

```text
Date,Weight,Rung,Flag,Comment
```

`CSVLog.template()` is that line plus a newline. The template button saves `EatWatch-template.csv` under the current display name.

Export prepends a Preferences line the online importer ignores because it does not start with a date:

```text
Preferences,1.0,<unit>,<unit>,calorie,0,.
```

`<unit>` is `pound`, `kilogram`, or `stone`, matching the app's unit. A stones log stores the weight numbers in pounds, which is what the online file does. Flag is `1` or `0`. Empty rung is an empty field. Comment is escaped when it contains a comma, quote, or newline.

Import:

- Strip a leading BOM. Turn CRLF and CR into LF before scanning. Swift treats CRLF as one Character, so splitting on Character boundaries would hide the break.
- A `Preferences` row's third field sets the log unit. `stone` and `stones` mean the numbers are pounds.
- The heading is the first row whose cells map to both a date and a weight. `Epoch`, `User`, `Diet-Plan`, and `StartTrend` sit above it and are skipped. `StartTrend` fails the date parse.
- Unit for a row: a unit named in the weight header, otherwise Preferences, otherwise the app's current unit.
- Rung outside 1...48 becomes blank. The weight is still imported.
- Flag is set only for the field `1`. Blank and `0` stay clear.
- A file with no recognized heading can still be `Date,Weight,Rung,Flag,Comment` when the rung cell is an integer or empty and the flag cell is empty, `0`, or `1`. Any other shape keeps the old fallback: non-numeric leftovers become the note.
- Same calendar day replaces that day. Days absent from the file stay.
- `importEntries` returns how many days replaced an existing weight.

An iPhone export includes every weight in the trend, including Health-only days and Health weights that overrode a stored weight. Importing that file writes those rows into the iCloud log. That is the case the agreement is there to prevent. Do not make the importer smarter by stripping a source column. Alex rejected that. The app still cannot tell the rows apart.

## Import agreement

Shown every time, before the file picker. The choice is not stored. `SettingsView` presents a sheet. `onDismiss` opens the importer only after Import. Cancel leaves the picker closed.

Title: `Import only your own log`

Buttons: `Cancel` and `Import`

Lines, with the display name filled in:

1. `EatWatch saves imported data to the EatWatch iCloud log.`
2. `Apple’s guidelines prohibit saving Apple Health data in the EatWatch iCloud log.`
3. `Do not include data that originated in Apple Health in your import.`

The Settings footnote is line 1 plus `Do not include data that originated in Apple Health.`

The apostrophe in line 2 is the typographic `’` used in `AppName.importGuidelineLine`. Do not "correct" it to a straight quote and do not change `saves` back to `save`.

## Sync

`EatWatchSession.open` builds a `ModelContainer` for `DayRecord` and `PlanRecord`.

- In-memory and seeded sessions use `cloudKitDatabase: .none`.
- Otherwise it tries `cloudKitDatabase: .private(EatWatchCloud.containerIdentifier)` with `try?`. Failure falls back to a local store. The app stays usable.
- `autosaveEnabled` is false. Callers save explicitly.
- `modifiedAt` is set before save.

`ResultsObserver` on the main context, with `withContinuousObservation(options: .didSet)`, reloads when the store changes, including a CloudKit import. The token is `~Copyable` and is stored with `@ObservationIgnored`. `RootView` also calls `session.refresh()` when the scene becomes active.

iPhone and watch Info.plists include `UIBackgroundModes` = `remote-notification` via `Supporting/BackgroundModes.plist`. The Mac plist does not. Do not put an Info.plist inside the synchronized `EatWatch/` or `EatWatchWatch/` groups. Xcode both copies and processes it, and the build fails. The entitlements files stay outside those groups too.

`ICloudSyncState` is account status, not a proof that a row arrived on another device. Two-device sync had not been watched as of 2026-10-08.

Debug builds use the CloudKit Development database. Release and TestFlight use Production until the schema is deployed.

A legacy `Application Support/EatWatch/log.json` is imported once per defaults suite (`eatwatch.didImportJSONLog`), only into days that are absent. The file's modification date becomes `modifiedAt`. It is not an ongoing write.

## Screens

iPhone, iPad, and Mac (`RootView`): Today, Log, Chart, Plan. The tab style is `sidebarAdaptable`. Settings is a sheet from the toolbar. A lock screen uses Face ID or the device passcode on iOS, and Touch ID or the password on Mac. Leaving the foreground locks again.

Watch (`WatchRootView`): Today, Log, Chart. The entry editor sets date, weight, flag, and rung, and preserves an existing note. It does not import CSV.

The chart plots weight and trend. It does not plot body fat.
