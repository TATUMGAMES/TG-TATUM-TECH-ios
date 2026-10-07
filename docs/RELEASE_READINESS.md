# Release Readiness

Where the iOS app stands before its first App Store submission. Only verified facts are listed as
done; everything else says what is missing.

## Verified

| Check | Result | How |
| --- | --- | --- |
| Core package builds | Pass | `swift build` in `Packages/TatumTechKit`, Swift 6.4 toolchain (Windows) |
| Core package tests | 131 tests in 16 suites pass | `swift test`, same toolchain |
| Firebase files match their apps | Debug file `BUNDLE_ID` is `com.tatumgames.tatumtech.ios.debug`, production file is `com.tatumgames.tatumtech.ios` | Inspected the files' contents |
| Firebase file selection | Copy phase bundles one file and fails on a mismatched or (Release) missing file | Script run outside Xcode with a PlistBuddy stand-in; launch check unit tested (`FirebaseEnvironmentTests`) |
| Bundled content | All 31 JSON files decode; every challenge bucket has 100 questions; every answer is among its options | Kit tests `everyBundledFileLoads`, `everyBucketHasAFullPool`, `everyQuestionHasItsAnswerAmongTheOptions`, `bundledAppContentDecodes` |
| Bundled content matches the shared source | All 31 files identical | SHA-256 comparison |
| No placeholder screens | No "coming soon" or pending screens remain; every Home card opens its feature | Source search; `HomeCatalogTests.everyCardOpensItsScreen` (not yet run) |
| Secrets | No credentials, keys, provisioning profiles or Firebase plists are tracked by git | `.gitignore` rules and `git status` review |

## Not yet verified (needs a Mac)

| Check | Why it matters |
| --- | --- |
| App target compiles | The SwiftUI app layer has never been compiled. Expect a round of compile fixes. |
| App unit tests and UI tests pass | Written, never run. |
| Device-only features | Camera QR scanning, system New Contact screen, local notifications, photo capture, Safari checkout. |
| Firebase events arrive | Check every event in [ANALYTICS_PARITY.md](ANALYTICS_PARITY.md) in DebugView under the Debug app. |
| Production Firebase routing | A Release build must report to the production iOS app only. Not checked in the Firebase console. |
| Sign in with Apple end to end | Needs the portal and Firebase console setup in TODO.md, then a physical iPhone: first sign-in, returning sign-in, cancel, private relay email, deletion with token revocation, in both Debug and Prod. Not production-ready until then. |
| Google sign-in through Firebase | Google sign-in now also requires Firebase Authentication with the Google provider enabled. |
| Accessibility | VoiceOver labels and Dynamic Type at the largest sizes on real screens. |
| Performance | Launch time, scrolling in Games carousels and long challenge sessions. |

## Release blockers (external)

Details for each are in [TODO.md](../TODO.md).

1. Mac build and test pass (above).
2. Apple Developer team, App IDs for both bundle IDs with Sign in with Apple, and the Apple provider configured in Firebase (including the key used for token revocation).
3. Final 1024×1024 app icon.
4. Backend sign-in route deployed (email and Google sign-in depend on it).
5. Server-side account deletion endpoint (App Store Guideline 5.1.1(v)).
6. Google iOS OAuth clients, if Google sign-in ships on iOS.

## App Store submission checklist

- **Bundle IDs:** Release `com.tatumgames.tatumtech.ios`, Debug `com.tatumgames.tatumtech.ios.debug`.
  These match the Firebase configuration files.
- **Usage descriptions:** camera (QR scanning and contact card photo) and contacts (saving scanned
  cards) are set in `Config/Info.plist`.
- **Privacy manifest:** declares email, name and user ID (app functionality), product interaction
  (analytics), crash and diagnostic data (app functionality), no tracking, and the UserDefaults
  API reason. Firebase SDKs ship their own manifests.
- **App Privacy labels in App Store Connect:** must match the manifest above.
- **Sign in with Apple:** offered alongside Google, as Guideline 4.8 requires. Deleting an Apple account revokes its Apple token (Guideline 5.1.1(v)).
- **Account deletion:** available in Profile; needs the server endpoint (blocker 5).
- **Rating:** uses the App Store review URL once `APP_STORE_ID` is set, otherwise
  `requestReview`.
- **Archive:** use the Tatum Tech Prod scheme; the build fails without
  `Config/Firebase/Prod/GoogleService-Info.plist`.
- **Crashlytics symbols:** the Upload Crashlytics Symbols phase runs on Release builds; confirm the
  first archive's dSYM appears in the Firebase console.
- **Home-screen name:** Release currently shows "Tatum Tech Prod" (`APP_DISPLAY_NAME`); confirm
  before submission.
- **Export compliance:** the app uses only standard HTTPS and Apple cryptography (SHA-256 for the
  Apple sign-in nonce and card IDs); set `ITSAppUsesNonExemptEncryption` accordingly when the App
  Store Connect record is created.
