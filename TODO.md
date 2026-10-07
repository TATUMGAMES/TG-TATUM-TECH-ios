# TODO

External configuration and verification the app still needs. Every feature is implemented in code;
the items below need access, accounts, assets or hardware that are not in this repository.

Never put credentials, keys or tokens in this file.

## Verification (needs a Mac)

### Build, run and test the app in Xcode
- **What:** Open the project, resolve packages (GoogleSignIn-iOS, firebase-ios-sdk), build for a
  simulator and a device, and run all tests (Cmd-U).
- **Why:** The app target and its tests have not been compiled. Only `TatumTechKit` was built and
  tested (117 tests, Swift 6.4 toolchain on Windows).
- **Where:** `TatumTech/`, `TatumTechTests/`, `TatumTechUITests/`, `TatumTech.xcodeproj`.
- **Blocks release:** Yes.
- Check in particular: camera QR scanning on a device, the system New Contact screen after saving
  a scanned card, the vCard QR being readable by the iOS Camera app, local notification delivery
  for speaker reminders (use the debug "Test reminder in 10 s" button), Safari checkout for
  donations, and the rating prompt on the 20th app open.

## Firebase

Status of the Debug and production Firebase environments. "Done" means implemented in the
repository; nothing here has been verified on a device or in the Firebase console yet.

| Item | Status |
| --- | --- |
| Configuration files present for both apps, `BUNDLE_ID` matching each bundle ID | Done (checked locally; files are git-ignored) |
| One file bundled per build, chosen by configuration, mismatch fails the build | Done in the build phase; build not yet run in Xcode |
| Bundle ID and Firebase app ID checked at launch before Firebase starts | Done; logic unit tested in `TatumTechKit` |
| Schemes "Tatum Tech Debug" (Debug) and "Tatum Tech Prod" (Release, archive) | Done; not yet opened in Xcode |
| Firebase SDK 12.19.2 (Analytics, Crashlytics) resolves and builds | Not verified |
| Debug build sends events to the Debug Firebase app | Not verified |
| Release build sends events to the production Firebase app | Not verified |
| Crashlytics reports and dSYM upload | Not verified |

### Build both environments in Xcode
- **What:** Resolve packages (Firebase 12.19.2 must resolve alongside GoogleSignIn-iOS 8.x).
  Build and run the Tatum Tech Debug scheme; confirm the build log shows "Bundled Firebase
  configuration from Config/Firebase/Debug" and the menu's "Firebase (Debug build only)" section
  shows `com.tatumgames.tatumtech.ios.debug` and app ID `1:200853064929:ios:fca90eb9865f2e2bd6fba0`
  with status Running. Archive the Tatum Tech Prod scheme and confirm the archived app's
  `GoogleService-Info.plist` has `BUNDLE_ID` `com.tatumgames.tatumtech.ios`.
- **Also check:** swapping the two files makes both builds fail with a bundle ID error, and a
  Release build without `Config/Firebase/Prod/GoogleService-Info.plist` fails.
- **Blocks release:** Yes.

### Firebase DebugView check (Debug app)
- **What:** Run the Tatum Tech Debug scheme (it passes `-FIRAnalyticsDebugEnabled`) and confirm in
  the Firebase console, under the iOS app `com.tatumgames.tatumtech.ios.debug`, that every event in
  `docs/ANALYTICS_PARITY.md` arrives with its parameters, and that nothing arrives under the
  production app.
- **Blocks release:** No, but needed to mark analytics as verified at runtime.

### Production routing check
- **What:** Install a Release build (TestFlight or an ad hoc archive), trigger a few events and a
  test non-fatal, and confirm they appear under the iOS app `com.tatumgames.tatumtech.ios` and not
  under the Debug app. Analytics reports can take up to 24 hours outside DebugView.
- **Blocks release:** Yes, if analytics is a release requirement.

### Crashlytics symbols
- **What:** After archiving with Tatum Tech Prod, confirm the **Upload Crashlytics Symbols**
  phase uploaded the dSYM (Firebase console, Crashlytics, dSYMs). If CI uses a custom package
  checkout directory, point the phase at that directory's `firebase-ios-sdk/Crashlytics/run`.
- **Blocks release:** No, but crash reports are unreadable without symbols.

### Configuration files on build machines and CI
- **What:** Place `Config/Firebase/Debug/GoogleService-Info.plist` and
  `Config/Firebase/Prod/GoogleService-Info.plist` on every build machine. In CI, store them as
  secrets and write them to those paths before building. They are git-ignored because they
  contain API keys.
- **Blocks release:** Yes for Release builds (they fail without the production file).

### Google sign-in client IDs from the Firebase apps
- **What:** Both configuration files contain an iOS OAuth client for their bundle ID. Decide
  whether to use them for Google sign-in by setting `GOOGLE_IOS_CLIENT_ID` and
  `GOOGLE_REVERSED_CLIENT_ID` per configuration in `Config/Secrets.xcconfig`. See "Google iOS
  OAuth clients" below.
- **Blocks release:** Only if Google sign-in ships on iOS.

### Home-screen names
- **What:** Confirm the production home-screen name. Release builds currently show
  "Tatum Tech Prod" (`APP_DISPLAY_NAME` in `Config/Release.xcconfig`); the App Store listing
  name is set separately in App Store Connect.
- **Blocks release:** No.

## External configuration

### Apple Developer team and capabilities
- **What:** Set `DEVELOPMENT_TEAM` in `Config/Secrets.xcconfig`; register App IDs
  `com.tatumgames.tatumtech.ios` and `com.tatumgames.tatumtech.ios.debug` with Sign in with Apple.
- **Blocks release:** Yes.

### Google iOS OAuth clients
- **What:** Create iOS OAuth clients for both bundle IDs in the Google Cloud project that owns the
  Web client, then set `GOOGLE_IOS_CLIENT_ID` and `GOOGLE_REVERSED_CLIENT_ID`.
- **Why:** Until then the Google button explains that Google sign-in is unavailable.
- **Blocks release:** Yes, if Google sign-in ships on iOS.

### App Store Connect record
- **What:** Create the app record and set `APP_STORE_ID` in `Config/Shared.xcconfig`.
- **Why:** The rating prompt opens the App Store review page with this ID. Without it the app uses
  the system in-app review request instead.
- **Blocks release:** No.

### Backend: delete account endpoint
- **What:** An endpoint that deletes the user's server-side account.
- **Why:** Delete Account signs out and erases all on-device data. App Store Review Guideline
  5.1.1(v) expects server-side deletion for accounts created in the app.
- **Blocks release:** Likely yes for App Store review.

### Backend: Sign in with Apple endpoint
- **What:** An endpoint that verifies an Apple identity token and nonce and issues a Tatum Tech
  session.
- **Why:** Apple sign-ins currently stay on the device and cannot call authenticated APIs.
- **Blocks release:** No.

### Backend: sign-in route
- **What:** Confirm `POST tatum-tech/signin` is deployed (it returned 404 when last checked).
- **Blocks release:** Yes, for email and Google sign-in.

### Final app icon
- **What:** A 1024×1024 opaque icon from design for `Assets.xcassets/AppIcon.appiconset`.
- **Why:** The current icon is upscaled from a smaller source.
- **Blocks release:** Yes.

### Event flyer image
- **What:** The bundled event data references `tatum_tech_placeholder_flyer_01`, which is not in
  the design assets. Provide the image or update the event data.
- **Blocks release:** No (a neutral image is shown).
