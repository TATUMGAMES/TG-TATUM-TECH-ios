# Architecture

How the Tatum Tech iOS app is built: a platform-neutral core package and a SwiftUI app layer.

## Layers

| Concern | Implementation |
| --- | --- |
| UI | SwiftUI views, one folder per feature under `TatumTech/Features` |
| Screen state | `@MainActor @Observable` models owned by views through `@State`, or view-local state for simple screens |
| App state | `AppModel`: account phase (launching, signed out, signed in), local profile, services |
| Navigation | `AppRouter`: selected tab, one `NavigationStack` path per tab, typed `AppRoute` values, one-time hand-offs (scanned card), rating prompt trigger |
| Dependency wiring | `AppDependencies`, built once at launch (live, or offline for UI tests) |
| Networking | `TatumTechAPIClient` over an `HTTPTransport` protocol (`URLSessionTransport` in production, `LocalJSONTransport` for bundled data) |
| Content | `ContentRepository` for events, speakers and partners; `BundledCatalog` for challenges, achievements, careers, resources and games |
| Local data | `LocalRepository` actor over a JSON document (see [LOCAL_DATA.md](LOCAL_DATA.md)) |
| Session and credentials | `SessionManager` actor, Keychain through `SecureStore` |
| Sign-in | Email via the API; Google (GoogleSignIn SDK behind `GoogleSignInProviding`) and Apple (AuthenticationServices) both verified by Firebase Authentication behind `FirebaseAuthenticating`. See [AUTHENTICATION.md](AUTHENTICATION.md) |
| Reminders | `MeetingReminderCenter` (UserNotifications) driven by `MeetingReminderPlanner` in the kit |
| Analytics | `AnalyticsService` in the kit; Firebase Analytics and Crashlytics clients in the app, started only after `FirebaseConfigurationCheck` confirms the bundled configuration belongs to the running bundle ID |
| Configuration | xcconfig, then Info.plist, then `AppConfiguration.resolve` |
| Tests | Swift Testing (kit and app), XCUITest (UI) |

## Core package: TatumTechKit

Everything that does not need UIKit or SwiftUI lives in `Packages/TatumTechKit`. It compiles on
Linux and Windows too, so its tests run anywhere.

- `Networking/`: transports (URLSession and bundled JSON), `APIError`, server message parsing,
  timeouts, traffic logging with header and body redaction, the API failure observer, and the
  contact card codecs (JSON payload and vCard, own-card detection, connections).
- `API/`: `TatumTechAPIClient` (sign-in, sign-up, refresh, password reset, sign-out, profile,
  events, speakers, partners), DTOs and lenient decoding.
- `Configuration/`: `AppConfiguration` (environment, data source, logging) and
  `FirebaseEnvironment` (bundle ID to Firebase app mapping and the configuration check).
- `Models/` and `Content/`: `Event`, `Speaker`, `Partner`, `ImageSource`, formatting, repository.
- `Session/` and `Account/`: session lifetime, Keychain storage, `AccountService` combining the API
  session with stored Google and Apple identities, credential rules, error copy.
- `Persistence/`: `LocalData`, `LocalRepository`, `PersistentStore`, networking data and recent
  notifications.
- `Stats/`: achievements, stats summary and timeline filters.
- `Challenges/`: question bank, session builder, `ChallengeEngine` (sessions, daily limit,
  scoring, resume, completions).
- `Catalogs/` and `Games/`: careers, resources, games, game resources, donation tiers, app links.
- `Community/`: `DiscordClient` for live server info.
- `Reminders/`: reminder planning and delivery rules, rating policy.
- `Analytics/`: events, parameters, sanitizers, service.

The package uses Swift 6 language mode with strict concurrency; services are actors or `Sendable`
value types.

## App layer

- `App/`: `TatumTechApp`, `RootView`, `AppModel`, `AppRouter`, `AppDependencies`,
  `BundledCatalog`, `ContactCardImageStore`, `FirebaseServices`, `FirebaseAuthentication`.
- `Features/<Name>/`: views and their models. Models receive services in their initializer and
  expose plain state.
- `Components/` and `DesignSystem/`: shared views (toast, Safari, form fields, GIFs, confetti,
  content images) and styling.

## Key behaviors

- **Session lifetime:** access tokens refresh one hour before expiry with a single shared request;
  only a 400, 401, 403 or 419 (`REFRESH_TOKEN_DOES_NOT_EXIST`) from the refresh endpoint signs the
  user out. Network errors never do.
- **Response envelope:** the API answers `{"status":{"statusCode":N,"statusMessage":"CODE"},"data":{...}}`
  and reports most failures inside an HTTP 200 response, e.g. `PASSWORDS_DO_NOT_MATCH` with
  status 406. `TatumTechAPIClient` turns any non-2xx `status.statusCode` into
  `APIError.http(statusCode:messages:)`, including on endpoints without data (forgot/reset
  password, sign-out, profile update), so a rejected request is never reported as success.
- **API errors:** `APIErrorClassifier` is the only place that interprets statuses, server codes
  and transport failures. It yields an `APIErrorKind` (network, timeout, 400, 401, 403, 404, 409,
  429, 5xx, invalid response, unknown); known codes such as `USER_ALREADY_EXISTS` take precedence
  over the status, and server text is kept only if `SafeServerMessage` accepts it.
  `APIErrorPresentation` chooses the copy for an `APIOperation`, and `AlertMessage.apiFailure`
  localizes it: request-specific failures are titled after the operation ("Unable to Create Your
  Account"), connectivity and service failures use "We’ve Encountered an Issue". Network, timeout,
  429 and 5xx failures offer "Try Again", which only runs when the user taps it.
- **API failure log:** Debug builds write one entry per failed call to the unified log (category
  `API`) through `APIErrorLog`: environment, method, path, HTTP and API status, server code, error
  type, exception, duration and a summarized response body with credentials masked. Request
  bodies, headers and query strings are never included. The API does not return a request ID.
  At launch Debug builds also log the selected environment, base URL and why it was chosen.
- **Google sign-in:** Firebase verifies the Google credential first; a Firebase failure keeps the
  user signed out. Then the ID token is exchanged with the API (10-second limit). If the exchange
  fails the user stays signed in with Google only.
- **Apple sign-in:** single-use random nonce (SHA-256 in the request), verified by Firebase.
  Revoked credentials sign the user out at launch and immediately while the app runs. Deleting an
  Apple account reauthorizes with Apple, revokes the token and deletes the Firebase user.
- **Offline first:** challenges, stats, timeline, careers, resources and games work without a
  network. Events, speakers, partners and Discord need the network in normal builds.
- **Navigation from notifications:** reminder taps and recent notifications go through
  `AppRouter.open(_:)`, which selects the right tab and pushes the destination.

## Design choices

- `@Observable` models and structured concurrency instead of lifecycle-bound callbacks.
- One scene switching on `AppModel.phase` for launch, auth and the main tabs.
- A single JSON document for local data: small, atomic writes, easy to erase on account deletion.
- Protocols at external boundaries (`HTTPTransport`, `SecureStore`, `GoogleSignInProviding`,
  `AppleCredentialStateChecking`, `AppleReauthorizing`, `FirebaseAuthenticating`, `AnalyticsClient`) keep the app testable without the network or
  real accounts.
