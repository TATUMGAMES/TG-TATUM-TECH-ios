# Tatum Tech for iOS

Native iOS version of the Tatum Tech app by Tatum Games: tech events, virtual speakers, partners,
and (coming) coding challenges, careers and community features. The Android app
([TG-TATUM-TECH-android](https://github.com/TATUMGAMES/TG-TATUM-TECH-android)) is the reference
for product behavior; this app matches its architecture and features using native iOS patterns.

## Requirements

- Xcode 16 or later (the project uses Xcode 16 folder-synchronized groups)
- iOS 17.0+ deployment target, iPhone, portrait, light appearance
- Swift 6 toolchain; the app target compiles in Swift 5 mode with complete concurrency checking,
  and `TatumTechKit` compiles in Swift 6 mode

## Getting started

1. Open `TatumTech.xcodeproj`. Xcode resolves the two packages: the local `Packages/TatumTechKit`
   and [GoogleSignIn-iOS](https://github.com/google/GoogleSignIn-iOS).
2. Copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` (git-ignored) and set at
   least `DEVELOPMENT_TEAM` to run on a device. Every other value is optional.
3. Select the **TatumTech** scheme and run.

With no local secrets the app still runs: email sign-in and content use the production API, Sign
in with Apple works once the team has the capability, and the Google button explains that Google
sign-in is unavailable. See [TODO.md](TODO.md) for what is still needed.

## Configuration

Build settings flow from `Config/*.xcconfig` into `Config/Info.plist`, where
`AppConfiguration.resolve` reads them at launch.

| Setting | Purpose |
| --- | --- |
| `TATUM_TECH_ENVIRONMENT` | `production` or `stage` (Debug only) |
| `TATUM_TECH_DATA_SOURCE` | `network` or `LOCAL_JSON` (Debug only) |
| `TATUM_TECH_API_KEY` | Optional `x-api-key` header |
| `GOOGLE_IOS_CLIENT_ID` / `GOOGLE_REVERSED_CLIENT_ID` | iOS OAuth client for Google sign-in |
| `GOOGLE_SERVER_CLIENT_ID` | Public Web client ID used as the ID token audience |

Release builds always use the production API over the network and never log HTTP traffic. Never
commit credentials, private keys or provisioning profiles; `Config/Secrets.xcconfig` is the only
place for machine-local values.

## Project layout

```
Config/                    xcconfigs, Info.plist, entitlements
Packages/TatumTechKit/     Platform-neutral core: networking, API client, models, session, account
TatumTech/
  App/                     Entry point, AppModel, dependency wiring, root view
  DesignSystem/            Palette, spacing, button styles
  Components/              Shared views (images, alerts, form fields, load states, pending screens)
  Features/                Auth, Main (tabs and routes), Home, Events, Partners
  Resources/               Asset catalog, bundled JSON, privacy manifest, string catalog
TatumTechTests/            Unit tests hosted in the app
TatumTechUITests/          UI tests that run offline
docs/                      Design, architecture, parity and history
```

## Testing

- **Core package:** `cd Packages/TatumTechKit && swift test` (also runs on Linux and Windows).
- **App:** run the **TatumTech** scheme's tests in Xcode (Cmd-U). This runs the app unit tests,
  the package tests and the UI tests.
- UI tests launch with `-uiTesting` (and `-uiTestingSignedIn` to start signed in). In that mode
  the app uses bundled JSON, in-memory credentials and no external sign-in, so no network or
  account is needed.

## Documentation

- [docs/APP_DESIGN.md](docs/APP_DESIGN.md): screens, navigation and visual design
- [docs/ANDROID_TO_IOS_ARCHITECTURE.md](docs/ANDROID_TO_IOS_ARCHITECTURE.md): how Android concepts map to iOS
- [docs/IOS_FEATURE_PARITY.md](docs/IOS_FEATURE_PARITY.md): feature-by-feature status
- [docs/PLATFORM_DIFFERENCES.md](docs/PLATFORM_DIFFERENCES.md): intentional differences from Android
- [docs/IMPLEMENTATION_LOG.md](docs/IMPLEMENTATION_LOG.md): what was built and decided, in order
- [TODO.md](TODO.md): open work, blockers and required external configuration
