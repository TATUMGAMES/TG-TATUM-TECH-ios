# Implementation Log

What was built and decided, in order. Add an entry for each meaningful change.

## 2026-10 — Initial implementation

### Core package (`TatumTechKit`)

- Built the platform-neutral core first so it could be compiled and tested without a Mac. Its
  70 Swift Testing tests pass with the Swift 6.4 toolchain on Windows.
- `TatumTechAPIClient` covers every endpoint the Android client calls, over an `HTTPTransport`
  protocol. `LocalJSONTransport` serves the Android sample JSON for offline development.
- `SessionManager` mirrors the Android session rules: proactive refresh one hour before expiry, a
  single shared refresh, sign-out only when the server rejects the refresh token.
- `AccountService` combines the API session with stored Google/Apple identities so a Google user
  stays signed in when the API exchange fails, as on Android.
- Fixes found while testing on Windows: `waitsForConnectivity` removed (default is already false),
  a bare `Bearer` header is treated as no token, test locking uses `withLock`.

### Project and configuration

- Xcode 16 project with folder-synchronized groups, so adding files needs no project edits.
- xcconfig, then Info.plist, then `AppConfiguration`. Release forces production and network.
  Secrets go only in the git-ignored `Config/Secrets.xcconfig`.
- The Google Web client ID is committed because it is a public OAuth identifier the backend uses
  as the token audience. The iOS client ID is left blank until it is created.

### Assets

- Brand colors, feature icons, partner logos, speaker photos and social icons copied from the
  Android resources. Colors are named asset-catalog colors used through `Palette`.
- The app icon is a placeholder made from the Android adaptive icon foreground.

### App

- `AppModel` owns the account phase; `RootView` switches between launch, auth and tabs.
- Auth: email sign-in, sign-up and forgot password with Android validation and copy; Google behind
  `GoogleSignInProviding` (an unavailable implementation is used until a client ID exists); Sign in
  with Apple with a SHA-256 nonce and launch-time revocation check.
- Home, account sheet, Upcoming Events, Virtual Speakers and Partners match the Android screens.
  Every other Android destination opens a pending screen so navigation is complete.
- UI test mode (`-uiTesting`, `-uiTestingSignedIn`) uses bundled JSON and in-memory credentials.

### Tests

- App unit tests: home catalog parity and bundled icons, auth form validation and error mapping,
  account restore and deletion, bundled content loading.
- UI tests: welcome options, sign-in validation, Home to Partners and Upcoming Events, account
  deletion confirmation.
- The app layer has not been compiled yet (no Mac was available). See TODO.md.
