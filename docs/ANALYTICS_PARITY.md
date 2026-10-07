# Analytics Parity

Every analytics event Tatum Tech sends, how each platform sends it, and how far it has been
verified. Event names, parameter names and values are identical on Android and iOS so reports
combine both platforms.

Events go to Firebase Analytics through `AnalyticsService` (`TatumTechKit/Analytics`). Errors that
carry a stack go to Crashlytics. With no `GoogleService-Info.plist` in the build, or one that does
not belong to the running bundle ID, nothing is sent. No event carries personal information:
screen names are route templates and endpoints have identifiers replaced with `{id}`.

## Summary

| | Count |
| --- | --- |
| Android events found (`AnalyticsEvents.kt`, `AnalyticsService.kt`) | 8 |
| iOS events implemented, same names and parameters | 8 |
| Missing on iOS | 0 |
| User properties / user ID set on either platform | none |
| Events verified at runtime in DebugView | 0 (needs a Mac build; see TODO.md) |

## Environments

Debug and production report to separate Firebase apps in the same Firebase project
(`tatumtech-mobile-firebase`), so debug traffic never reaches production reports. Android follows
the same model with its own debug and release apps.

| | Debug | Production |
| --- | --- | --- |
| Xcode scheme | Tatum Tech Debug | Tatum Tech Prod |
| Build configuration | Debug | Release |
| Bundle ID | `com.tatumgames.tatumtech.ios.debug` | `com.tatumgames.tatumtech.ios` |
| Firebase iOS app ID | `1:200853064929:ios:fca90eb9865f2e2bd6fba0` | `1:200853064929:ios:56260bb200c2ad8fd6fba0` |
| Configuration file | `Config/Firebase/Debug/GoogleService-Info.plist` | `Config/Firebase/Prod/GoogleService-Info.plist` |
| Android counterpart | `com.tatumgames.tatumtech.android.debug` | `com.tatumgames.tatumtech.android` |

Only one file is bundled per build, chosen by the build configuration and checked twice: the
"Copy Firebase Configuration" build phase fails if the file's `BUNDLE_ID` differs from the build's
bundle ID, and at launch `FirebaseConfigurationCheck` (in `TatumTechKit`) compares the bundled
file's `BUNDLE_ID` and `GOOGLE_APP_ID` with the running app before Firebase starts. The running
bundle ID decides the environment, not the build configuration. Debug builds show the result in
the menu under "Firebase (Debug build only)".

## Beyond events

| Item | Android | iOS | Verified |
| --- | --- | --- | --- |
| User properties | None set | None set | Code review |
| User ID | Not set | Not set | Code review |
| Crashlytics custom keys | `application_id` (package name), `build_type` (`debug`/`release`) | `application_id` (bundle ID), `build_type` (`debug`/`release`) | Code review |
| Crashlytics collection | Enabled | Enabled (SDK default) | Code review |
| DebugView | Debug builds enable analytics collection for DebugView | The Tatum Tech Debug scheme launches with `-FIRAnalyticsDebugEnabled` | Not yet (needs a Mac) |
| Screen tracking | `navigate` event (below); Firebase automatic screen reporting left at its default | `navigate` event (below); Firebase automatic screen reporting left at its default | Code review |
| Auth events | Only `navigate` for the auth screens and `api_error` for failed sign-in calls | Same | Code review |
| Coding challenge events | No dedicated event; finishing a session can trigger the rating prompt (`rate_app` with `trigger` = `coding_challenge_complete`) | Same | Code review |

## Events

**Verified** levels used below:
- **Unit test:** a `TatumTechKit` test asserts the event name and parameters (runs on any platform).
- **Code review:** the iOS call site was compared line by line with the Android call site.
- **Runtime:** seen in Firebase DebugView. Not done yet; it needs a Mac build (see TODO.md).

| Event | Android behavior | iOS implementation | Parameters | Verified |
| --- | --- | --- | --- | --- |
| `navigate` | Logged by a navigation listener each time the destination route changes, using the route's first path segment. | `trackScreen` logs on each appearance of a pushed route (`AppRoute.analyticsRoute`), tab root (`MainTab.analyticsRoute`), auth screen, and the rating sheet. Route names are the same strings (`upcoming_events_screen`, `scanner_from_upcoming_events`, `home_pager`, `rating_screen`, …). About and FAQ are dialogs on Android and are not reported on either platform. | `screen_name` (string) | Unit test (sanitizer), code review |
| `update_profile` | One event per changed field after saving Profile or the contact card editor. | `ProfileView` and `ContactCardEditorView` log one event per field returned by `LocalRepository.updateProfile`. | `field`: `first_name`, `last_name` or `email` | Code review |
| `scan_contact_card` | Logged when a valid Tatum Tech card is scanned. | `ScannerView` logs before opening the scanned-card preview. Invalid or unsupported codes are not logged. | none | Code review |
| `create_contact_card` | Logged when a contact card is saved for the first time. | `ContactCardEditorView` logs only when no card existed before saving. | none | Code review |
| `delete_account` | Logged when deletion starts. | `AppModel.deleteAccount` logs before signing out and erasing data. | none | Code review |
| `rate_app` | Logged when the user submits a star rating. | `RatingView` logs on submit. | `rating` (integer 1–5), `trigger`: `app_open` or `coding_challenge_complete`, `sent_to_store`: `"true"` or `"false"` | Unit test (rating policy), code review |
| `exception` (handled) | Logged with a Crashlytics non-fatal when a recoverable error occurs (Discord response parsing). | `AnalyticsService.recordHandled` from `DiscordClient` on parse failures. iOS also reports a failure to load the bundled games catalog (`GamesView`, `GameDetailsView`); Android only writes that failure to the log. A failure there means the shipped file is broken, so iOS surfaces it. | `handled`: `"true"` | Code review |
| `exception` (unhandled) | Best-effort event from the default uncaught exception handler, then the previous handler (Crashlytics). | `UnhandledExceptionBridge` installs an uncaught Objective-C exception handler that logs the event and then calls the previous handler (Crashlytics). Swift runtime traps cannot be intercepted on iOS; Crashlytics reports them on the next launch. | `handled`: `"false"` | Code review |
| `api_error` | Logged for every failed Tatum Tech API call and every failed Discord request. Successful calls are never logged. | `TatumTechAPIClient` reports failures through `APIFailureObserver` (implemented by `AnalyticsService`); `DiscordClient` reports HTTP, empty-body, network and parse failures. | `endpoint` (sanitized path), `method` (lowercase), `duration_ms` (integer), `error_type`: `http`, `timeout`, `connection`, `io`, `parse` or `unknown`; `status_code` (integer) when there was an HTTP response | Unit test (`httpFailuresAreReportedToAnalytics`, sanitizer), code review |

## Screen names

Pushed screens: `upcoming_events_screen`, `virtual_speakers_screen`, `partners_screen`,
`coding_challenges_screen`, `ai_llm_challenges_screen`, `leet_code_challenges_screen`,
`mock_interview_challenges_screen`, `stats_screen`, `achievements_screen`, `my_timeline_screen`,
`resources_screen`, `community_screen`, `donate_screen`, `career_screen`, `games_screen`,
`game_details_screen`, `get_your_game_discovered_screen`, `games_resources_screen`,
`scanner_screen`, `scanner_from_upcoming_events`, `contact_card_editor_screen`,
`my_contact_card_qr_screen`, `scanned_contact_preview`, `user_profile_screen`,
`demographic_screen`.

Other screens: `home_pager` (Home tab), `rating_screen`, `auth_screen`, `sign_in_screen`,
`sign_up_screen`, `forgot_password_screen`.
