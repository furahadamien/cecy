# Onboarding and Settings UX refinements

September 30, 2026 · `fix/onboarding-ux-settings`

## Research and design choices

Reviewed public product material, not a hands-on audit of competitors’ current onboarding screens:

- [Flo product tour](https://flo.health/product-tour) and [period tracking overview](https://flo.health/product-tour/tracking-cycle): benefit-led presentation and goal-oriented tracking.
- [Clue](https://helloclue.com/): quick tracking, clear personal benefits and prominent privacy reassurance.
- [Apple onboarding guidance](https://developer.apple.com/design/human-interface-guidelines/onboarding): focused, brief prerequisites; optional nonessential setup; context for permission requests.
- [Apple slider guidance](https://developer.apple.com/design/human-interface-guidelines/sliders): live values, understandable ranges and precise supplementary adjustment.

Applied these principles using Cecy’s existing warm neutral/sage palette and native controls. No competitor assets, layouts, medical claims, algorithms, analytics or AI features were copied.

## Changes

- **Appearance:** Settings has a Dark mode toggle and Use device appearance action. The default follows the device. An optional Codable preference preserves backward compatibility with existing privacy files and does not reset lock/reminder choices. The root, sheets and separate privacy-cover window follow the resolved appearance. Failed writes retain the previous selection.
- **Measurements:** height and weight use sliders with a large live value, range endpoints, fine +/- controls and individual Clear actions. Moving a slider or using a fine adjustment explicitly adds that value; merely viewing the screen does not save suggested defaults. Wider ranges are available. Canonical centimeters/kilograms remain unchanged when the display system changes. Existing values outside the compact range remain accessible. These fields remain optional and never enter prediction calculations.
- **Onboarding:** a dedicated page presentation replaces the Settings-style heading. Pinned progress, a restrained per-step symbol, short supporting copy, selected-row feedback and persistent Continue/Skip controls improve hierarchy. Validation appears above the primary action rather than below a long scrolled form. Review edits are grouped in a disclosure. Four period starts, backward editing, optional answers and all prediction safeguards remain unchanged.
- **Apple sign-in:** new users see “Sign in to save your details,” explicitly saving on this device. Linking and reconnection use different wording. No copy suggests cloud backup or cross-device recovery.
- **Logout:** Settings → Apple Account → Log out has a confirmation. Logout is durable across relaunch, clears the published in-memory health snapshot, cleans temporary exports, and returns to a generic sign-in screen. Records, profile, preferences, reminders and app lock are not deleted or disabled.

## Logout safety

The Apple identifier/profile binding remains in the non-synchronizing, device-only Keychain, alongside an explicit signed-out flag. This is disclosed in the signed-out screen. It prevents a different Apple account from taking over preserved records. A failed Keychain write does not report successful logout. Automatic credential checks and stale callbacks cannot undo an explicit logout. Unreadable identity storage fails closed until retry or a confirmed reset.

After logout, sign in with the same Apple account to reopen local records. Repository loading and ordinary mutations are blocked until reconnection. Revoked authorization alone still does not automatically delete records. Existing users who have never linked an account are not newly forced through onboarding.

The signed-out screen offers the existing typed DELETE confirmation to delete local data and start over, including when the original Apple account is unavailable. Deletion is separate from logout. It does not delete the Apple Account or revoke Apple’s system authorization. A reset failure may leave records already removed but the Keychain binding uncleared; the error explicitly requests another cleanup attempt.

## Validation

- Added `UXImprovementsTests.swift` for legacy preference/identity decoding, appearance persistence/failure, slider conversion/bounds, logout reload, preserved records, mutation gates, same-account reconnection, reset and Keychain failure behavior.
- Added/updated UI checks for appearance persistence, measurement slider clearing, logout confirmation/cancellation/relaunch, reconnection and the redesigned headings.
- Direct macOS checks using actual domain, SwiftData and session/service sources passed: appearance round trips, slider unit conversions/bounds, durable logout, blocked signed-out reads/mutations, preserved records/reminders/predictions, reconnection and explicit reset.
- The focused iOS test run failed before launching tests: **simulator boot could not proceed due to insufficient system resources**. This is not a passing iOS test run. Results: `/tmp/cecy-ux-tests.xcresult`.
- Build logs: `/tmp/cecy-ux-final-build.log` and `/tmp/cecy-ux-release-build.log`. Host check: `/tmp/cecy-ux-check.swift`.

## Device checks still required

- Light/dark/device appearance across tabs, sheets, app lock, privacy snapshots, relaunch and system appearance changes.
- Optional sliders, clear, precise adjustment, extended ranges and imperial/metric changes with VoiceOver and large text.
- Onboarding on smaller phones, landscape, iPad and accessibility text sizes; no clipped headings or inaccessible primary actions.
- Real Apple logout/reconnect/cancellation, offline reconnect failure, revoked authorization, different-account rejection and post-logout reset.
- Confirm logout preserves reminders and app lock, and that signed-out/background snapshots contain no health information.

No Phase 6, cloud synchronization, backend or prediction-policy changes.