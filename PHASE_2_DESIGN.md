# Cecy — Phase 2 design and acceptance

Date: September 29, 2026
Branch: `phase-2`
Status: Implemented; automated acceptance checks passed. Manual device, iOS 17 runtime, and full accessibility verification remain pending.

## Scope
Complete everyday period tracking: saved-record correction/deletion, optional flow/notes, explicit end entry, local descriptive statistics, and deletion of app-held tracking data. Preserve the four tabs. No symptoms, patterns, notifications, accounts, AI, HealthKit, subscriptions, or cloud services. Phase 1 manual device/accessibility checks remain open.

## System design
- Keep the existing dependency flow: SwiftUI → TrackerSession → pure Swift domain and repository contract → SwiftData.
- One shared committed snapshot drives all screens. Update/delete/reset publish only after successful persistence; failures retain drafts and the last committed snapshot.
- Reuse the period form for new records, onboarding drafts, and saved edits. Preserve IDs/createdAt; update updatedAt only on successful edits. Validate the entire candidate history before writes. Existing duplicate/overlap/future/reversed-date rules remain unchanged.
- Introduce an immutable V2 schema and an explicit V1 → V2 lightweight migration. V1 models remain unchanged. Add nullable flow and notes fields; existing records migrate to nil. Use the SAME store URL (`Cecy/CecyPeriodsV1.store` is a historical filename, not a request to create a second store). No reset, copied parallel store, or reinterpretation of template timestamps.
- Flow: nil, light, moderate, heavy. It is the user's overall summary of that period, not a daily observation, a clinical assessment, or an input to prediction. Unknown persisted enum values fail validation rather than silently dropping information.
- Notes: optional plain text, maximum 2,000 characters. Validate rather than silently truncate. Notes stay local and are not included in logs or analytics. Empty text becomes nil; preserve meaningful text unchanged.
- No new ongoing-state field: a missing end can mean ongoing OR unknown. Never infer either. Provide Edit period / Add end date on saved records, including the latest start on Today. Calendar confirms only the start or explicitly bounded span. This avoids inventing bleeding during unrecorded days.

## Statistics definitions
Computed in pure Swift from the validated snapshot, never persisted:
- Completed cycle intervals: every consecutive pair of starts, excluding the current open interval. Use all recorded completed intervals for descriptive statistics; the prediction engine still uses at most six.
- Arithmetic mean and median; minimum/maximum and spread in calendar days.
- Variability: population standard deviation of the recorded sample, available only with at least two intervals. Explain that this describes records, not medical normality or prediction accuracy.
- Distribution: counts for each exact observed cycle length, sorted; an accessible text distribution avoids chart-only interpretation.
- Average bleeding duration: inclusive duration for entries with confirmed ends only. Show the number included and number without an end. One observation can be shown explicitly as one, never as an established pattern.
- Empty data displays an explanation, not zero-day statistics. Invalid/future-date context withholds affected statistics while retaining record-management access.

## UI and interaction design
### Logging and correction
- Calendar recorded-day detail offers Edit period and Delete period. Insights offers a separate Recorded periods list so every entry, including a single start or a future-dated record after travel, remains reachable.
- Today offers Edit latest period / add end date beside current recorded context.
- Shared form: required start, optional confirmed end, optional flow picker, optional multiline note and visible character count. Edit uses Save changes; onboarding drafts use Add to list. Cancel/discard never saves.
- Inline validation and persistent save failure messages preserve values; native controls, Dynamic Type, VoiceOver labels, and 44-point actions remain standard.
- Per-record deletion is a destructive confirmation stating that calculations will change. Failure leaves the record visible with Retry through the same action. Deleting the last period leaves onboarding completed and shows honest empty states.
- Add previous periods remains available after onboarding. Existing history is never duplicated by re-entering onboarding.

### Insights
1. Completed interval explanation/count.
2. Compact descriptive summary (mean, median, recorded range, spread, variability).
3. Exact-length frequency disclosure.
4. Confirmed period-duration summary with denominator and exclusions.
5. Prediction evidence and source intervals.
6. Recorded periods with editing/deletion and optional flow/notes in details, not health content in accessibility identifiers.
No diagnostic labels, trend claims, charts without equivalent text, or default averages.

### Settings and reset
- Separate destructive Delete all data action, then an explicit confirmation sheet requiring `DELETE`. State exactly what is removed: local period dates/flow/notes and onboarding completion; return to onboarding after success.
- Inventory the legacy Core Data template's default `cecy.sqlite` and its `-wal`/`-shm` sidecars in the app Application Support directory. The template has only timestamps, no external binary fields. It is excluded from the active build and never opened during cleanup.
- Delete only these allowlisted legacy files when the user explicitly requests reset; do not remove arbitrary Application Support content, preview stores, or test directories. Production cleanup is injected; in-memory and test repositories never touch production paths.
- Current SwiftData rows and onboarding reset in one context save. Legacy filesystem cleanup cannot be atomic with that transaction: perform it before committing current-store deletion; failure leaves current records unchanged and reports that cleanup did not finish (some legacy files might already be removed). Retry is idempotent. Never announce full success after partial failure.
- Logical deletion is not a secure-erasure guarantee. State that device backups and copies outside the app are not removed. Do not promise overwritten SQLite pages, remote deletion, or backup purging.
- No additional audit record is retained after delete-all. Clear derived snapshots, confirmations, and view drafts by returning to onboarding. No notifications/caches exist in this phase.

## Implementation order
1. Domain fields, validation, statistics, tests.
2. V2 migration and repository mapping/update/reset, migration/rollback tests.
3. Session mutation commands and recomputation tests.
4. Shared form, record actions, Calendar/Today/history integration.
5. Statistics presentation and Settings reset workflow.
6. Headless build/tests, update tracking with actual results.

## Acceptance checklist
- [x] V1 file-backed store migrates without lost dates, identity, timestamps, or onboarding state; nil new fields remain nil after reopening.
- [x] New flow/notes round-trip; invalid raw flow and oversized notes are rejected.
- [x] Edit dates/flow/notes persists across relaunch; cancel and validation failures do not mutate records.
- [x] Editing an end changes confirmed Calendar days and duration, not start-to-start lengths.
- [x] Editing starts refreshes intervals, prediction, Today and statistics from one committed snapshot.
- [x] Delete cancel is harmless; confirm deletes only the selected record; last-record deletion does not restart onboarding.
- [x] Reset cancellation is harmless; successful reset survives relaunch and returns to onboarding.
- [x] Reset save/legacy-cleanup failures do not falsely report success; retry succeeds; unrelated files are retained.
- [x] Means, even/odd medians, distribution, standard deviation, unknown ends, empty and single samples have deterministic tests.
- [x] Phase 1 regression suite and Phase 2 UI flows pass without opening Simulator windows.
- [x] Debug and Release builds pass; manual accessibility, iOS 17 and physical-device gates remain explicitly tracked.

## Verification results
- 29 domain/repository/session tests passed, including the in-place migration and failure-recovery checks.
- Four existing UI regressions passed. After correcting the deletion presentation and end-switch test interaction, all three new Phase 2 UI flows passed on rerun.
- Saved-period deletion uses an alert with explicit Keep/Delete actions, ensuring cancel is visible across adaptive presentations.
- Debug and Release simulator builds passed. No additional editor or Simulator windows were opened.
- Checked acceptance items refer to the automated scenarios above, not a completed physical-device or accessibility audit. See IMPLEMENTATION_PLAN.md for evidence paths and remaining manual gates.
