# Rules

Read this before editing. These are decisions Alex already made. If a task asks for something this file forbids, stop and say so. Do not ship a partial version that gets the data into iCloud by another path.

`llm/check.sh` fails when a later edit breaks the greppable parts of these rules: no `fatPercent` in Swift, the agreement line says `saves imported data`, the rung range is `1...48`, the watch entitlement has no iCloud container, the watch app still calls `EatWatchSession.open` with CloudKit left on, and the interface locks hold. Those locks are the design-guidelines sentence, `AppIcon.icon` in both apps, no flat icon restore path, Today as a `List` with `.font(.largeTitle)`, no `minimumScaleFactor`, per-mark chart labels, a visible watch chart axis, and two increased-contrast accent appearances. Run it from the repository root.

For screens, icons, type, color, and charts, the Seldon vault note `projects/Apple-OS27-Design-Guidelines` outranks this repository. Health, import, and signing rules in this file still bind.

## Health and iCloud

App Store Review Guideline 5.1.3(ii) (guidelines dated 2026-06-08) says an app may not store personal health information in iCloud. That binds the app. It is not lifted because the user taps a button, because a column was deleted, or because the file once passed through The Hacker's Diet Online.

Allowed:

- Read Health body mass on iPhone, iPad, and Apple Watch and compute the trend in memory.
- Write a weight the user typed in this app to Health, when write permission is granted, as a user-entered body-mass sample.
- Keep typed EatWatch fields in the CloudKit log: date, weight, rung, flag, comment, and the plan.
- Export a CSV after the user chooses where to save it. The file may contain the weights the trend used, including Health readings. The user owns that file.

Forbidden:

- Copy a Health weight into `DayRecord`, the SwiftData store, `log.json`, CloudKit, or any file the app writes on its own.
- Store the trend, variance, slope, or calorie balance. Recompute them.
- Treat an imported CSV as safe because the user agreed. The importer still writes every accepted row into the iCloud log. It cannot tell a Health row from a typed row.
- Add a "Mac local Health import" unless Alex asks for that specific feature. It was offered and not built. The current Import CSV path is not that feature.
- Read or write Health body-fat percentage.

The Mac has no Health store. HealthKit can be linked so the shared iPhone/iPad/Mac target compiles. Apple's capability list does not offer HealthKit for Mac. `EatWatch.entitlements` still requests HealthKit because that same file is used by the iPhone and iPad. Do not delete that key to "clean up" the Mac. The Mac provisioning profile cannot grant it. `HealthKitJournal.signedForHealth` is false on macOS unless the signed process actually has `com.apple.developer.healthkit`. History that exists only in Health reaches the Mac only if the user typed it into EatWatch on another device, or imported their own log. Health's own iCloud sync is the path between iPhone, iPad, and Apple Watch.

## Same-day weight

There is no control that chooses the source.

For the trend, chart, and Today screen on a device that can read Health: if Health has a plausible weight that day, that weight is what the screen uses. The EatWatch row in the database is not replaced. Its rung, flag, and comment stay on the merged day. The edit sheet still loads the stored EatWatch weight.

On the Mac, Health is absent, so the stored weight is what the screen uses.

## Body fat

Body fat is not calculated from weight. An older build stored a percentage and read it from Health. Alex removed it so the log matches The Hacker's Diet Online, which has no body-fat column. Do not add the field, the Health type, or a fat trend back.

## Display name

Change `APP_DISPLAY_NAME` in `Supporting/AppName.xcconfig` and rebuild. Swift reads `CFBundleDisplayName` through `AppName.display`. The Health and Face ID usage strings use `$(APP_DISPLAY_NAME)`.

Leave these alone when the visible name changes:

- `com.alexshultz.EatWatch` and `com.alexshultz.EatWatch.watchkitapp`
- `iCloud.com.alexshultz.EatWatch`
- SwiftData configuration name `"EatWatch"` (`EatWatchSession.storeName`)
- Store folder `Application Support/EatWatch/EatWatch.store` (`LogStore.storeFolderName`)
- Type and module names (`EatWatchSession`, `EatWatchCore`, `EatWatchApp`)

Package tests have no display name, so `AppName.display` falls back to `"EatWatch"`. That fallback is not a second place to rename the app.

The watch target sets `INFOPLIST_KEY_CFBundleDisplayName` and `INFOPLIST_KEY_CFBundleName` to `$(APP_DISPLAY_NAME)`. `PRODUCT_NAME` stays `$(TARGET_NAME)`, which is `EatWatchWatch`. A 2026-10-08 watch product reported `CFBundleName` as `EatWatchWatch`. A build from the current project file takes `CFBundleName` from `APP_DISPLAY_NAME`. Do not rename the watch product to chase the visible name.

## Signing and tools

- `CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM = N8D3Z8U4Y9`.
- Do not set `CODE_SIGNING_ALLOWED=NO`. An unsigned install fails.
- Command-line device builds need `-allowProvisioningUpdates`. The first paid Mac build also needs `-allowProvisioningDeviceRegistration` until that Mac is registered.
- Xcode 27.0 (27A266a) is `/Applications/Xcode.app`. `xcode-select` points there. Do not reinstall Xcode and do not install a second one.
- No iOS or watch simulator runtime is installed. Build the apps. Do not expect `simctl` to launch them.

## Watch target

`EatWatchWatch` is a separate target. It is not embedded in the iPhone app. Its entitlement file has HealthKit and not the iCloud container. `EatWatchWatchApp` calls `EatWatchSession.open` with CloudKit left on. `makeContainer` tries the private database with `try?` and, when that throws, opens a local store. A crash inside CloudKit setup is not a thrown error. The build notes record an `EXC_BREAKPOINT` on the Mac when the iCloud entitlement is missing. The watch app has not been launched, so a watch log joining CloudKit is unverified. Do not add the container as a drive-by fix.

## Scope

Change only what Alex asked for. The old FatWatch tree is reference material, not a place to edit. Do not copy Apple portal session tokens into notes or commits.
