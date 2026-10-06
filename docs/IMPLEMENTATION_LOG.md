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
