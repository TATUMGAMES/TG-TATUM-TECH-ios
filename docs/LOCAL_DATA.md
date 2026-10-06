# Local Data

What Tatum Tech stores on the device, where, and how it is read. Everything here works offline.

## Storage locations

| Data | Location | Format | Cleared by Delete Account |
| --- | --- | --- | --- |
| User activity (profile, progress, timeline, card, connections, notifications, counters) | `Application Support/TatumTech/local-data.json` | One JSON document (`LocalData`), written atomically | Yes, except the "sent to App Store for rating" flag |
| Contact card photo | `Application Support/ContactCardImages/photo_<ms>.jpg` | JPEG, longest side ≤ 1024 px, complete file protection | Yes |
| API session, Google/Apple identity | Keychain, service `<bundle id>.auth`, this-device-only, after first unlock | Keychain items | Yes |
| Speaker reminder state (scheduled and delivered keys) | `UserDefaults`, key `tatumTech.meetingReminders` | JSON | Yes: reminders are cancelled; whether notification permission was already requested is kept |
| Device identifier for the API | `UserDefaults` | UUID string, not a secret | No |
| First-launch marker (clears Keychain items left by a previous install) | `UserDefaults` | Boolean | No |

UI tests (`-uiTesting`) use an in-memory store, no photo directory and a separate defaults suite,
so they never touch real data.

## LocalData document

`LocalRepository` (an actor in `TatumTechKit/Persistence`) owns the document. Missing keys decode as
empty values, so files written by older versions keep loading.

| Field | Contents |
| --- | --- |
| `user` | The single local profile: anonymous ID such as `anon_482913` (created on first use), username (the anonymous ID, read-only), first name, last name, email. The Home greeting shows "First Last", the first name, or the anonymous ID. |
| `demographics` | Optional answers: age range, sex, occupation, salary range (only with an occupation), school. The three consent checkboxes gate saving and are not stored. |
| `timeline` | Activity entries with type, description, timestamp and optional related ID. Types: event registration and unregistration, challenge completion, QR scan, friend add and remove, contact card created and shared, connection made, donation. |
| `quizProgress` | Per challenge bucket (track + language + level): the current session's question IDs, shuffled option order, answers so far, score, and completion state. Interrupted sessions resume with the same option order. |
| `answerEvents` | Every submitted answer with track, language, level, correctness and timestamp. Drives the daily limit, streaks and accuracy. |
| `counters` | `APP_OPEN_COUNT`, `HAS_BEEN_SENT_TO_APP_STORE_FOR_RATING`, `GAME_DETAILS_VIEWED`, `JOB_APPLY_CLICKED`. |
| `contactCard` | The user's card: stable card ID, photo file name, name, job title, company, description, email, phone, alternate email, website, LinkedIn, Twitter/X, custom link, Calendly. |
| `connections` | Scanned cards, unique per card ID. Re-scanning updates the details and keeps the first connection date. |
| `notifications` | Recent notifications (daily coding challenge, upcoming events). At most 3 event notifications; read items expire after 14 days. |

## Bundled content

JSON files in `TatumTech/Resources/Content`, read by `BundledCatalog` and `LocalJSONTransport`.

| File | Entries | Used by |
| --- | --- | --- |
| `coding_challenges_<track>_<level>.json` (24 files) | 100 questions each, 2,400 total | Coding (C#, Java, JavaScript, Kotlin, Python), AI & LLMs, Leet Code, Mock Interviews |
| `achievements.json` | 30 | Stats, Achievements |
| `career_listings.json` | 50 | Apply for Jobs |
| `resources.json` | 19 | Resources |
| `games.json` | Games, sections and filters | Discover Games, Game Details |
| `games_resources.json` | 5 categories | Game Resources (resolved against partners) |
| `partners.json` | 37 | Partners in local JSON mode and UI tests |
| `upcoming_events.json` | 1 | Upcoming Events in local JSON mode and UI tests |

Challenge rules (in `ChallengeEngine`): sessions of 10 questions; at most 30 answers per day, with
the last session of the day shortened to fit; questions are unique within a session and options are
shuffled once per session. Both spellings of the mock interview language share one bucket.

Content that changes often (events, speakers, partners) comes from the Tatum Tech API in normal
builds. Debug builds can switch to bundled JSON with `TATUM_TECH_DATA_SOURCE = LOCAL_JSON`.

## Privacy

- Local data never leaves the device. The only data sent to the API is account data (sign-in,
  sign-up, profile updates) and content requests.
- Contact card photos use complete file protection. Keychain items do not sync to iCloud and are
  not restored to another device.
- Delete Account signs out of every identity provider, erases the document, photos and reminder
  state, and keeps only whether the user was already sent to the App Store to rate the app (so the
  prompt does not return).
