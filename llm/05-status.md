# Status and discarded ideas

Facts below are dated 2026-10-08. Verify anything that can change (profiles, install paths, DerivedData, device lock state) before you rely on it.

This file is history. Do not implement a feature from it unless Alex asks again.

## Verified that day

- `swift test` in `EatWatchCore`: 31 tests passed.
- Mac Debug `xcodebuild` succeeded and was signed `Apple Development: alex.shultz@mac.com (4TRS65CTUB)` with a Mac Team Provisioning Profile for `com.alexshultz.EatWatch`.
- The built Mac Info.plist had `CFBundleDisplayName` EatWatch, and Health usage strings that mention weight only.
- Opening that Debug app showed Today. Settings showed the import footnote beginning "EatWatch saves imported data to the EatWatch iCloud log." The agreement sheet showed all three lines and the title "Import only your own log".
- Watch Debug `xcodebuild` for `generic/platform=watchOS` succeeded. It was not installed. `CFBundleDisplayName` was EatWatch. That product's `CFBundleName` remained EatWatchWatch. The project file now sets the watch `CFBundleName` from `APP_DISPLAY_NAME`.
- The iPhone was not updated to this build. An earlier HealthKit install was copied to the phone and did not launch because the phone was locked. That older install still requested body-fat access.

On 2026-10-09 the Xcode source and these notes were published together in `alexshultz/eatwatch`.

## Not verified

- Two devices receiving the same CloudKit row.
- The watch app on a watch.
- This build on the iPhone or an iPad.
- A simulator launch. No simulator runtime is installed.
- Production CloudKit schema deployment. Debug uses the Development database.

## Older notes that are wrong

Local assistant memory and earlier chat summaries still say some of the following. The source and `llm/02-behavior.md` are right.

- The import agreement does not say "EatWatch save imported". It says "saves".
- Flag is stored and round-trips. Import does not ignore the Flag column.
- Rung stops at 48. The stepper is not 1...200.
- Body-fat percentage is not stored, not shown, and not read or written through Health.
- `DayRecord` does not have `fatPercent`.
- A Health weight does not replace the stored EatWatch row. It replaces the weight used for the trend.

## Ideas Alex considered and rejected

- Copying Health history into the EatWatch iCloud log so the Mac can chart years of scale data. Guideline 5.1.3(ii) forbids it. Health's own sync is the allowed path between Apple devices that have a Health store. The Mac is not one of those devices.
- Treating a user-exported CSV, or a file that passed through The Hacker's Diet Online, as no longer being Health data.
- Stripping a source column so the importer cannot see where a row came from.
- An import filter that claims to detect Health rows. Alex asked for an agreement instead. The agreement is a reminder.
- Keeping body fat because the trend might calculate it. The percentage was entered or read. The online log has no such column.

## Gap that is not a request

The watch target has no iCloud entitlement, so its typed log does not join the iPhone, iPad, and Mac log. Say so if it matters to the task. Do not add the container unless Alex asks.

A Mac-only import that never uploads was described as a compliant way to use Health history on the Mac. It was not built. Do not bolt it onto Import CSV.

## Related local notes

These are not the source of truth. They also cover other apps.

- `/Users/alex/.grok/memory-v2/workspaces/alex-a426792c/topics/eatwatch.md`
- `/Users/alex/.grok/memory-v2/workspaces/alex-a426792c/topics/icloud-sync.md`
- `/Users/alex/.grok/memory-v2/workspaces/alex-a426792c/topics/apple-device-testing.md`

The iCloud note's `DayRecord` field list still includes `fatPercent`. Ignore that list.
