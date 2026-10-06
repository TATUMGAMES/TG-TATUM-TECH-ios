# Android to iOS Architecture

The iOS app matches the Android app's architecture and behavior, not its source code. This page
maps each Android building block to its iOS counterpart and explains why.

## Layers

| Concern | Android | iOS |
| --- | --- | --- |
| UI | Jetpack Compose screens | SwiftUI views |
| Screen state | Composable `remember` state and callbacks | `@MainActor @Observable` feature models owned by views via `@State` |
| App state | `MainActivity` / `AuthActivity` split | `AppModel.phase` switching between auth flow and tabs in one scene |
| Navigation | Navigation Compose `NavGraph` and `NavRoutes` | `NavigationStack` with typed `AuthRoute` / `AppRoute` values |
| Dependency wiring | `TatumTechApiProvider`, application singletons | `AppDependencies` built once at launch, passed through `AppModel` in the environment |
| Networking | OkHttp/Retrofit-style `TatumTechApiClient` | `TatumTechAPIClient` over an `HTTPTransport` protocol (`URLSession` in production) |
| Local JSON mode | `LocalJsonRequestExecutor` | `LocalJSONTransport` reading bundled JSON |
| Data sources | `TatumTechDataSources`, `TatumTechContentRepository` | `ContentRepository` protocol and `APIContentRepository` |
| Session | `TatumTechSessionManager`, `KeystoreSessionStore` | `SessionManager` actor, `SecureValue` over `KeychainStore` |
| Google sign-in | Credential Manager + Firebase Auth | GoogleSignIn SDK behind `GoogleSignInProviding` |
| Apple sign-in | Not available | `AuthenticationServices` (`SignInWithAppleButton`) |
| Configuration | `BuildConfig` fields from Gradle | xcconfig, then Info.plist, then `AppConfiguration.resolve` |
| Logging | OkHttp logging interceptor (debug) | `HTTPTrafficLogger` with redaction, `os.Logger` (Debug only) |
| Tests | JUnit, Robolectric, instrumented tests | Swift Testing (kit and app), XCUITest (UI) |

## Core package: TatumTechKit

All logic that does not need UIKit or SwiftUI lives in the local Swift package
`Packages/TatumTechKit`. It compiles on Linux and Windows too, so its tests run anywhere.

- `Networking/`: `HTTPTransport`, `URLSessionTransport`, `LocalJSONTransport`, `APIError`,
  server error message parsing, timeouts, traffic logging with header/body redaction.
- `API/`: `TatumTechAPIClient` with every endpoint the Android client calls (sign-in, sign-up,
  refresh, forgot/reset password, sign-out, profile update, events, speakers, partners), DTOs and
  lenient decoding (numbers or strings for IDs, missing optional fields).
- `Models/`: app-facing `Event`, `Speaker`, `Partner`, `ImageSource`, formatting helpers.
- `Content/`: `ContentRepository` that maps DTOs to models.
- `Session/`: `TatumTechSession`, `SessionManager` (sign-in, proactive refresh one hour before
  expiry with a single in-flight refresh, sign-out with timeout), `SecureStore` implementations.
- `Account/`: `AccountService` combining the API session with stored Google/Apple identities,
  credential rules, and auth error copy.

The package uses Swift 6 language mode with strict concurrency; services are actors or `Sendable`
value types.

## App layer

- `App/`: `TatumTechApp` (entry point), `AppModel` (account phase and services),
  `AppDependencies` (live vs UI-test wiring), `RootView`.
- `Features/<Name>/`: views plus their `@Observable` model. Models receive services in their
  initializer and expose plain state (`LoadState`, form fields, alerts).
- `Components/` and `DesignSystem/`: shared views and styling.

## Key behaviors carried over from Android

- **Session lifetime:** access tokens refresh before expiry; only a 400/401/403 from the refresh
  endpoint signs the user out. Network errors never do.
- **Google sign-in:** the Google identity is stored first, then the ID token is exchanged with the
  API (10-second limit). If the exchange fails the user stays signed in with Google only, exactly
  as Android keeps a Firebase user without an API session.
- **Content:** the same endpoints and the same bundled JSON (copied from Android assets) for local
  mode.
- **Copy:** user-facing text is reused from Android `strings.xml` wherever Android defines it.

## Why not a literal port

- SwiftUI's `@Observable` and structured concurrency replace Android's lifecycle-bound state and
  coroutine scopes with less code.
- One scene with a phase switch replaces two activities; iOS has no activity concept.
- Keychain replaces the Android Keystore-encrypted store; Keychain items are already encrypted at
  rest, so no extra cipher layer is needed.
- Protocols at external boundaries (`HTTPTransport`, `SecureStore`, `GoogleSignInProviding`,
  `AppleCredentialStateChecking`) make the app testable without the network or real accounts.
