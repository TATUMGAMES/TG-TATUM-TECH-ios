# Feature Parity Audit

Each user-facing feature of Tatum Tech, the behavior identified in the Android app, and its state
on iOS. Audited by reading every Android screen and comparing it with the iOS source (October 2026).

How to read the columns:
- **iOS implemented / Logic implemented:** "Yes" means the screen and its behavior exist in code
  with no placeholder.
- **Error handling:** what the user sees when something fails.
- **Analytics:** events logged (see [ANALYTICS_PARITY.md](ANALYTICS_PARITY.md)); "Screen" means a
  `navigate` event only.
- **Tested:** **Kit** = covered by `TatumTechKit` tests that were run and pass (110 tests on the
  Swift 6.4 toolchain, Windows). **App test** / **UI test** = covered by tests in
  `TatumTechTests` / `TatumTechUITests`, which are written but **not yet run** because the app
  target needs a Mac. **None** = no automated test; verify manually.

## Accounts

| Feature | Screen | Android behavior identified | iOS implemented | Logic implemented | Error handling | Analytics | Assets | Tested |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Welcome | Welcome | Sign In, Sign Up, Google button, terms and privacy links | Yes, plus Sign in with Apple (Firebase Authentication) | Yes | Google unavailable message when unconfigured | Screen | `google_sign_in_button`, logo | UI test |
| Email sign-in | Sign In | Email and password validation after focus loss, submit disabled until valid, server messages shown | Yes | Yes | Server message (capped at 500 chars) or friendly copy | Screen | — | Kit (CredentialRules, AccountService, API client); UI test |
| Sign-up | Sign Up | Email, password, confirmation, same validation | Yes | Yes | Same as sign-in | Screen | — | Kit; App test (auth models) |
| Forgot password | Forgot Password | Email, send, success message | Yes | Yes | Inline success and error | Screen | — | Kit; App test |
| Google sign-in | Welcome | Google identity kept even if the API exchange fails | Yes | Yes | Unavailable or failure copy | — | Google button | Kit (`googleSignInContinuesWhenExchangeFails`) |
| Session restore and refresh | — | Refresh one hour before expiry, single refresh, sign-out only when refresh is rejected | Yes | Yes | Network errors keep the session | `api_error` | — | Kit (SessionManager, 12 tests); App test |
| Profile | Profile | Username read-only, first/last name, email, Save, toast, Delete Account with Yes/No confirmation | Yes | Yes | Delete progress overlay | Screen, `update_profile`, `delete_account` | SF Symbols | UI test (deletion dialog) |
| Sign out | Profile | Text link below Save, Yes/No confirmation, `POST tatum-tech/signout` with `{}`, clears session, Firebase and Google only after the server confirms, returns to Welcome | Yes | Yes | Failure stays on Profile with the standard API alert; progress overlay blocks a second request | — | — | Kit (SessionManager, AccountService); App test; UI test |
| Demographic info | Demographic | 13+ confirmation, three consents gate Save, age/sex/salary/occupation/school, salary only with occupation | Yes | Yes | Cancel on the 13+ dialog goes back | Screen | — | None |
| Delete account | Profile | Signs out, erases local data, keeps "sent to store" flag | Yes | Yes | Runs to completion even if the screen closes | `delete_account` | — | App test |

## Home and navigation

| Feature | Screen | Android behavior identified | iOS implemented | Logic implemented | Error handling | Analytics | Assets | Tested |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Greeting | Home | "Hello, First Last!", first name, or anonymous ID | Yes | Yes | — | Screen (`home_pager`) | — | App test; UI test |
| Category pager | Home | Events, Coding, Community, Career, Games with feature cards; odd last card full width | Yes | Yes | — | — | 12 feature icons | App test (cards, routes, icons) |
| Recent notifications | Home | Collapsible list, unread styling, tap marks read and opens destination | Yes | Yes | Empty text | — | `notif_coding_challenge` | Kit (`notificationsAreAddedOncePerDayAndExpireWhenRead`) |
| Account menu | Home sheet | Profile, Demographic Info, About, FAQ, version, terms | Yes | Yes | — | — | logo | UI test |
| About and FAQ | Dialogs | Mission, MIKROS resources, Visit Tatum Tech; FAQ questions | Yes (pushed screens) | Yes | — | Not reported (as Android) | — | None |
| Tabs | Main | Home, Learn, Timeline, Stats | Yes | Yes | — | Screen | SF Symbols | UI test |
| Rating prompt | Rating | Every 20 app opens and after a coding challenge session; 4–5 stars open the store; never again after the store | Yes | Yes | Falls back to in-app review without an App Store ID | Screen, `rate_app` | logo | Kit (`ratingPolicyMatchesTheSchedule`) |

## Events and networking

| Feature | Screen | Android behavior identified | iOS implemented | Logic implemented | Error handling | Analytics | Assets | Tested |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Upcoming events | Upcoming Events | Flyer (full screen on tap), host, date in the published offset, location, Register, Virtual Speakers | Yes | Yes | Error with Retry; empty text | Screen | event flyers | Kit (content, formatting); UI test |
| Networking section | Upcoming Events | Create/Edit, Share, Scan | Yes | Yes | — | — | — | None |
| Virtual speakers | Virtual Speakers | Speaker cards, Join (Meet), scroll to and highlight the speaker from a reminder | Yes | Yes | Error with Retry; empty text | Screen | speaker photos | Kit (speaker sorting) |
| Speaker reminders | Banner and notifications | Reminder before each session; in-app banner in the foreground; tap opens the speaker | Yes | Yes | Skipped without permission | — | SF Symbol | Kit (8 reminder tests) |
| Contact card editor | Contact Card Editor | Photo (gallery or camera), profile, contact and link fields, validation, saves profile too | Yes | Yes | Field errors, permission and cancel toasts | Screen, `update_profile`, `create_contact_card` | SF Symbols | UI test (create, required fields) |
| Share card QR | My Contact Card QR | vCard QR readable by any camera; timeline entry | Yes | Yes | "Unable to generate QR code" | Screen | — | Kit (vCard codec, 10 tests); UI test |
| Scanner | Scanner | Camera permission, scan, invalid and unsupported-version messages, back to Upcoming Events when opened there | Yes | Yes, and re-arms after an invalid scan | Permission and no-camera messages | Screen, `scan_contact_card` | — | Kit (codec parsing) |
| Scanned card preview | Scanned Contact Preview | Details, Save Contact (records connection, opens system contact insert), own-card check, Cancel | Yes | Yes | Invalid card text; own-card toast | Screen | — | Kit (`ownCardsAreRecognisedByStableIdentity`, connections) |

## Partners

| Feature | Screen | Android behavior identified | iOS implemented | Logic implemented | Error handling | Analytics | Assets | Tested |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Partner directory | Partners | Category chips, featured first, cards with Contact/Website/Donate, detail with products and socials | Yes | Yes | Error with Retry | Screen | 34 partner logos, social icons | Kit (content, contact links); UI test |

## Challenges and progress

| Feature | Screen | Android behavior identified | iOS implemented | Logic implemented | Error handling | Analytics | Assets | Tested |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Coding challenges | Coding (Learn tab) | Language and level pickers, 10-question sessions, explanations, feedback animation, confetti, daily limit 30 | Yes | Yes (2,400 bundled questions) | Daily-limit message | Screen | GIFs, correct/incorrect images | Kit (13 challenge tests); UI test (answer and feedback) |
| AI & LLMs | AI & LLMs | Same engine, AI track | Yes | Yes | Same | Screen | `ai_logo` | Kit |
| Leet Code | Leet Code | Same engine, Leet Code track | Yes | Yes | Same | Screen | — | Kit |
| Mock interviews | Mock Interviews | Same engine, mock interview track | Yes | Yes (both language spellings share one bucket) | Same | Screen | — | Kit (`bothMockInterviewSpellingsShareOneBucket`) |
| Stats | Stats tab | Count-up rings, accuracy, streak, category breakdown, coding stats, achievements preview | Yes | Yes | "No statistics loaded yet." | Screen | badges | Kit (stats, streaks); UI test (opens) |
| Achievements | Achievements | 30 achievements with points and locked state | Yes | Yes | Loading text | Screen | 22 badges | Kit (`bundledAchievementsDecodeAndUnlock`) |
| Timeline | Timeline tab | Today / Last Week / Last Month filters | Yes | Yes | Empty text | Screen | — | UI test (opens) |

## Career, community and games

| Feature | Screen | Android behavior identified | iOS implemented | Logic implemented | Error handling | Analytics | Assets | Tested |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Apply for jobs | Career | Search, category and type filters, Apply counts clicks | Yes | Yes | Empty and no-results text | Screen | — | Kit (`careerListingsLoadAndFilter`); UI test (opens) |
| Resources | Resources | Technology filter, Visit | Yes | Yes | Empty text | Screen | — | Kit (`resourcesLoadAndFilterByTechnology`); UI test (opens) |
| Community | Community | Live Discord info (members, online, boosts, avatars), copy and share invite, Join, Support Us | Yes | Yes | "Error: …" text | Screen, `api_error`, `exception` | `discord_banner` | Kit (`parsesInviteDetails`, `httpFailuresAreReportedToAnalytics`) |
| Donate | Donate | Donation tiers open checkout; timeline entry | Yes (Safari view) | Yes | — | Screen | — | UI test (opens) |
| Discover games | Games | Featured and Games tabs, carousels, genre and gameplay filters, search | Yes | Yes | Error and empty text | Screen, `exception` | game logos and screenshots | Kit (`gamesCatalogLoadsWithSectionsAndCallsToAction`); UI test (opens) |
| Game details | Game Details | Media, screenshots viewer, store and follow buttons, Discord, socials, tags | Yes | Yes | "Game not found." | Screen | game media | Kit (`otherStoreLabelsDependOnTheHost`) |
| Get your game discovered | MIKROS | MIKROS copy, Learn More, Explainer Video | Yes | Yes | — | Screen | — | None |
| Game resources | Game Resources | Categories resolved against partners | Yes | Yes | Empty text | Screen | partner logos | Kit (`gamesResourcesResolveAgainstPartners`) |

## Android defects not carried over

- Mock interview questions use two spellings of the language; iOS merges them into one bucket.
- Mock interview completions were missing from stats; iOS counts them.
- Resumed sessions reshuffled options; iOS keeps the saved option order.
- The scanner never re-armed after an invalid or unsupported code; iOS re-arms about 3 seconds
  after the message.
- A permission message read "utes" instead of "2 minutes"; iOS shows the intended text.

## Android code with no user-facing behavior

Not reproduced because nothing in the Android app reaches it: a Change Password screen that is not
in the navigation graph, local event registration (so "events attended" is always 0 on both
platforms), and `mock_notifications.json`.
