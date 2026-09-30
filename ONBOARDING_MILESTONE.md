# Pre–Phase 6: Onboarding, local profile and Apple identity

September 30, 2026 · `fix/pre-phase-6`

## Scope and decisions

- This is a detour before Phase 6. No HealthKit, cloud sync, backend, AI, partner sharing or subscription work.
- New users enter **at least four period starts**, not three. End dates and additional history are optional. Existing median-window and evidence-confidence rules are unchanged. Wide variability may withhold a prediction; setup still completes honestly.
- The flow is Welcome → About you → optional measurements → cycle basics → four periods → optional common symptoms → optional context → optional goals → reminders → editable review → Apple sign-in → setup.
- The two existing reminder types are retained: daily check-in (period/symptom logging) and one day before an eligible estimated window. We do not present four differently named toggles for two schedules. Permission is requested during setup only after a user enables a reminder. Denial does not block onboarding.
- Existing onboarded V1–V3 users retain access and history. They can add a profile and link Apple identity from Settings without repeating onboarding or entering four dates again.

## Architecture

- `OnboardingDraft` owns unsaved answers and period records; screens do not write individual answers to persistence. Review calls the existing domain calculators.
- `LocalProfile` contains preferred name, civil birth date, preferred units, optional canonical centimeters/kilograms, predictability, typical duration, common symptoms, cycle context and tracking goals. Exclusive None/Prefer not to say selections are validated.
- `TrackerSchemaV4` adds one versioned profile record, retaining existing period/symptom models. The migration is additive; no destructive reset or guessed profile values.
- Repository staging saves profile and draft periods in one transaction, leaving onboarding incomplete. Retrying replaces only unfinished setup history rather than appending duplicates. Completion is a separate final transaction after calculations and reminder handling.
- `TrackerSession.finishSetup` coordinates real work. Following the revised UX request, onboarding shows “Creating your account…” for at least 1.2 seconds, counting real setup work toward that interval. Completion stays uncommitted until the interval finishes, with cancellation and access rechecked. App backgrounding invalidates the attempt. An interrupted staged setup resumes at Review and requires Apple authorization again.
- A failure after staging can leave local draft records and already-applied reminder preferences, but cannot falsely mark setup complete. Retry is idempotent. Unsaved answers before staging remain in memory; process termination or an app-lock transition may discard those drafts.
- Settings → Profile edits the same local model. Historical dates remain in Calendar/history and trigger the existing recalculation pipeline. Typical duration is a self-reported summary, not a measured average or an inferred end date. Common symptoms never become dated observations. Goals/context remain available for later personalization, not prediction inputs.

## Identity and account lifecycle

- Native `SignInWithAppleButton`/AuthenticationServices establishes a local Cecy identity. There is no custom email/password flow, token backend, remote account database or health upload. Name and birth date come from local profile fields; no Apple name/email scopes are requested.
- Only the Apple user identifier and local profile UUID are stored in Keychain, with `kSecAttrSynchronizable = false` and `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. No Apple identifier is placed in the health store or export.
- Apple sign-in requires network availability. Already-onboarded local tracking does not require a successful online credential check.
- Credential revocation preserves local records and invites reconnection. A different Apple identity cannot silently take over an already-linked profile. Changing identities requires explicit local reset.
- Delete all data removes the local profile, records, local Apple link and existing ancillary data; app-lock preference is preserved. It does not delete the person's Apple Account or revoke Apple's authorization. Manage that authorization in Apple Account settings. No server-side account exists to delete.
- SwiftData, Keychain and notifications cannot share an atomic transaction. If reset fails after identity cleanup, records remain and the local Apple link may already be removed; the error discloses this.
- Debug UI fixtures use isolated file identity stores and a clearly labeled test authorization button. Release builds contain neither the fake authorization UI nor test identity store.

## Privacy and future cloud synchronization

- Onboarding uses plain Continue actions and introduces Apple sign-in only on the final screen: “Sign in with Apple to save your data and begin cycle tracking.” Repeated storage messaging is removed from onboarding; privacy and backup disclosures remain in Settings. Health storage explicitly disables CloudKit. Record/profile and preference directories are excluded from future system backups; exports remain excluded too. Earlier backups and external copies cannot be erased by this change.
- There is no cross-device restoration yet. Apple sign-in alone does not restore health records after deleting Cecy or moving devices. Keychain persistence alone also does not preserve the health database.
- Future cloud sync needs a separate consent, account-mapping, backup/deletion and recovery design. CloudKit's device iCloud account must not be assumed to equal the Apple identity selected during Sign in with Apple. Privacy copy must change before any health synchronization is enabled.
- Complete Data Protection and Sign in with Apple entitlements are declared. Runtime file protection and the existing app-switcher shield remain in place. Entitlements do not substitute for signed-device verification.
- Profile export requires its own opt-in, off by default and independent of note consent. Profile-inclusive JSON uses format version 2 and civil birth dates. Normal record-only exports retain version 1. Neither export includes Apple identity or calculated predictions.

## Validation

- App and unit/UI test targets compile for iOS Simulator.
- Direct macOS host checks of the actual domain sources passed: four-start eligibility, cycle statistics/confidence, no profile inputs in predictions, optional ends, exclusive choices, measurement conversion, profile-export consent and wide-variation withholding.
- Direct host checks of actual SwiftData sources passed: staging, retries without duplicates, completion, profile editing, reset, save rollback, V3 migration, reopening and backup exclusion.
- Direct host checks of actual session/account/reminder services passed: identity required, retry after final-commit failure, derived calculations, revocation preserving records, account mismatch rejection, identity cleanup and non-blocking notification denial.
- The focused iOS unit run could not start: simulator boot failed with **insufficient system resources**. This is not a passing iOS test run. UI test execution remains pending.
- Regression suites are in `cecyTests/OnboardingTests.swift` and `cecyUITests/OnboardingUITestSupport.swift`; prior onboarding/reset UI tests now target the new flow.
- Temporary host-check sources/executables are under `/tmp/cecy-onboarding-{domain,persistence,session}-check*`. Build log: `/tmp/cecy-onboarding-final-build.log`; attempted simulator results: `/tmp/cecy-onboarding-unit.xcresult`.

## Signed-device and release gates

- [ ] Enable Sign in with Apple for the registered app identifier and developer team; regenerate provisioning if required. Do not remove Data Protection or Apple sign-in entitlements to bypass signing failures.
- [ ] Test real Apple success, cancellation, unavailable network, repeated authorization, revocation, account mismatch and interrupted setup. Never use real health data for these checks yet.
- [ ] Run the iOS unit/UI suites, including legacy migrations and reset flows. The previous Phase 5 protection-attribute failure remains unresolved; assertions have not been weakened.
- [ ] Verify actual SwiftData store/WAL/SHM, preferences, temporary exports and Keychain protection on a locked device; verify backup exclusion for the real production directories.
- [ ] Inspect privacy snapshots over birthday/history forms, Apple authorization, profile editing, export/reset and setup. Verify biometrics/passcode cancellation still fails closed.
- [ ] Verify four-date entry, validation, review/back/skip, imperial/metric editing, largest text sizes, VoiceOver, dark mode, rotation and iOS 17 compatibility.
- [ ] Test reminder denial/revocation, stale or unavailable estimates, DST/travel, retries and reset with real notification services.

Phase 6 remains deferred. This implementation is not a claim that all release gates have passed.