# Cycle setup and starter predictions

Date: October 2, 2026 · Branch: `testing/on-device-fixes`

## Research and decisions

- [Apple: Track your period with Cycle Tracking](https://support.apple.com/en-us/120356), reviewed October 2, 2026. Apple documents entering the last period start, typical period duration and typical cycle length during setup. Predictions can begin after the last period is entered. Apple does **not** publish its exact prediction algorithm here; Cecy does not claim to reproduce it or use Apple sensor-based predictions.
- [NHS: Periods](https://www.nhs.uk/conditions/periods/), reviewed October 2, 2026. The page describes roughly five bleeding days and 28-day cycles as common, while stressing variation. These support the user's requested editable defaults, not a diagnosis or a guarantee for an individual.
- No ovulation/fertility estimates, contraception claims, temperature/heart-rate processing or medical cutoffs were introduced.

## Setup experience

The old four-start gate is replaced with three focused cycle pages:

1. **When did your last period start?** Choose and confirm one past/today date in a native date sheet. An end date is optional, never inferred. Existing staged records are retained; only the selected latest record is edited.
2. **How long is your period?** Vertical wheel starts at **5 days**, editable within 1–30 days.
3. **How long is your cycle?** Vertical wheel starts at **28 days**, editable within 10–120 days, with a start-to-start definition.

The ranges are finite product input limits, not definitions of medically normal cycles. The usual period cannot exceed the usual cycle. Review shows both entered values and identifies the starter estimate. Defaults are applied only to an unfinished setup draft; simply opening an existing Profile does not adopt them. Add/Edit wheel controls in Profile allow later correction or clearing. Other optional profile steps, required account/basics, identity handling, save/discard protection and retryable completion remain.

## Deterministic starter policy

- Requires at least one validated recorded start and an explicitly supplied `typicalCycleDays` preference.
- Used **only when the existing engine returns insufficient history** (fewer than three completed intervals). Center = latest recorded start + supplied cycle days.
- Display range = center ± **3 days**. This is an uncalibrated starter display rule, not an Apple formula, clinical tolerance or probability interval.
- Confidence is always **Low**; provenance is `usualCycle`; `sourceLengths` is empty. The preference is never inserted into observed history or measured statistics.
- Typical period days are presented as a self-reported planning duration. They do not shift next-start arithmetic or create bleeding/end-date records.
- After three completed intervals (four recorded starts), the existing median/range/evidence engine takes over unchanged. Wide variation, invalid dates, and missing starts do not trigger a misleading profile fallback.
- A passed estimate stays passed. The app never advances the start by repeated cycle lengths or inserts assumed periods. The existing reminder planner skips notifications whose firing time is past.
- Backtesting continues to use observed historical intervals only. Today's profile assumption is not applied retrospectively or counted as historical prediction evidence. AI summaries and insights still use recorded facts, not fabricated cycles.

## Persistence and compatibility

- Added optional `LocalProfile.typicalCycleDays` in the existing encoded profile payload; no new SwiftData entity or schema migration.
- Old profile payloads decode the new field as nil and are not forced to repeat onboarding. Already-completed setup remains idempotent without requiring new answers.
- Unfinished onboarding still stages profile and dates atomically, then commits completion separately. One valid start is sufficient; duplicate/future/overlapping records remain invalid.
- New profile value appears only in consented personal-profile exports. Exports containing it use format version 6; older shapes retain their previous version when absent.
- Session recalculation applies the starter policy during setup, loading, profile changes, record changes and date refresh. Clearing cycle length or removing the only start withdraws the starter estimate.

## Validation

- App/test compilation passed (38.4 seconds).
- **54 focused tests in eight unit/domain/persistence/AI-context suites passed**, covering setup defaults, legacy decoding, one-start validation/completion, date arithmetic, no invented ends/history, history takeover and withholding, passed windows/reminders, retrospective exclusion, consented export and reopening/profile edits.
- The initial combined test run failed on two UI issues despite passing all 54 unit tests. The common-symptom container masked child accessibility identifiers; explicit child containment fixed it. At the largest accessibility text size, the test needed to reveal the cycle wheel before reading its value.
- Both corrected UI scenarios passed: largest-text wheel selection (68.722 seconds) and one-start completion, relaunch and profile editing (75.074 seconds). The bounded rebuild/recheck completed in 162 seconds.
- Final unsigned iOS Release build passed (47.9 seconds), including singular-day wording polish. `git diff --check` passed.
- Evidence: `/tmp/cecy-cycle-setup/compile.log`, `focused.xcresult` (initial UI failures plus passing units), `recheck.xcresult` (both corrected UI tests passed), and `release.log`; process deadlines were 4 minutes for builds and 6 minutes for test runs. No indefinite simulator retries, live AI calls, commits or pushes.

## Still open

Physical-device usability, VoiceOver and older supported OS execution; real-world prediction calibration; historical full-suite/privacy acceptance and earlier optional-integration gates. The starter window must not be advertised as clinically validated. No live AI requests or backend changes are needed for this local feature.
