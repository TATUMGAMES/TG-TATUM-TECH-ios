# Tatum Tech for iOS

Tatum Tech by Tatum Games is a companion app for the Tatum Tech community: tech events and
virtual speakers, partner organizations, coding challenges, career listings, games, and
networking with QR contact cards.

## Features

- **Accounts:** email sign-in, sign-up and password reset; Google sign-in; Sign in with Apple;
  profile, demographic info and account deletion.
- **Home:** greeting, category pager (Events, Coding, Community, Career, Games), feature cards and
  recent notifications.
- **Events:** upcoming events with full-screen flyers, Luma registration, virtual speakers with
  Google Meet links, and local reminders before each speaker session.
- **Networking:** create a contact card (with photo), share it as a vCard QR code any phone camera
  can read, scan other attendees' cards, and save them to Contacts.
- **Partners:** directory with categories, details, contact, website and donation links.
- **Challenges:** coding (C#, Java, JavaScript, Kotlin, Python), AI & LLMs, Leet Code and mock
  interviews at three levels each. 2,400 questions ship with the app, so challenges work offline.
  Sessions of 10 questions, a daily limit of 30 answers, resumable sessions, streaks and
  achievements.
- **Progress:** stats, 30 achievements and an activity timeline.
- **Career and learning:** job listings with search and filters, learning resources.
- **Community:** live Discord server info, invite sharing, and donation tiers.
- **Games:** featured games, carousels with genre and gameplay filters, game details with media,
  store links and socials, game development resources, and MIKROS information.
- **Rating prompt:** shown every 20 app opens and after completing a coding challenge session.

## Requirements

- Xcode 16 or later (folder-synchronized groups)
- iOS 17.0+, iPhone, portrait, light appearance
- Swift 6 toolchain. The app target compiles in Swift 5 mode with complete concurrency checking;
  `TatumTechKit` compiles in Swift 6 mode.

## Getting started

1. Open `TatumTech.xcodeproj`. Xcode resolves the local `Packages/TatumTechKit` package and the
   remote packages (GoogleSignIn-iOS, Firebase).
2. Copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` (git-ignored) and set
   `DEVELOPMENT_TEAM` to run on a device. Every other value is optional.
3. Optional: place the Firebase configuration files `GoogleService-Info Debug.plist` and
   `GoogleService-Info Prod.plist` in the repository root. They are git-ignored and must never be
   committed. Without them the app runs with analytics and crash reporting turned off.
4. Select the **TatumTech** scheme and run.

With no local configuration the app still runs: content uses the production API, challenges and
catalogs use bundled data, Sign in with Apple works once the team has the capability, and the
Google button explains that Google sign-in is unavailable. [TODO.md](TODO.md) lists the external
setup that is still required.

## Configuration

Build settings flow from `Config/*.xcconfig` into `Config/Info.plist`, where
`AppConfiguration.resolve` reads them at launch.

| Setting | Purpose |
| --- | --- |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.tatumgames.tatumtech.ios` (Release), `com.tatumgames.tatumtech.ios.debug` (Debug) |
| `TATUM_TECH_ENVIRONMENT` | `production` or `stage` (Debug only) |
| `TATUM_TECH_DATA_SOURCE` | `network` or `LOCAL_JSON` (Debug only) |
| `TATUM_TECH_API_KEY` | Optional `x-api-key` header |
| `GOOGLE_IOS_CLIENT_ID` / `GOOGLE_REVERSED_CLIENT_ID` | iOS OAuth client for Google sign-in |
| `GOOGLE_SERVER_CLIENT_ID` | Public Web client ID used as the ID token audience |
| `APP_STORE_ID` | Numeric App Store ID for the "rate the app" link |
| `FIREBASE_PLIST_VARIANT` | Which `GoogleService-Info <variant>.plist` is bundled |

Release builds always use the production API over the network and never log HTTP traffic. Never
commit credentials, private keys, provisioning profiles or Firebase configuration files;
`Config/Secrets.xcconfig` is the only place for machine-local values.

## Project layout

```
Config/                    xcconfigs, Info.plist, entitlements
Packages/TatumTechKit/     Platform-neutral core: API client, session, account, local data,
                           challenges, catalogs, contact card codecs, reminders, analytics
TatumTech/
  App/                     Entry point, AppModel, AppRouter, dependency wiring, Firebase setup
  DesignSystem/            Palette, spacing, button styles
  Components/              Shared views (images, toasts, form fields, Safari, GIFs, confetti)
  Features/                One folder per area: Auth, Main, Home, Events, Networking, Partners,
                           Challenges, Stats, Career, Resources, Community, Games, Profile,
                           About, Rating, Reminders
  Resources/               Asset catalog, bundled JSON, animations, privacy manifest, strings
TatumTechTests/            App unit tests
TatumTechUITests/          UI tests that run offline
docs/                      Design, architecture, data, analytics, assets, audit, release
```

## Testing

- **Core package:** `cd Packages/TatumTechKit && swift test`. It also runs on Linux and Windows.
- **App:** run the **TatumTech** scheme's tests in Xcode (Cmd-U): app unit tests, package tests
  and UI tests.
- UI tests launch with `-uiTesting` (plus `-uiTestingSignedIn` to start signed in). In that mode
  the app uses bundled JSON, in-memory storage and credentials, and no external sign-in, so no
  network or account is needed.

## Documentation

- [docs/APP_DESIGN.md](docs/APP_DESIGN.md): screens, navigation and visual design
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): layers, modules and key behaviors
- [docs/LOCAL_DATA.md](docs/LOCAL_DATA.md): what is stored on the device and where
- [docs/ANALYTICS_PARITY.md](docs/ANALYTICS_PARITY.md): every analytics event and its parameters
- [docs/ASSET_PARITY.md](docs/ASSET_PARITY.md): images, colors, animations and bundled content
- [docs/FEATURE_PARITY_AUDIT.md](docs/FEATURE_PARITY_AUDIT.md): feature-by-feature audit
- [docs/PLATFORM_DIFFERENCES.md](docs/PLATFORM_DIFFERENCES.md): behavior that differs by platform
- [docs/RELEASE_READINESS.md](docs/RELEASE_READINESS.md): what is verified and what blocks release
- [docs/IMPLEMENTATION_LOG.md](docs/IMPLEMENTATION_LOG.md): what was built and decided
- [TODO.md](TODO.md): external configuration and verification still required
