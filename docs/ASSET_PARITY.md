# Asset Parity

Images, colors, animations and bundled content in the iOS app compared with the Android app's
`res/drawable*`, `res/mipmap*` and `assets/` folders. Counts come from a scripted comparison of
asset names (October 2026).

## Summary

| Kind | Android | iOS | Notes |
| --- | --- | --- | --- |
| Drawable and mipmap image names | 146 | 120 image sets | 119 shared names; 27 Android-only names explained below; 1 iOS-only image |
| Colors | Theme and `colors.xml` | 19 color sets plus fixed palette colors in `Theme.swift` | Same hex values |
| Animations | 2 GIF drawables | 2 GIF files in `Resources/Animations` | Played by `AnimatedGIFView` |
| Bundled JSON | 32 files | 31 files | `mock_notifications.json` is not shipped (see below) |
| App icon | Adaptive icon (`ic_launcher*`) | `AppIcon.appiconset` | Final 1024×1024 artwork pending (TODO.md) |

## Shared images (119)

Same file names on both platforms, so content JSON resolves the same way:

- **Home feature icons:** `upcoming_events`, `scanner`, `partners`, `coding_challenges`, `apps`,
  `stats`, `opportunity`, `community`, `donate`, `jobs`, `career`, `games`.
- **Achievement badges (22):** every `badge_*` image the achievements reference.
- **Challenges:** `coding_challenge_correct`, `coding_challenge_incorrect`, `ai_logo`.
- **Notifications:** `notif_coding_challenge`.
- **Partners (34 logos):** `partner_logo_*`.
- **Games:** logos and screenshots for Banjax, HVN, POG, Saint Art Puzzle and Tales of Encenia
  (`*_logo`, `*_logo_icon`, `*_ss_NN`), plus `gbi_logo`.
- **People:** `speaker_jeff_bogensberger`, `speaker_reginald_owens`, `male_profile_default`,
  `female_profile_default`.
- **Social:** `social_media_discord`, `_instragram`, `_linkedin`, `_meta`, `_tiktok`, `_x`.
- **Brand:** `tatumgames_logo`, `discord_banner`.

## Android-only names (27) and why

| Android asset | iOS equivalent |
| --- | --- |
| `animated_coding_challenge_correct`, `animated_coding_challenge_incorrect` | Same GIFs, stored as files in `Resources/Animations` (asset catalogs do not animate GIFs) |
| `ic_launcher`, `ic_launcher_round`, `ic_launcher_background`, `ic_launcher_foreground` | `AppIcon.appiconset` |
| `ic_notification_speaker` | iOS notifications always show the app icon; the in-app reminder banner uses the SF Symbol `person.wave.2.fill` |
| `back_arrow`, `forward_arrow`, `hamburger_icon` | System navigation back button and SF Symbols (`chevron.right`, `line.3.horizontal`) |
| `profile_email`, `profile_name`, `profile_phone` | SF Symbols in form fields (`envelope.fill`, `person.fill`, `phone.fill`) |
| `android_dark_sq_signin`, `android_light_sq_signin` | `google_sign_in_button` (the iOS-only image) and Apple's `SignInWithAppleButton` |
| `events`, `my_timeline`, `notif_event_registration` | Not referenced by any Android screen or content file |
| `badge_heart_giver_01`, `badge_qr_explorer_01`, `badge_showed_up_01` | Unused alternates; the referenced badges are shipped |
| `banjax_logo`, `talesofencenia_logo`, `talesofencenia_logo_alt`, `muffinvr_logo` | Not referenced by `games.json` or any screen (the `*_logo_icon` variants are) |
| `partner_logo_google` | Not referenced by `partners.json` |
| `tatum_tech_flyer_01` | Not referenced; the event data references `tatum_tech_placeholder_flyer_01`, which neither platform has (TODO.md) |

## Bundled JSON

All content files are byte-for-byte copies so both platforms serve the same questions, listings
and catalogs. `mock_notifications.json` is not shipped: Android never reads it, and iOS builds
recent notifications from real events and the daily challenge.

## Colors

Asset catalog colors: BrandPrimary `#BB86FC`, BrandPrimaryStrong `#6200EE`, BrandSecondary
`#03DAC5`, ScreenBackground `#F0F0F0`, SurfaceBackground white, TextPrimary black, TextSecondary
`#616161`, Error, Success, Divider, Disabled, FeatureCardBackground, IconBackground,
FeaturedAccent, PartnerContact, PartnerDonation, and others. Fixed colors used by individual
screens (gold, teal, deep orange, Discord blurple, Steam dark, lavender, greys) are defined in
`Palette` with the same hex values as the Android theme.
