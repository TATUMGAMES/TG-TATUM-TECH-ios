# Authentication

How users sign in to Tatum Tech on iOS, what each sign-in method stores, and the product decisions
behind sign-out, account linking and account deletion.

## Sign-in methods

The welcome screen shows, top to bottom: **Sign In**, **Sign Up**, "OR", **Sign in with Apple**
(Apple's `SignInWithAppleButton`) and **Sign in with Google**.

| Method | Verified by | Tatum Tech API session | Stored on the device |
| --- | --- | --- | --- |
| Email and password | Tatum Tech API (`tatum-tech/signin`, `tatum-tech/signup`) | Yes | API session (Keychain) |
| Google | Firebase Authentication, then the ID token is exchanged with the API (10-second limit, best effort) | Only if the exchange succeeds | Federated account (Keychain), Firebase session, API session when exchanged |
| Apple | Firebase Authentication | No (the API has no Apple endpoint yet) | Federated account (Keychain), Firebase session |

A Google or Apple sign-in counts as signed in only while the stored federated account and the
current Firebase user match (`FederatedAccount.firebaseUID`). If either is missing, for example
after Firebase signs the user out, the app shows the welcome screen.

## Sign in with Apple flow

1. Tapping the button creates an `AppleSignInAttempt` with a new 32-character nonce from
   `SecRandomCopyBytes`. The request carries its SHA-256 hash and asks for the full name and email.
2. Apple returns an `ASAuthorizationAppleIDCredential`. The attempt is consumed, so each nonce is
   used once.
3. `AccountService.completeAppleSignIn` rejects a missing identity token or nonce, then calls
   Firebase with `OAuthProvider.appleCredential(withIDToken:rawNonce:fullName:)`.
4. On success the federated account is saved with the Firebase user ID and the app enters the
   signed-in experience. On failure nothing is saved and the user stays on the welcome screen.

### Name and email

- Apple sends the name and email only the first time a user authorizes the app. Later sign-ins
  keep the values stored earlier; an empty value never replaces a stored one.
- If the stored record is gone (sign-out or reinstall), the name and email come from the Firebase
  user, which kept them from the first sign-in.
- Private relay addresses (`@privaterelay.appleid.com`) are stored and shown like any other email.
- The local profile is seeded with the given and family name only when it is first created; later
  edits in Profile are never overwritten.

### Errors

| Situation | What the user sees |
| --- | --- |
| User closes Apple's sheet | Nothing |
| Missing or invalid identity token, invalid nonce, invalid credential, other Apple failure | "We couldn't sign you in with Apple..." |
| No network | The standard connection message |
| Email already used by another sign-in method | "An account with this email already uses a different sign-in method..." |
| Apple provider disabled in Firebase, or no Firebase configuration in the build | "Sign in with Apple isn't available right now..." |
| Firebase user disabled | "This account has been disabled." |
| Anything unexpected | "We couldn't sign you in with Apple..." |

Alerts use the app's standard alert (`AlertMessage`). Failures other than cancellation and
"unavailable" are also recorded as handled exceptions.

### Revoked credentials

The app checks Apple's credential state at launch and listens for Apple's revocation notification
while it runs. A revoked or missing credential signs the user out, including from Firebase.

## Account linking

- Email and password accounts live in the Tatum Tech API, not in Firebase, so there is nothing to
  link with a Google or Apple sign-in.
- With Firebase's default setting (one account per email address), signing in with Apple using an
  email that already belongs to a Google sign-in fails with "account exists with different
  credential". The user is asked to sign in the way they did before. The app does not link the
  two automatically: linking needs the user's explicit consent and a product decision.
- An Apple sign-in that uses a private relay email creates a separate Firebase user from any
  Google sign-in, even for the same person.
- If the product later wants linked accounts, add a "link Apple" action for a signed-in Google
  user using `User.link(with:)`.

## Sign-out

There is no standalone Sign Out button; the account ends through Delete Account or a revoked Apple
credential. `AccountService.signOut()` ends the API session, signs out of Firebase and clears the
stored federated account. Signing in again with Apple works normally afterwards.

## Account deletion

**Apple accounts:**
1. Profile, then Delete Account, then the user confirms.
2. Apple's sheet asks the user to authorize again. This gives a fresh identity token and
   authorization code. Closing the sheet cancels deletion and keeps the account.
3. Firebase reauthenticates the user, revokes the Apple token with the authorization code
   (`Auth.auth().revokeToken(withAuthorizationCode:)`), then deletes the Firebase user.
4. If any of these steps fail, nothing is deleted, the user stays signed in and an alert asks
   them to try again.
5. On success the app signs out and erases all on-device data.

**Google accounts:** the Firebase user is deleted on a best-effort basis; a failure is recorded
but does not stop the sign-out and on-device erase.

**Email accounts:** the app signs out and erases on-device data. Server-side deletion needs a
backend endpoint (see TODO.md).

## Analytics

| Event | When |
| --- | --- |
| `login` with `method` = `email`, `google` or `apple` | A returning user signs in |
| `sign_up` with the same `method` values | Email sign-up, or Firebase reports a new Google or Apple user |
| `exception` (handled) | A Google or Apple sign-in fails for a reason other than cancellation |
| `delete_account` | Deletion starts (for Apple, after the user authorizes again) |

See [ANALYTICS_PARITY.md](ANALYTICS_PARITY.md) for parameters and verification.

## Configuration

### Debug and Production

| | Debug | Production |
| --- | --- | --- |
| Bundle ID | `com.tatumgames.tatumtech.ios.debug` | `com.tatumgames.tatumtech.ios` |
| Entitlements | `Config/TatumTech.entitlements` (Sign in with Apple) | Same file |
| Firebase iOS app | Debug app | Production app |
| Firebase project and Apple provider | Shared (`tatumtech-mobile-firebase`) | Shared |

- Each bundle ID is its own App ID in the Apple Developer portal, so Sign in with Apple must be
  enabled on both. Provisioning profiles must be regenerated after enabling it.
- Apple identity tokens carry the bundle ID as audience. Firebase accepts tokens for any iOS app
  registered in the project, so both builds use the same Apple provider configuration.
- Users who sign in with Apple in the Debug build and in the Production build are different App
  IDs as far as Apple is concerned. Group both App IDs under one primary App ID in the portal if
  the same Apple user ID is wanted in both builds.

### Apple Developer portal

- Enable **Sign in with Apple** on both App IDs.
- Create a **Services ID** and a **Sign in with Apple key**. Firebase needs them to revoke tokens
  when an account is deleted. The key (`.p8`) is entered only in the Firebase console; never add
  it to this repository.

### Firebase console

- Authentication, Sign-in method: enable **Apple**. In its OAuth code flow section enter the
  Services ID, Apple Team ID, key ID and private key.
- Authentication, Sign-in method: enable **Google** (Google sign-in also goes through Firebase).
- Registering the private email relay with Apple is only needed if Firebase sends emails to
  users, which this app does not do.

## Code map

| Piece | Location |
| --- | --- |
| Sign-in orchestration, stored identities, deletion rules | `TatumTechKit/Account/AccountService.swift` |
| Firebase protocol, failures, in-memory test double | `TatumTechKit/Account/FirebaseAuthentication.swift` |
| Error copy mapping | `TatumTechKit/Account/AuthErrorText.swift` |
| Firebase SDK adapter | `TatumTech/App/FirebaseAuthentication.swift` |
| Nonce, Apple request, reauthorization | `TatumTech/Features/Auth/AppleSignIn.swift` |
| Welcome screen buttons and models | `TatumTech/Features/Auth/AuthFlowView.swift`, `AuthModels.swift` |
| Deletion flow | `TatumTech/App/AppModel.swift`, `TatumTech/Features/Profile/ProfileView.swift` |

## Tests

- Kit (`swift test`, runs anywhere): new and returning Apple users, private relay email, name
  preservation and recovery, rejected token or nonce, each Firebase failure, sign-out and sign-in
  again, deletion with revocation, deletion failures, Google through Firebase, error copy and
  analytics events.
- App unit tests: nonce length, alphabet, uniqueness and SHA-256, Apple request scopes,
  cancellation, every alert, analytics, profile seeding and the deletion results.
- UI tests: the button order and the Apple button's size.
- Not covered by automated tests: Apple's real sheet, Firebase's servers and token revocation.
  These need a physical iPhone (see TODO.md).
