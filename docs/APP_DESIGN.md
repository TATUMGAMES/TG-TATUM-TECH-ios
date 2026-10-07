# App Design

How the iOS app is organized for users: screens, navigation and the visual system.
[PLATFORM_DIFFERENCES.md](PLATFORM_DIFFERENCES.md) lists behavior that is specific to iOS.

## Builds

| Scheme | Home-screen name | Bundle ID | Firebase app |
| --- | --- | --- | --- |
| Tatum Tech Debug | Tatum Tech Debug | `com.tatumgames.tatumtech.ios.debug` | Debug |
| Tatum Tech Prod | Tatum Tech Prod | `com.tatumgames.tatumtech.ios` | Production |

Different bundle IDs let both builds sit on one device side by side.

## Launch and account state

`RootView` switches on `AppModel.phase`:

- **launching:** logo on the screen background (matches the launch screen) while the stored
  account is restored.
- **signedOut:** the auth flow.
- **signedIn:** the main tab view.

A stored Apple identity whose credential was revoked is signed out at launch, or immediately if it
is revoked while the app runs. On the first launch after a reinstall, credentials left in the
Keychain by a previous install are cleared.

## Auth flow

| Screen | Content |
| --- | --- |
| Welcome | "Let's begin your Tatum Tech experience.", Sign In, Sign Up, "OR", Sign in with Apple (system button, black, white in dark mode, at least 44 pt tall and scaling with Dynamic Type), Google sign-in button, terms and privacy links. See [AUTHENTICATION.md](AUTHENTICATION.md) |
| Sign In | Email, password (Show/Hide), Forgot Password link, Sign In |
| Sign Up | Email, password, confirmation, Sign Up |
| Forgot Password | Email and Send; success shown inline |

Validation errors appear after a field loses focus and is not blank; submit stays disabled until
the form is valid. While a request runs the button shows a progress indicator and further taps are
ignored. Failures appear in an alert with a title-cased title ("Unable to Create Your Account",
"We’ve Encountered an Issue") and the app's own message for the cause; technical text is never
shown. Transient failures (network, timeout, rate limit, server error) offer "Try Again", which
sends the request again only when tapped.

## Main app

A `TabView` with four tabs, each with its own `NavigationStack`:

| Tab | Root screen |
| --- | --- |
| Home | Greeting, category pager, recent notifications |
| Learn | Coding challenges |
| Timeline | Activity timeline |
| Stats | Progress and achievements |

On top of the tabs: the speaker reminder banner and the rating prompt sheet. The first time the
signed-in experience opens, the app asks for notification permission so reminders can be
delivered.

### Home

- "Hello, *name*!" using the profile's first and last name, the first name, or the anonymous ID.
- Category chips (Events, Coding, Community, Career, Games) synchronized with a paged grid of
  feature cards. An odd last card spans the full width.
- Recent Notifications: collapsible, up to 200 pt tall, unread items highlighted; tapping marks the
  item read and opens its destination.
- The menu button opens the account sheet: Profile, Demographic Info, About Tatum Games, FAQ, app
  version, terms and privacy. Debug builds add a "Firebase (Debug build only)" section with the
  environment name, bundle ID, Firebase app ID, Firebase project and status; Release builds do not
  contain it.

| Category | Cards |
| --- | --- |
| Events | Upcoming Events, Scanner, Partners |
| Coding | Coding, AI & LLMs, Stats, Resources |
| Community | Community, Donate |
| Career | Apply for Jobs, Leet Code, Mock Interviews |
| Games | Discover, Resources |

### Events and networking

- **Upcoming Events:** networking card (Create or Edit, Share, Scan), then event cards with flyer
  (full screen on tap), host, date in the event's published time zone, location, Register and
  Virtual Speakers.
- **Virtual Speakers:** speaker cards with photo, company, bio, topic, schedule, time zone and
  Join. Opened from a reminder, the list scrolls to and outlines that speaker. Debug builds add a
  "Test reminder in 10 s" button.
- **Contact Card Editor ("Tatum Tech Card"):** photo from the library or camera, profile, contact
  and link fields; first name and a valid email are required.
- **My Tatum Tech Card:** photo, name, job and company, and a vCard QR code any phone camera can
  read.
- **Scanner:** full-screen camera with permission handling. Invalid or unsupported codes show a
  message and scanning resumes. Opened from Upcoming Events, Back returns there.
- **Connecting With New Friend:** the scanned card's details, Save Contact (records the connection,
  then opens the system New Contact screen) and Cancel.

### Partners

Category chips, partner cards with logo, featured badge, summary and Contact, Website and Donate
actions. A card opens a detail sheet with the description, products and social links. Contact
opens Mail with a prefilled subject; several contacts show a picker; phone-only contacts open the
dialer.

### Challenges

Coding (C#, Java, JavaScript, Kotlin, Python), AI & LLMs, Leet Code and Mock Interviews share one
quiz screen: language and level pickers, 10-question sessions, code snippets, answer feedback with
animation and explanation, a results summary with confetti, and the daily limit message after 30
answers. Sessions resume where they stopped.

### Progress

- **Stats:** count-up rings for events, challenges and QR scans, percent correct, streak,
  achievements unlocked, category breakdown, coding challenge stats, and the first achievements
  with View All.
- **Achievements:** 30 achievements with badge, description, requirement and points; locked ones
  are dimmed.
- **Timeline:** Today, Last Week and Last Month filters over the activity log.

### Career, community and games

- **Apply for Jobs:** search, job category and employment type filters, Apply opens the listing.
- **Resources:** technology filter and Visit links.
- **Community:** Discord banner, icon, name, invite (tap to copy, share), members, online and boost
  level, description, online avatars, Join and Support Us.
- **Donate:** donation tiers open checkout in Safari inside the app.
- **Discover Games:** Featured tab (showcase cards and the MIKROS card) and Games tab (search,
  genre and gameplay chips, carousels).
- **Game Details:** logo, hero image, about, videos, screenshot viewer, store and follow buttons,
  Discord, social links and tags.
- **Get Your Game Discovered:** MIKROS information with Learn More and Explainer Video.
- **Game Resources:** categories of partner resources with Visit Website.

### Profile

- **Profile:** read-only username, first name, last name, email, Save, a black Sign Out text link
  below Save, and Delete Account. Sign Out and Delete Account use the same Yes/No confirmation
  alert, and both show a progress overlay while running. A failed sign-out keeps the user on
  Profile and shows the standard API failure alert.
- **Demographic Info:** a 13-or-older confirmation, three consents that gate Save, and optional
  age range, sex, occupation, salary range and school.
- **About and FAQ:** mission, MIKROS resources, Visit Tatum Tech, and frequently asked questions.

### Rating prompt

A sheet with the logo, mission text and five stars. Four or five stars open the App Store review
page (or the system review request); the prompt never returns after that. It appears every 20 app
opens and after finishing a coding challenge session.

## Visual system

Defined in `DesignSystem/Theme.swift` and the asset catalog:

- **Colors:** BrandPrimary `#BB86FC`, BrandPrimaryStrong `#6200EE`, BrandSecondary `#03DAC5`,
  ScreenBackground `#F0F0F0`, SurfaceBackground white, TextPrimary black, TextSecondary `#616161`,
  plus fixed accents (gold, teal, deep orange, lavender, Discord and Steam colors).
- **Spacing:** 4, 8, 12, 16, 20, 24, 32 pt. **Corner radii:** 8, 10, 12, 16 pt.
- **Buttons:** `.primary` (filled brand; outlined when disabled), `.filledAction(color)`,
  `.outlinedAction`.
- **Feedback:** bottom toasts that hide after 3 seconds and are announced to VoiceOver.
- **Typography:** system text styles so Dynamic Type scales everything.
- **Appearance:** light only, portrait only, iPhone.

## Accessibility

- Every control has a label; image-only buttons have explicit labels.
- Elements used by UI tests have stable identifiers (`welcome.signIn`, `signIn.email`,
  `feature.partners`, `home.greeting`, `menu.profile`, `account.signOut`, `account.delete`, `networking.scan`,
  `contactCard.save`, and so on).
- Toasts post accessibility announcements.
