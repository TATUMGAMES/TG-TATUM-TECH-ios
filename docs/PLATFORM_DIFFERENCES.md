# Platform Differences

Intentional differences between the iOS and Android apps, and why.

## Sign-in

- **Sign in with Apple** is offered on iOS. App Store Review Guideline 4.8 requires it when an
  app offers third-party sign-in such as Google. The API has no Apple endpoint yet, so an Apple
  sign-in is stored on the device only (like a Google sign-in whose API exchange failed).
- **Google sign-in** uses the GoogleSignIn SDK directly instead of Firebase Auth. The ID token is
  sent to the same `tatum-tech/signin` endpoint with the same Web client ID as audience.
- **Revoked Apple credentials** (Settings > Apple ID > Sign in with Apple) sign the user out at
  the next launch.
- **Reinstall:** Keychain items survive app deletion on iOS, so the first launch after an install
  clears stored credentials. Android loses its Keystore data with the app, so the result matches.

## Feedback

- Forgot Password shows its success message inline under the form. iOS has no toast.
- When events or partners fail to load, iOS shows an error with Retry. Android shows an empty
  list.
- Filled buttons use dark text on the light purple brand color to meet contrast guidelines;
  Android uses white text.

## Build and distribution

- iOS uses one bundle ID (`com.tatumgames.tatumtech`) for Debug and Release. Android's debug build
  adds a `.debug` suffix. A separate iOS debug bundle ID would need its own Google OAuth client and
  Sign in with Apple configuration.
- Configuration comes from xcconfig files instead of Gradle `BuildConfig`. Local values live in the
  git-ignored `Config/Secrets.xcconfig`.
- Release builds force the production API over the network, like Android release builds.

## Presentation

- One scene switches between the auth flow and the tab view instead of two activities.
- Home uses a native paged `TabView` with chips instead of a Compose pager with tabs.
- iPhone only, portrait only, light appearance only.
- The privacy manifest (`PrivacyInfo.xcprivacy`) declares collected data (email, name, user ID for
  app functionality) and the UserDefaults API reason. Android has no equivalent file.
