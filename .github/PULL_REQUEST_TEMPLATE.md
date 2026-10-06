## Summary

<!-- One or two sentences: what this PR does. -->

- [ ] The title describes the change in plain language

## Problem

<!-- What was wrong or missing, and who it affects. Link issues. -->

- [ ] The problem is described or linked

## Implementation

<!-- Approach and notable decisions. -->

- [ ] Follows the existing structure (core logic in TatumTechKit, UI in TatumTech/Features)
- [ ] No unused code, debug output or commented-out code

## Cross-platform Parity

<!-- Product behavior shared with other Tatum Tech apps, and any intentional difference. -->

- [ ] Behavior, copy and analytics stay consistent across Tatum Tech apps, or the difference is explained
- [ ] `docs/FEATURE_PARITY_AUDIT.md` and `docs/ANALYTICS_PARITY.md` updated if features or events changed
- [ ] `docs/PLATFORM_DIFFERENCES.md` updated for any new intentional difference

## Testing

- [ ] `swift test` passes in `Packages/TatumTechKit`
- [ ] App unit tests and UI tests pass in Xcode
- [ ] New logic has tests
- [ ] Tested on a simulator or device (list which)

## UI

<!-- Screenshots or recordings for visual changes. -->

- [ ] Screenshots attached for visual changes
- [ ] Works with large Dynamic Type sizes
- [ ] VoiceOver labels present for new controls

## Security

- [ ] No credentials, API secrets, private keys or provisioning profiles committed
- [ ] Sensitive data stored in the Keychain, not UserDefaults or files
- [ ] No disabled certificate validation or authentication bypasses
- [ ] Privacy manifest updated if data collection or required-reason APIs changed

## Documentation

- [ ] README, `docs/` and `TODO.md` updated as needed
- [ ] `docs/IMPLEMENTATION_LOG.md` entry added for meaningful changes
