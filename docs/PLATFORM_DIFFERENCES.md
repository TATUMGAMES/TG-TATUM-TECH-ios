# Platform Differences

Behavior that is intentionally different on iOS, and why.

## Sign-in

- **Sign in with Apple** is offered on iOS. App Store Review Guideline 4.8 requires it when an app
  offers third-party sign-in such as Google. The API has no Apple endpoint yet, so an Apple
  sign-in is stored on the device only (like a Google sign-in whose API exchange failed).
- **Google sign-in** uses the GoogleSignIn SDK directly. The ID token goes to the same
  `tatum-tech/signin` endpoint with the same Web client ID as audience.
- **Revoked Apple credentials** sign the user out at launch and immediately while the app runs.
- **Reinstall:** Keychain items survive app deletion on iOS, so the first launch after an install
  clears stored credentials, giving the same result as a fresh install elsewhere.

## Networking and contacts

- **Saving a scanned card** opens the system New Contact screen. iOS cannot write contact notes
  without a special entitlement, so LinkedIn, Twitter/X, custom and Calendly links are saved as
  labeled URL fields, and the card description is not copied into the contact.
- **Scanner re-arms** about 3 seconds after an invalid or unsupported code, so the user can try
  another code without leaving the screen.
- **Profile photo capture** uses the system camera picker; choosing from the library uses the
  system photo picker, which needs no photo library permission.

## Feedback and presentation

- Toasts appear at the bottom and hide after 3 seconds, like snackbars. Forgot Password shows its
  success message inline under the form instead.
- When events, speakers or partners fail to load, iOS shows an error with Retry instead of an
  empty list.
- About and FAQ open as pushed screens instead of dialogs, so long text scrolls naturally. They
  are not reported to analytics on either platform.
- Donation checkout opens in an in-app Safari view instead of a web view.
- Filled buttons use dark text on the light purple brand color to meet contrast guidelines.
- Home uses a native paged `TabView` with chips; the speaker reminder banner and rating prompt sit
  above the tabs.
- iPhone only, portrait only, light appearance only.

## Analytics

- Uncaught Objective-C exceptions log `exception` with `handled=false` before Crashlytics handles
  them. Swift runtime traps cannot be intercepted; Crashlytics reports them on the next launch.
- A failure to load the bundled games catalog is reported as a handled exception.

## Build and distribution

- Bundle IDs: Release `com.tatumgames.tatumtech.ios`, Debug `com.tatumgames.tatumtech.ios.debug`,
  each reporting to its own Firebase app in the shared Firebase project. Android selects its
  configuration file per build type from source-set folders; iOS selects
  `Config/Firebase/<Debug|Prod>/GoogleService-Info.plist` per build configuration in a build
  phase that fails on a bundle ID mismatch, and checks it again at launch.
- Schemes: Tatum Tech Debug (Debug) and Tatum Tech Prod (Release, used for archives).
- Configuration comes from xcconfig files. Local values live in the git-ignored
  `Config/Secrets.xcconfig`; Firebase files are git-ignored.
- Release builds force the production API over the network.
- The privacy manifest (`PrivacyInfo.xcprivacy`) declares collected data and required-reason API
  use.
