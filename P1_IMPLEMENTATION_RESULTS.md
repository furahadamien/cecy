# P1 Implementation Results

Date: October 15, 2026
Branch: `feat/complete-p1-roadmap`

## Scope delivered

### P1.1 Progressive onboarding

- Reduced activation to essential profile and cycle questions.
- Added a realistic Today preview before final setup.
- Persisted the draft and next step after every successful transition using SwiftData schema V8.
- Restores an interrupted setup without replaying completed steps.
- Moved measurements, identity preferences, symptom preferences, goals, reminders, and Apple Health import to an optional Today follow-up and existing Settings screens.

### P1.2 Unified personalized daily check-in

- Preserved the atomic bleeding + symptom check-in and direct logging shortcuts.
- Added stable personalization from onboarding choices and recently recorded symptoms.
- Added pinning, reordering, and hiding symptom choices.
- Added independent visibility controls for sexual activity and treatment categories.
- Added an explicit “Review same as yesterday” draft action; it never auto-saves and never copies private notes.
- Sensitive categories retain a separate visible review and Save action.

### P1.3 Medication and contraception tracking

- Added structured medication, supplement, and contraception records.
- Supports pill, ring, patch, shot, implant, hormonal IUD, copper IUD, barrier, and other methods.
- Supports daily, weekly, four-week, twelve-week, and as-needed schedules.
- Added optional local reminders and explicit Taken, Late, Missed, and Skipped adherence states.
- Unlogged days remain unknown and are never converted to Missed.
- Contraception records atomically create a dated cycle factor.
- No effectiveness, interaction, fertility, or pregnancy-risk calculation is performed.

### P1.4 Dated cycle factors

- Added dated records for pregnancy, pregnancy loss, postpartum, breastfeeding, perimenopause, contraception changes, illness, stress, travel, and possible missed records.
- Added editable start/end dates, private notes, and explicit include/exclude controls.
- Shows exactly which completed start-to-start intervals each factor affects.
- Excluded intervals remain stored and visible; raw period history is never rewritten.
- Forecast evidence shows included and excluded counts and factor reasons.

### P1.5 Appointment Report 2.0

- Added local PDF, CSV, and text reports.
- Added date range, recording coverage, period starts, symptom trend summaries, top concerns, and clinician questions.
- Added optional medication, contraception, and factor timelines.
- Added a full redaction preview before sharing.
- PDF content is searchable text and trend sections include textual alternatives and coverage limitations.
- Existing deterministic plain-text reports remain supported.

### P1.6 Data import and recovery

- Upgraded JSON export to format V8 for factors, treatments, and adherence.
- Preserves nanosecond timestamp precision for exact round-trip deduplication while importing older second-precision exports.
- Added security-scoped file selection, whole-file validation, preview counts, duplicate detection, and three conflict strategies.
- Imports commit in one SwiftData transaction; validation or save failure rolls back the entire import.
- Cecy remains local-only. Automatic encrypted backup was intentionally not added because the product requirement gates it on a completed threat model and key-recovery design.

### P1.7 Improved reminders

- Added period start/end follow-ups, selected symptom prompts, neutral missed-log prompts, and treatment reminders.
- Added native snooze-until-tomorrow behavior.
- Added per-reminder detailed/discreet lock-screen wording controls.
- Notification content never includes recorded symptom values, treatment names, or private notes.
- Reminder taps route to the exact Today check-in or forecast destination.
- Dynamic reminder cleanup removes every Cecy-owned request without touching other apps’ notifications.

## Storage and migration

- Added `TrackerSchemaV8` with lightweight V7 → V8 migration.
- New P1 records use validated Codable payloads in dedicated SwiftData models.
- Reset deletes all V8 records and onboarding progress.
- Existing V1–V7 migration behavior remains covered by regression tests.

## Validation

- A clean Xcode build succeeds for the app, unit-test, and UI-test targets.
- New `P1RoadmapTests` cover factor exclusions, explicit copy-forward behavior, local report formats, reminder planning/snooze, export/import round trips, V8 persistence, contraception-factor synchronization, and transactional import rollback.
- Existing focused appointment, check-in, reminder layout, and V1–V7 migration suites pass.
- Complete `cecyTests` regression on iPhone 17 Pro / iOS 26.2 Simulator: 430 tests discovered, 429 passed, 1 skipped, 0 failed. Parameterized cases produced 499 passing executions.
- The one skip is `PhaseFivePrivacyTests/completeProtectionCoversExportsStoresAndSidecars()`: Simulator does not expose iOS file-protection attributes, so that assertion remains a physical-device validation.
- Final clean-build review fixed an omitted return in detailed reminder text, completed V8 exact timestamp fields used by restore, rejected provider-reported oversized imports before allocation, and corrected “snooze until tomorrow” to resume tomorrow rather than one day late.
- Known pre-existing Swift concurrency warnings in AI request validation remain outside P1 scope.

## Architecture and privacy review

- P1 records remain in the existing local SwiftData store with CloudKit disabled. The store directory, preferences, generated insights, and temporary exports use complete file protection; app-owned persistence is excluded from system backup.
- Schema V8 is an additive lightweight migration. Existing V1–V7 migration coverage passes, V8 payloads are validated on load, and reset includes factors, treatments, adherence, and onboarding progress.
- Daily check-in, contraception/factor synchronization, import replacement, and reset use synchronous main-actor SwiftData transactions with rollback on failure and publication only after commit.
- Restore is user-initiated through a security-scoped JSON file, bounded to 25 MB, fully decoded and domain-validated before preview, conflict-aware, and committed as one transaction. No imported content is uploaded.
- Appointment reports are generated locally from explicit section choices, show the exact redacted document before export, exclude identity, sexual activity, forecasts, and generated AI content, and use protected temporary files that are cleaned on dismissal/backgrounding.
- Notification permission is requested only from a user action. Discreet wording is the default; detailed wording never includes recorded values, treatment names, doses, or private notes. Cecy cleanup is restricted to its identifier prefix, and routes contain only fixed destinations.
- No medication effectiveness, interaction, fertility, pregnancy-risk, diagnosis, or dosing inference was introduced. Missing adherence and missed daily logs remain unknown unless the user explicitly records a state.

## Known deferred boundaries

- Automatic encrypted backup, cloud sync, and cross-device restore remain deferred until a threat model, key-recovery design, and loss/revocation behavior are approved. P1 restore is manual and local-first.
- User-exported JSON, PDF, CSV, and text files are not encrypted after sharing and leave Cecy’s control. The app warns before export and protects only its temporary copy.
- JSON recovery restores health records represented by the export; it intentionally does not restore device-level notification authorization, app-lock/AI consent, Apple sign-in state, HealthKit authorization, or local UI/privacy preferences.
- Treatment tracking is a recording and reminder tool only. Clinical decision support, interaction checks, effectiveness windows, refill management, and inferred missed doses are deferred.
- Physical-device file-protection verification remains part of release-device validation because Simulator cannot expose the required protection attributes.
- The pre-existing AI request-context actor-isolation warnings must be resolved before enabling Swift 6 language mode; they do not change P1’s local transaction or privacy boundaries.
