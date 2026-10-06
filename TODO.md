# TODO

Open work for the iOS app. Each entry says what is needed, why, where it applies, what it unlocks,
whether it blocks release, and whether an AI agent can do it without outside help. Keep this file
current: remove entries when done and record them in `docs/IMPLEMENTATION_LOG.md`.

Never put credentials, keys or tokens in this file.

## Needs a Mac (verification)

### Build and run the app in Xcode
- **What:** Open the project, resolve packages, build, run on a simulator, run all tests (Cmd-U).
- **Why:** The app layer was written without access to Xcode; only `TatumTechKit` has been compiled
  and tested.
- **Where:** Whole `TatumTech/`, `TatumTechTests/`, `TatumTechUITests/`, `TatumTech.xcodeproj`.
- **Value:** Confirms everything compiles and the UI matches `docs/APP_DESIGN.md`.
- **Blocks release:** Yes.
- **AI can continue:** Yes, once build output is shared. Fixing compile errors is routine.
- Things to check in particular: the partner detail sheet dismissing before the contact picker
  appears; the Google image button scaling; paged home grid height with large Dynamic Type; UI test
  identifiers resolving on image buttons.

## External configuration

### Google iOS OAuth client
- **What:** Create an iOS OAuth client for `com.tatumgames.tatumtech` in the Google Cloud project
  that owns the Web client, then set `GOOGLE_IOS_CLIENT_ID` and `GOOGLE_REVERSED_CLIENT_ID` in
  `Config/Secrets.xcconfig` (or in `Shared.xcconfig`, since client IDs are not secret).
- **Why:** Google sign-in needs a client ID registered for the iOS bundle ID.
- **Where:** `Config/*.xcconfig`, `GoogleSignInProviderFactory`.
- **Value:** Enables Google sign-in; until then the button shows the "unavailable" message.
- **Blocks release:** Yes, if Google sign-in should ship on iOS.
- **AI can continue:** No. Needs Google Cloud console access.

### Apple Developer team and Sign in with Apple
- **What:** Set `DEVELOPMENT_TEAM`, register the App ID with the Sign in with Apple capability.
- **Why:** Signing and the Apple sign-in entitlement.
- **Where:** `Config/Secrets.xcconfig`, Apple Developer portal.
- **Value:** Device builds, Sign in with Apple, TestFlight.
- **Blocks release:** Yes.
- **AI can continue:** No.

### Backend: Sign in with Apple endpoint
- **What:** An API endpoint that verifies an Apple identity token (and nonce) and issues a Tatum
  Tech session.
- **Why:** Apple sign-ins are stored on the device only and cannot call authenticated APIs.
- **Where:** Backend; then `TatumTechAPIClient`, `AccountService.completeAppleSignIn`.
- **Value:** Apple users get a full account (profile, future authenticated features).
- **Blocks release:** No (current behavior is usable), but needed before authenticated features.
- **AI can continue:** iOS side yes, once the endpoint contract exists.

### Backend: delete account endpoint
- **What:** An endpoint that deletes the user's server data.
- **Why:** Delete Account currently signs out and clears local data, as on Android. App Store
  Guideline 5.1.1(v) requires deleting the account, not only signing out.
- **Where:** Backend; then `AppModel.deleteAccount`.
- **Blocks release:** Likely yes for App Store review.
- **AI can continue:** iOS side yes, once the endpoint exists.

### Backend: sign-in route
- **What:** `POST tatum-tech/signin` returned 404 when last checked from Android.
- **Why:** Email and Google sign-in depend on it.
- **Blocks release:** Yes.
- **AI can continue:** No.

### Final app icon
- **What:** A 1024×1024 opaque icon from design.
- **Why:** The current icon is upscaled from the Android foreground and is a placeholder.
- **Where:** `Assets.xcassets/AppIcon.appiconset`.
- **Blocks release:** Yes.
- **AI can continue:** No (needs the design asset).

### Firebase Analytics (optional)
- **What:** Decide whether iOS should report analytics like Android. If yes, add the Firebase SDK
  and a `GoogleService-Info.plist` provided outside git, and update the privacy manifest.
- **Blocks release:** No.
- **AI can continue:** Partly; needs the plist and a product decision.

## Features to build

Each needs no outside help unless noted. None blocks a first release unless product decides so.

- **Scanner and contact card:** QR generation (Core Image) and scanning (AVFoundation) with the
  Android vCard and legacy payload formats; needs `NSCameraUsageDescription`.
- **Meeting reminders:** local notifications before events the user registered for, with a
  permission prompt and in-app banner like Android.
- **Recent notifications:** local store (SwiftData) and list screen.
- **Networking section** on Upcoming Events.
- **Coding challenges, AI challenges, stats, resources, community, donate, careers, Leet Code,
  mock interviews, discover games, game resources, timeline:** replace the pending screens. Most
  need backend endpoints that are not yet defined.
- **Profile, Demographic, About, FAQ** screens from the account sheet.
- **Apple credential revocation while running:** observe
  `ASAuthorizationAppleIDProvider.credentialRevokedNotification` and sign out immediately (today
  it is checked at launch).

## Content

- **Missing event flyer:** the bundled event JSON references `tatum_tech_placeholder_flyer_01`,
  which exists in neither app. iOS shows a placeholder; add the image or update the data.

## Maintenance

- **GoogleSignIn package:** pinned "up to next major" from 8.0.0; review on each major release.
- **Localization:** strings are in code and collected by `Localizable.xcstrings`; add languages when
  Android does.
