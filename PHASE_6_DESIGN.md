# Phase 6 — Optional HealthKit integration

September 30, 2026 · `phase-6`

**Status: read-only review/import implemented; 13 Phase 6 unit tests and three focused UI flows passed; Release build passed. Full-suite regression failures and signed-device release gates remain open.**

## Starting point

- PR #9 is merged into `main` at `a362a19`; `phase-6` starts from that merge.
- Local tracking now includes onboarding/profile editing, measurement wheels, wrapping symbol-based symptom selections, app lock, and separate daily sexual-activity records.
- SwiftData V5 was the starting schema. V6 adds import receipts; frozen V1–V5 models and migration history remain intact.
- Sexual activity does not inform cycle predictions. Its JSON export is independently opt-in; this is not permission to share it with Apple Health.
- Foreground read-only HealthKit review is now implemented with its capability and purpose text. No write permission or background delivery is requested.

## Goal

Complement Cecy's local records without making Apple Health a dependency or silently changing a person's history. Denying or disabling HealthKit must not block local tracking.

## Baseline validation to close

These are outstanding checks, not completed Phase 6 acceptance criteria:

- [ ] Restore sufficient simulator resources and run the current iOS unit/UI suites, including onboarding, wrapped selections, activity logging, migrations, privacy, export, and reset.
- [ ] Resolve the Phase 5 protection-attribute test disposition without silently weakening its assertions. The historical Phase 5 run was 64/65, not a fully passing suite.
- [ ] Complete the signed-device privacy, backup, biometric/passcode, app-switcher, and reminder checks in [PHASE_5_VALIDATION.md](PHASE_5_VALIDATION.md).
- [ ] Complete Apple sign-in provisioning and real authorization/lifecycle checks in [ONBOARDING_MILESTONE.md](ONBOARDING_MILESTONE.md).
- [ ] Verify iOS 17 compatibility, VoiceOver, large text, smaller phones, dark mode, rotation, and iPad layouts. Historical slider-specific UX checks must now exercise measurement wheels.

Latest merged-change evidence: app and test targets compiled; six activity domain/storage/migration/export tests passed in a temporary macOS harness. Focused iOS execution was blocked by simulator process limits. Host checks do not replace iOS or signed-device verification.

## Implemented first slice

A narrow, **read-only menstrual-flow import with explicit review**, accessed from Settings. There is no persistent connected/authorized flag: Apple hides read-grant status. Each review is explicitly requested; leaving the screen stops it.

- Request only the supported menstrual-flow read permission after the user enables the feature. Do not request access during onboarding or startup.
- Do not initially read or write sexual activity, weight, height, other symptoms, fertility estimates, or predictions.
- Defer writes to Apple Health and automatic/background synchronization. A read-only first slice avoids write-back loops and unintended external disclosures.
- Treat Health samples as source observations, not automatically as complete Cecy periods. Specify how sample dates, time zones, overlapping samples, and cycle-start metadata are presented for review before selecting an import mapping.
- Never infer a confirmed period end or a new cycle merely from adjacent samples or missing days. Do not add imported data to prediction inputs until a user accepts a valid local record.

## Finalized decisions

- [x] Read only menstrual flow. Default last 12 calendar months; selectable 3/6/12 months. Maximum 2,000 samples; larger responses fail visibly rather than silently truncate.
- [x] Off/requesting/reading/review/empty/failed states plus device availability. Authorization-request completion and empty reads never imply read permission.
- [x] Each sample is a source observation, not an inferred period. Source time zone determines the suggested start; absent/invalid metadata uses the captured device zone with a visible warning. Source timestamps remain visible. The user adjusts the date and explicitly confirms a new period start. Never infer an end or whole-period flow. No-flow samples are omitted; unknown flow values cannot be imported.
- [x] A V6 receipt stores source UUID, source name/bundle, source timestamps/time-zone metadata, flow/cycle-start metadata, accepted local period ID/day, fallback zone, acceptance time and mapping version.
- [x] Deduplicate by UUID, not date. Different-source overlaps use normal validation with no overwrite/merge. An already-imported UUID remains reviewed even if source metadata changes; changed metadata is labeled. Local edits are not overwritten. Individual period deletion retains the receipt to prevent reimport. Missing source samples never cause local deletion. Unconfirmed/discarded samples may appear again.
- [x] One atomic period-plus-receipt transaction per confirmation, with rollback. Cancellation and generation/access checks reject stale replies. Stop on leaving review, background, lock, logout or reset; no automatic retry/import.
- [x] Stop clears volatile samples, not accepted records. Revoke OS permission in Apple Health. Delete-all clears receipts/imported periods but not Apple Health; source samples become eligible again after reset.
- [x] Ordinary period exports include accepted dates but not provenance/source metadata. Profile, note and sexual-activity consent is unchanged.

## Implementation boundaries

`HealthFlowReading` isolates HealthKit from domain/persistence. `HealthImportReview` owns cancellable draft state. `TrackerSession` gates imports and recalculates predictions, insights and reminders after commit. The V6 repository atomically stores periods and receipts. Preview/test compositions never contact Apple Health.

No automatic date inference, writes, raw-sample export, cloud configuration or prediction-policy changes. Earlier release gates are not waived; use synthetic data until signed-device acceptance is complete. See [validation](PHASE_6_VALIDATION.md) for actual results.

## Architecture and implementation order

1. Finalize decisions; keep unresolved baseline acceptance gaps as explicit release blockers while developing with synthetic data.
2. Introduce a small injectable HealthKit service boundary with deterministic fakes. Keep HealthKit types out of domain calculations and repository interfaces.
3. Add the capability and accurate purpose text only with the implemented opt-in feature. Check availability before requesting permission.
4. Implement preview/review, explicit acceptance, provenance storage, and idempotent import as a single vertical slice.
5. Add lifecycle/conflict handling and clear disable/delete explanations.
6. Record actual automated and signed-device results in `PHASE_6_VALIDATION.md`; do not create a passing verification record in advance.

## Acceptance scenarios

- Local onboarding and tracking work with HealthKit off, unavailable, denied, revoked, or returning no readable samples.
- Permission is requested only by explicit user action; read authorization is never inferred from write-authorization status.
- Repeated imports/relaunches do not duplicate accepted records; different sources on the same day are not silently merged.
- Conflicts, source changes/deletions, and local edits are reviewed without overwriting or removing local history.
- Failed saves, cancellation, locking, logout, and process interruption cannot leave records and provenance half-committed.
- Civil dates remain correct across supported sample formats, DST, and time-zone changes.
- Disabling, local reset, and exports match their disclosures. No HealthKit access or health details appear in diagnostics while access is gated.
- Existing prediction, symptom, sexual-activity, migration, privacy, and reset regressions remain valid.

No Phase 7–9 work, backend, cloud sync, subscriptions, or AI is included.
Authorized sequence: **6 → 9A → 9B → 8 → 7** ([phase order](PHASE_ORDER.md)).
