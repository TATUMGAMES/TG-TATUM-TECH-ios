# TODO

External configuration and verification the app still needs. Every feature is implemented in code;
the items below need access, accounts, assets or hardware that are not in this repository.

Never put credentials, keys or tokens in this file.

## Verification (needs a Mac)

### Build, run and test the app in Xcode
- **What:** Open the project, resolve packages (GoogleSignIn-iOS, firebase-ios-sdk), build for a
  simulator and a device, and run all tests (Cmd-U).
- **Why:** The app target and its tests have not been compiled. Only `TatumTechKit` was built and
  tested (110 tests, Swift 6.4 toolchain on Windows).
- **Where:** `TatumTech/`, `TatumTechTests/`, `TatumTechUITests/`, `TatumTech.xcodeproj`.
- **Blocks release:** Yes.
- Check in particular: camera QR scanning on a device, the system New Contact screen after saving
  a scanned card, the vCard QR being readable by the iOS Camera app, local notification delivery
  for speaker reminders (use the debug "Test reminder in 10 s" button), Safari checkout for
  donations, and the rating prompt on the 20th app open.

### Firebase DebugView check
- **What:** Run a Debug build with `-FIRDebugEnabled` and confirm every event in
  `docs/ANALYTICS_PARITY.md` arrives with its parameters.
- **Blocks release:** No, but needed to mark analytics as verified at runtime.

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

### Firebase configuration files and Crashlytics symbols
- **What:** Keep `GoogleService-Info Debug.plist` and `GoogleService-Info Prod.plist` in the
  repository root on build machines (they are git-ignored; distribute them through a secure
  channel, never through git). Add the Crashlytics "upload symbols" run-script phase in Xcode
  (`${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run`) so crash
  reports are symbolicated.
- **Blocks release:** No (the app runs without them, with analytics off).

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
