# Analytics Parity

Every analytics event Tatum Tech sends, how each platform sends it, and how far it has been
verified. Event names, parameter names and values are identical on Android and iOS so reports
combine both platforms.

Events go to Firebase Analytics through `AnalyticsService` (`TatumTechKit/Analytics`). Errors that
carry a stack go to Crashlytics. With no `GoogleService-Info.plist` in the build, nothing is sent.
No event carries personal information: screen names are route templates and endpoints have
identifiers replaced with `{id}`.

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
