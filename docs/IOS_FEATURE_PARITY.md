# iOS Feature Parity

Status of each Android feature on iOS. "Pending" screens exist as placeholders that explain the
feature is coming, so navigation matches Android.

| Area | Feature | Android | iOS | Notes |
| --- | --- | --- | --- | --- |
| Auth | Email sign-in, sign-up | Yes | Done | Same validation and copy |
| Auth | Forgot password | Yes | Done | Success shown inline instead of a toast |
| Auth | Google sign-in | Yes | Built, needs config | Requires an iOS OAuth client ID (see TODO) |
| Auth | Sign in with Apple | No | Done (local) | No backend endpoint yet; Apple-only sessions are local |
| Auth | Session refresh and secure storage | Yes | Done | Keychain |
| Auth | Sign-out / delete account | Yes | Done (local) | No backend delete endpoint on either platform |
| Home | Category pager and feature cards | Yes | Done | Same cards and icons |
| Home | Account menu | Yes | Done | Profile, Demographic, About, FAQ pending |
| Events | Upcoming events | Yes | Done | Includes full-screen flyer viewer |
| Events | Virtual speakers | Yes | Done | |
| Events | Networking section on events | Yes | Pending | |
| Events | Meeting reminders | Yes | Pending | Android uses WorkManager notifications |
| Events | Scanner and contact card (QR, vCard) | Yes | Pending | Needs camera permission and AVFoundation scanner |
| Partners | List, categories, detail, contact | Yes | Done | |
| Coding | Coding challenges, AI challenges, stats, resources | Yes | Pending | |
| Community | Community, donate | Yes | Pending | |
| Career | Jobs, Leet Code, mock interviews | Yes | Pending | |
| Games | Discover games, game resources | Yes | Pending | |
| Timeline | Timeline tab | Yes | Pending | |
| Notifications | Recent notifications | Yes | Pending | Android stores them in Room |
| Analytics | Firebase Analytics | Yes | Not started | Needs `GoogleService-Info.plist` and a privacy review |
| Settings | Light theme | Yes | Done | Dark mode not supported on either platform |
