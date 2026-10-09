# Build and install

## Package tests

```sh
cd /Users/alex/Projects/EatWatch/EatWatchCore
swift test
```

This does not sign, and it does not prove the iOS or watch UI compiles. Run it when the change is in `EatWatchCore`. Also run `sh llm/check.sh` from the repository root. That script locks the greppable rules in `llm/01-rules.md`. Trust the test output from the run you just made.

## Mac app

```sh
xcodebuild -project /Users/alex/Projects/EatWatch/EatWatch.xcodeproj \
  -scheme EatWatch \
  -destination 'platform=macOS,arch=arm64' \
  -configuration Debug \
  -allowProvisioningUpdates \
  build
```

The 2026-10-08 Debug product was:

`/Users/alex/Library/Developer/Xcode/DerivedData/EatWatch-dakbakwrvzuulvgwdovbfgbrhpla/Build/Products/Debug/EatWatch.app`

DerivedData folder names can change. Trust the build log over that path.

Open that app directly. An Xcode `debugserver` launch has hung in `NSApplication` init with no window. A build whose entitlements omit iCloud has crashed (`EXC_BREAKPOINT`) while CloudKit set up the container. Keep `CODE_SIGN_ENTITLEMENTS = EatWatch.entitlements` on the paid-team iPhone/iPad/Mac target.

After a rename experiment, check the built Info.plist:

```sh
plutil -p EatWatch.app/Contents/Info.plist | grep -E 'CFBundle(Display)?Name|Health|Face'
```

`CFBundleDisplayName` and the Health usage strings should contain the display name and should not mention body fat.

## Watch app

```sh
xcodebuild -project /Users/alex/Projects/EatWatch/EatWatch.xcodeproj \
  -scheme EatWatchWatch \
  -destination 'generic/platform=watchOS' \
  -configuration Debug \
  -allowProvisioningUpdates \
  build
```

A generic destination builds. It does not install. Installing needs the paired watch selected in Xcode. Developer Mode on the watch if the install asks. The watch installs through the paired iPhone.

## iPhone

- iPhone 16 Pro Max, model iPhone17,2, iOS 27.0.1 (24A446)
- UDID `00008140-000C78E43A33001C`
- Developer Mode is on. The developer certificate is trusted.
- Unlock the phone before launch. A locked phone denies launch after a successful install.
- No iPad and no watch were connected on 2026-10-08.

Xcode Run is the toolbar triangle, Command-R. The destination popup is beside the scheme. Pick the phone by name. A simulator row is not the phone. If the phone is missing: connect, unlock, Trust, then the destination menu → Manage Devices…

Command-line install needs the signed app and `devicectl`, or Xcode with the real device as the run destination. `-destination 'generic/platform=iOS'` only builds.

A device build from the command line needs `-allowProvisioningUpdates`. Register a new Mac with `-allowProvisioningDeviceRegistration` once.

## Signing facts that have already failed

- A free personal team cannot sign the iCloud capability. The paid membership on the same team id is what signs CloudKit. Do not remove `CODE_SIGN_ENTITLEMENTS` to "make it build" on this team.
- `CODE_SIGNING_ALLOWED=NO` produces an app the device rejects: "The executable is not codesigned".
- Read the embedded profile from the built app when you need the UUID or the expiry. Profiles in this note go stale. The Mac build on 2026-10-08 used "Mac Team Provisioning Profile: com.alexshultz.EatWatch". The watch build used "iOS Team Provisioning Profile: com.alexshultz.EatWatch.watchkitapp".

## Phone install quirks

On 2026-10-08, Verify App did nothing until two configuration profiles were removed and the phone was rebooted: Client-SecureQ (`6AA99C8F-2733-450B-A32E-23AF79B65E59`) and Secure-InterQ (`C0197272-85A9-4864-BA8C-10CF52872C86`). Leave the Atkinson Hyperlegible iFont profiles in place. If those two certificates are trusted again, Verify App can stall the same way.

If an install says the Developer App certificate is not trusted: Settings → General → VPN & Device Management → alex.shultz@mac.com → Trust, then Verify App. If Verify does nothing, reboot. Unlock before expecting a launch.

## Checking the Mac UI

Screen capture permission has been unavailable. Accessibility can read static text. Button titles are often missing. `description` of the Settings toolbar button is `Settings`.

Do not drive an `NSOpenPanel` or save panel with System Events. Those scripts hang. Escape dismisses the import agreement and then Settings. Do not dump the contents of an open file panel.

The import agreement's three lines are static text inside the Settings sheet after Import CSV is activated. Confirm the first line still says `saves`.

## Scheme and project shape

- Scheme `EatWatch`: iPhone, iPad, Mac. `SUPPORTED_PLATFORMS` includes `macosx`. Device family 1,2. Deployment 27.0.
- Scheme `EatWatchWatch`: watchOS 27. Not embedded. `PRODUCT_NAME` is `EatWatchWatch`.
- `GENERATE_INFOPLIST_FILE = YES`. Usage strings are `INFOPLIST_KEY_*` build settings, not hand-written plist entries, except background modes.
- The project Debug and Release configurations set `baseConfigurationReference` to `Supporting/AppName.xcconfig`.

## Publishing

This Mac has no `gh` login and no GitHub SSH key. `git push` to `git@github.com` is denied. The GitHub contents API writes text. It encodes the string it is given, so a PNG byte above 127 is stored wrong. The icon bytes stay in `Supporting/AppIcon.base64`. Restore both catalogs with `sh Supporting/restore-icons.sh`. Do not send the PNG through that API.

One request that held the whole tree was rejected for length. Requests under about 80 KB succeeded. `raw.githubusercontent.com` has served a cached older README after a new commit. Read the commit through the API before trusting that cache.

Leave `.build`, DerivedData, `xcuserdata`, Apple portal tokens, and `/Users/alex/Projects/FatWatch` out of the repository.
