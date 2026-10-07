# Implementation Log

What was built and decided, in order. Add an entry for each meaningful change.

## 2026-10: Foundation

### Core package (`TatumTechKit`)

- Built the platform-neutral core first so it could be compiled and tested without a Mac, with the
  Swift 6.4 toolchain on Windows.
- `TatumTechAPIClient` covers every Tatum Tech endpoint over an `HTTPTransport` protocol.
  `LocalJSONTransport` serves bundled JSON for offline development and UI tests.
- `SessionManager`: proactive refresh one hour before expiry, a single shared refresh, sign-out
  only when the server rejects the refresh token.
- `AccountService` combines the API session with stored Google and Apple identities so a Google
  user stays signed in when the API exchange fails.

### Project and configuration

- Xcode 16 project with folder-synchronized groups, so adding files needs no project edits.
- xcconfig, then Info.plist, then `AppConfiguration`. Release forces production and network.
  Secrets go only in the git-ignored `Config/Secrets.xcconfig`.
- The Google Web client ID is committed because it is a public OAuth identifier the backend uses as
  the token audience.

### App

- `AppModel` owns the account phase; `RootView` switches between launch, auth and tabs.
- Auth screens, Home, account sheet, Upcoming Events, Virtual Speakers and Partners.
- UI test mode (`-uiTesting`, `-uiTestingSignedIn`) uses bundled JSON and in-memory credentials.

## 2026-10: Complete feature set

### Core package

- Analytics events, parameters and sanitizers; API failure reporting through
  `APIFailureObserver`.
- `LocalRepository`: profile, demographics, timeline, challenge progress, answer history,
  counters, contact card, connections and recent notifications in one JSON document.
- Coding challenge engine with 2,400 bundled questions: 10-question sessions, a daily limit of 30,
  resumable sessions with stable option order, completions, streaks and stats.
- Catalogs for careers, resources, games and game resources; donation tiers and app links;
  Discord client; contact card JSON and vCard codecs; reminder planning and rating policy.
- Kit tests grew from 70 to 110, all passing.

### App

- Every Home destination is implemented; the pending-feature screen was removed.
- New screens: coding, AI & LLMs, Leet Code and mock interview challenges; Stats, Achievements,
  Timeline; Apply for Jobs, Resources, Community, Donate; Discover Games, Game Details, Get Your
  Game Discovered, Game Resources; Profile, Demographic Info, About, FAQ; Rating prompt; contact
  card editor, My Tatum Tech Card QR, Scanner and scanned-card preview.
- `AppRouter` for per-tab navigation, notification destinations, the scanned-card hand-off and the
  rating prompt.
- Speaker reminders with local notifications and an in-app banner; recent notifications on Home.
- Firebase Analytics and Crashlytics, enabled only when the git-ignored configuration file is
  bundled; uncaught Objective-C exceptions are reported before Crashlytics handles them.
- Apple credential revocation now signs out immediately while the app runs.
- Delete Account moved to the Profile screen; the account sheet links to Profile, Demographic Info,
  About and FAQ.
- Bundle IDs changed to `com.tatumgames.tatumtech.ios` and `.ios.debug` to match the Firebase
  apps.
- Privacy manifest extended with analytics and crash data; camera usage text covers photo capture.

### Decisions

- Behavior defects found in the shared product design were fixed rather than reproduced: mock
  interview language spellings are merged, mock interviews count in stats, resumed sessions keep
  their option order, and the scanner re-arms after an invalid code.
- Code with no reachable behavior (a Change Password screen outside navigation, local event
  registration, sample notifications) was not reproduced.

### Tests

- App unit tests: Home cards and their destinations, analytics screen names, bundled icons, auth
  validation, account restore and deletion, greeting, bundled content.
- UI tests: welcome options, sign-in validation, Home to Partners and Upcoming Events, each Home
  category opening its screens, Timeline and Stats tabs, answering a coding question, creating and
  sharing a contact card, contact card validation, deletion confirmation from Profile.
- The app target and its tests have not been compiled or run yet (no Mac). See TODO.md.

## 2026-10: Firebase Debug and production environments

### Configuration naming

- Kept the two existing build configurations, Debug and Release, and did not add new ones. Each
  already maps to one bundle ID, so a third configuration would only add a way to mismatch them.
  The environment is named in the schemes and the home-screen name instead: **Tatum Tech Debug**
  (Debug: run, test, profile, archive) and **Tatum Tech Prod** (Release: run, profile, archive).
  The generic TatumTech scheme was replaced by these two.

### Configuration files

- Inspected both Firebase files by content. `BUNDLE_ID` `com.tatumgames.tatumtech.ios.debug` with
  app `1:200853064929:ios:fca90eb9865f2e2bd6fba0`, and `com.tatumgames.tatumtech.ios` with app
  `1:200853064929:ios:56260bb200c2ad8fd6fba0`; both in project `tatumtech-mobile-firebase`. They
  match the intended bundle IDs.
- Moved them to `Config/Firebase/Debug/GoogleService-Info.plist` and
  `Config/Firebase/Prod/GoogleService-Info.plist`. `Config/` is not a synchronized group, so
  neither file can be added to the target by accident.
- They stay git-ignored. Firebase iOS API keys are restricted client identifiers, but the
  repository rule is to never commit API keys; build machines and CI receive the files separately.

### Selection and checks

- The "Copy Firebase Configuration" build phase copies only
  `Config/Firebase/$(FIREBASE_CONFIG_DIR)/GoogleService-Info.plist`, removes any previously copied
  file first, and fails when the file's `BUNDLE_ID` differs from `PRODUCT_BUNDLE_IDENTIFIER`. A
  missing file fails Release (`FIREBASE_CONFIG_REQUIRED = YES`) and only warns in Debug. The script
  was exercised with a stand-in for PlistBuddy for the match, swapped, missing-Debug and
  missing-Release cases.
- At launch `FirebaseConfigurationCheck` (kit) compares the bundled file's `BUNDLE_ID` and
  `GOOGLE_APP_ID` with the running bundle ID; Firebase starts with
  `FirebaseApp.configure(options:)` only when they match. The bundle ID decides the environment,
  not the build configuration. Firebase is still configured once, from
  `AppDependencies.live()`, which the SwiftUI `App` creates once at launch; no app delegate is
  needed.
- Crashlytics custom keys `application_id` and `build_type` are set, as on Android.
- Debug builds show environment, bundle ID, Firebase app ID, project and status in the menu
  ("Firebase (Debug build only)"). The section is compiled out of Release. No API key is read
  into it.
- The Debug scheme passes `-FIRAnalyticsDebugEnabled` for DebugView.
- Home-screen names come from `APP_DISPLAY_NAME`: "Tatum Tech Debug" and "Tatum Tech Prod".

### SDK

- The Firebase package requirement was "up to next major from 11.0.0", which could never resolve
  the current release. Raised to 12.19.2 (up to next major), products FirebaseAnalytics and
  FirebaseCrashlytics only. Its shared dependencies (GoogleUtilities 8.x, gtm-session-fetcher,
  promises) overlap with GoogleSignIn-iOS 8.x's requirements.
- Added the **Upload Crashlytics Symbols** build phase. It runs only when the build produces
  dSYMs (Release) and a Firebase file was bundled.

### Analytics audit

- Android sends 8 events, sets no user properties and no user ID, and sets two Crashlytics keys.
  iOS sends the same 8 events with the same parameters; nothing is missing. See
  ANALYTICS_PARITY.md.
- Kit tests: 117 in 15 suites, all passing. Nothing here has been built in Xcode or verified in
  the Firebase console yet (TODO.md, Firebase).

## 2026-10: Sign in with Apple through Firebase Authentication

### Sign-in

- Added the FirebaseAuth product (Firebase 12.19.2). `FirebaseAuthenticating` (kit) wraps it;
  `FirebaseSDKAuthentication` (app) is the SDK adapter and maps Firebase error codes to
  `FirebaseAuthFailure`. Builds without a Firebase configuration use
  `UnavailableFirebaseAuthentication`, so Apple and Google explain that they are unavailable.
- Apple: a single-use random nonce per attempt (`SecRandomCopyBytes`, SHA-256 in the request),
  then `OAuthProvider.appleCredential`, then Firebase sign-in, then the existing
  `AccountService` state. Name and email are kept from the first authorization and never
  replaced by empty values; private relay email is supported.
- Google now also signs in to Firebase before the API exchange. A Firebase failure keeps the user
  signed out; an exchange failure still leaves them signed in with Google only.
- A stored Google or Apple identity counts only while it matches the current Firebase user.
- Welcome order: Sign In, Sign Up, "OR", Sign in with Apple, Sign in with Google.
- Cancellation is silent. Every other failure shows a standard alert with provider-specific copy
  (`AlertMessage.signInFailure`).

### Account

- Sign-out also signs out of Firebase. Email sign-in or sign-up clears any federated identity.
- Apple account deletion reauthorizes with Apple, revokes the token, then deletes the Firebase
  user. Cancelling or a failure keeps the account and shows an alert. Google deletion stays best
  effort.
- No automatic account linking; see AUTHENTICATION.md.

### Analytics

- Added `login` and `sign_up` with `method`, and handled-exception reporting for failed Google
  and Apple sign-ins. Android does not send these yet (ANALYTICS_PARITY.md).

### Tests

- Kit: 131 tests in 16 suites, all passing. App unit and UI tests were added for the nonce,
  alerts, analytics, deletion results and button order; they have not been run (needs a Mac).
