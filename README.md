# EatWatch

This repository is the Xcode project and the briefing a new assistant should read before editing.

Read `llm/` before changing behavior. If a sentence there and the Swift disagree, the Swift wins. Update the briefing in the same change.

Assistant memory and the Seldon vault are pointers to this repository. They are not a second copy of the rules.

A checkout on Alex's Mac is `/Users/alex/Projects/EatWatch`. Build products, `EatWatchCore/.build/`, and `xcuserdata/` are not in the repo. The app icon PNG is the same file for iPhone and Watch. Its exact bytes are `Supporting/AppIcon.base64`. Restore both copies with `sh Supporting/restore-icons.sh`. The Mac checkout already has the PNGs.

Read in this order before you edit:

1. This file. `AGENTS.md` only repeats this first step.
2. `llm/01-rules.md`
3. The one behavior or build file the task needs.

The short rules below are reminders. The binding text is `llm/01-rules.md`. A shorter sentence here is not permission to go further.

| If the task is about | Read |
| --- | --- |
| Health, iCloud, CSV, import, body fat, display name, the watch | `llm/01-rules.md` then `llm/02-behavior.md` |
| Where a fact lives in code | `llm/03-map.md` |
| Compile, sign, install, or check the Mac window | `llm/04-build.md` |
| Whether something was already tried or already rejected | `llm/05-status.md` |

## What this app is

EatWatch is a native SwiftUI log for the trend method in John Walker's *The Hacker's Diet*. It runs on iPhone, iPad, and Mac from one target, plus a separate Apple Watch app. The person using it is Alex Shultz. He wants one log on every device signed into his iCloud account, and he wants Apple Health used only in the way App Store Review allows.

It is not a patch of the old FatWatch app. Leave `/Users/alex/Projects/FatWatch` unchanged.

## Names that are easy to mix up

| Name | What it is |
| --- | --- |
| EatWatch | This app. The visible name can change. See the display-name rule below. |
| The Hacker's Diet Online | The Fourmilab web log. CSV compatibility means that system, not a second copy of this app. |
| Eat Watch | The old Palm app from Fourmilab. There was never an official iOS Eat Watch. |
| FatWatch | A third-party iOS app from 2010 by Heroic Software. Source is the untouched checkout above. |

## Rules that override a helpful idea

1. Do not store a Health sample, or a number computed from one, in CloudKit, SwiftData, `log.json`, or any file the app creates by itself.
2. A CSV is written only after the user picks a destination. Import writes accepted rows into the iCloud log. The agreement reminds the user. It does not detect Health data.
3. Health read and write are body mass only. Body-fat percentage is not in the product.
4. On iPhone, iPad, and Watch, a Health weight for a day replaces the on-screen trend weight. The stored EatWatch row stays. There is no setting to pick the source.
5. The visible name is `APP_DISPLAY_NAME` in `Supporting/AppName.xcconfig`. Do not rename the bundle ids, the iCloud container, the SwiftData store name, or `Application Support/EatWatch/EatWatch.store` to follow a display-name change.
6. Sign with the paid team. Do not set `CODE_SIGNING_ALLOWED=NO`.
7. This Mac has Xcode 27.0 at `/Applications/Xcode.app`. Do not reinstall it. Do not use APIs that exist only in the 27.1 SDK. No iOS or watch simulator runtime is installed.
8. Weights in the store are pounds. The trend is recomputed in memory and is not a stored field.

## Account

- Apple ID: `alex.shultz@mac.com`
- Team: Alex Shultz, `N8D3Z8U4Y9`, Individual, paid membership active as of 2026-10-08
- Signing identity already on the Mac: `Apple Development: alex.shultz@mac.com (4TRS65CTUB)`. Do not create another.
- Bundle id: `com.alexshultz.EatWatch`
- Watch bundle id: `com.alexshultz.EatWatch.watchkitapp`
- iCloud container: `iCloud.com.alexshultz.EatWatch`

Do not put the Apple ID password, or an Apple Developer portal session token, in this repo or in chat.

## Answers a first read should give

A reader who has only this repository should be able to answer these three. The binding text is the file named on each line.

1. A Health weight is used for the on-screen trend and is not written into `DayRecord`. See `llm/01-rules.md` (Same-day weight) and `llm/02-behavior.md` (Health merge).
2. Import writes every accepted row into the iCloud log. The agreement does not detect Health rows. See the forbidden list in `llm/01-rules.md`.
3. Sign with `CODE_SIGN_STYLE` Automatic and team `N8D3Z8U4Y9`. Do not set `CODE_SIGNING_ALLOWED=NO`. A device build needs `-allowProvisioningUpdates`. See `llm/04-build.md`.

## Checks

From the repository root, after a behavior or signing edit:

```sh
sh llm/check.sh
cd EatWatchCore && swift test
```

`llm/check.sh` fails if Swift contains `fatPercent`, the agreement line lacks `saves imported data`, the rung range is not `1...48`, the watch entitlement names an iCloud container, the project drops an entitlement-file reference, or the watch app turns CloudKit off. `swift test` is the behavior check. Trust that run's output. The last recorded count is in `llm/05-status.md`.
