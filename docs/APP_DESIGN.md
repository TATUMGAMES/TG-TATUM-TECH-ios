# App Design

How the iOS app is organized for users: screens, navigation, and the visual system. Product
behavior follows the Android app; see [PLATFORM_DIFFERENCES.md](PLATFORM_DIFFERENCES.md) for
where iOS deliberately differs.

## Launch and account state

`RootView` switches on `AppModel.phase`:

- **launching**: logo on the screen background (matches the launch screen) while the stored
  account is restored.
- **signedOut**: the auth flow.
- **signedIn**: the main tab view.

At launch, a stored Apple identity whose credential was revoked in Settings is signed out. On the
first launch after a reinstall, credentials left in the Keychain by a previous install are cleared.

## Auth flow

A `NavigationStack` rooted at the welcome screen:

| Screen | Content |
| --- | --- |
| Welcome | Logo, Sign In, Sign Up, Google sign-in image button, Sign in with Apple, terms and privacy links |
| Sign In | Email, password (Show/Hide), Forgot Password link, Sign In button |
| Sign Up | Email, password, confirmation, Sign Up button |
| Forgot Password | Email and Send button; success message shown inline under the form |

Validation matches Android: an error appears only after the field loses focus and is not blank;
the submit button stays disabled until the form is valid. Server error messages are shown as-is
(capped at 500 characters); network failures and unexpected errors use friendly copy.

## Main app

A `TabView` with four tabs, each owning a `NavigationStack`:

| Tab | Content |
| --- | --- |
| Home | Greeting, category chips, paged feature grid |
| Learn | Coding challenges (pending) |
| Timeline | Pending |
| Stats | Pending |

### Home

- Greeting "Hello, *name*!" using the API user's first name, username, or the Google/Apple name.
- Category chips (Events, Coding, Community, Career, Games) synchronized with a horizontally paged
  `TabView`.
- Each page is a two-column grid of feature cards; an odd last card spans the full width.
- The toolbar menu button opens the account sheet.

Feature cards route through `AppRoute`. Implemented: Upcoming Events and Partners. Every other
card opens a `PendingFeatureView` that explains the feature is coming.

### Account sheet

Logo, Profile, Demographic, About and FAQ rows (pending screens), Delete Account with a Yes/No
confirmation and progress text, app version, and terms and privacy links.

### Upcoming Events

Cards with flyer image (tap for a full-screen viewer), title, formatted date in the event's
published time zone, location, description, Register (opens the registration URL) and Virtual
Speakers (when the event has speakers). Load failures show an inline error with Retry.

### Virtual Speakers

Speaker cards with photo, name, title, company and bio for one event.

### Partners

Category chips (All plus each category), partner cards with logo, name, featured badge, summary and
action buttons (Contact, Website, Donate). Tapping a card opens a detail sheet with the full
description, products, social links and the same actions. Contact opens Mail with the Android
subject line; with several contacts a picker appears; phone-only contacts open the dialer.

## Visual system

Defined in `DesignSystem/Theme.swift` and the asset catalog colors, mirroring the Android theme:

- **Colors:** BrandPrimary `#BB86FC`, BrandPrimaryStrong `#6200EE`, BrandSecondary `#03DAC5`,
  ScreenBackground `#F0F0F0`, SurfaceBackground white, TextPrimary black, TextSecondary `#616161`,
  Error `#D32F2F`, Success `#4CAF50`, plus partner and featured accents.
- **Spacing:** 4, 8, 12, 16, 20, 24, 32 pt. **Corner radii:** 8, 10, 12, 16 pt.
- **Buttons:** `.primary` (filled brand; outlined when disabled), `.filledAction(color)`,
  `.outlinedAction`. Filled buttons use dark text on light brand fills for contrast.
- **Typography:** system text styles so Dynamic Type scales everything.
- **Appearance:** light only (Android has no dark theme). Portrait only.

## Accessibility

- Every control has a label; image-only buttons (Google, menu, social links) have explicit labels.
- Interactive elements used by UI tests have stable accessibility identifiers (`welcome.signIn`,
  `signIn.email`, `feature.partners`, `account.delete`, and so on).
- Dynamic Type is supported through system fonts; layouts use flexible stacks rather than fixed
  heights.
