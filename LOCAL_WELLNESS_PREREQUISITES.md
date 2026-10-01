# Local tracking prerequisites for AI

October 1, 2026 · `planning/phase-8-gpt`

## Authorization and scope

The user requested missing local tracking/preferences before any AI integration. This detour supersedes normalization-first sequencing until its local work is complete. No AI consent, API service, model prompts, gateway requests, new backend, cloud sync or conversation storage is included.

Local implementation complete, with passing focused automated evidence. Full baseline and manual/device acceptance remain open. Implemented scope:

- Digestive changes extend the existing dated symptom taxonomy with optional severity/notes, ordinary edit/delete, calendar and deterministic timing insights. Common-symptom choices in existing onboarding/Profile also include digestive changes; preferences never create symptom logs.
- Optional profile wellness preferences: activity level (Beginner / Moderately active / Very active), nine preferred exercise types, dietary preference (No preference / Vegetarian / Vegan / Pescatarian), food allergies and wellness goals (Manage symptoms / Stay active).
- Nil/unanswered is distinct from explicit empty choices. Allergies distinguish Not answered / No known food allergies / an explicit list; no inferred allergy-free default. Lists validate names, duplicates and limits (20 names, 80 characters each).
- Settings → Profile → Wellness preferences edits a local draft. Done returns it to Profile; Save commits the whole profile. Cancel/clear/error behavior does not silently save. No additional onboarding steps.
- Existing SwiftData V6 store and repository remain in place. An optional Codable profile payload field preserves existing profiles; no schema version or destructive migration. Existing symptom raw values unchanged. Adding the digestive raw value means old binaries cannot necessarily read new symptom records; no downgrade guarantee.
- Profile export consent includes the new preferences/allergies, disclosed in UI. Exports containing wellness use JSON format 4; old formats 1–3 remain when wellness is absent/excluded. Private notes and sexual-activity consent remain independent. Delete-all removes the profile and new fields through the existing reset.
- Cycle predictions and sleep/energy rating semantics remain unchanged.

## Deliberately deferred

- Estimated phase: the current app does not implement a validated phase policy, and the API field is optional. No phase guesses, ovulation/fertility claims or new phase engine.
- AI-derived explanations, wellness suggestions, cycle-summary prose, natural-language input and Ask Cecy remain AI integration work, not local prerequisite fields.
- Fitness activity logs, meals, prescriptions, extra wellness-goal categories and profile fields not requested by the handoff are not added.
- Existing full-suite regression and signed-device release gates remain deferred, not cleared by these focused tests.

## Verification record

Environment: Xcode 27.0 (27A266a); iPhone 17 Pro simulator on iOS 26.2. Synthetic isolated stores only; no production data or live AI endpoint.

- Debug build-for-testing passed, including app, unit and UI test targets.
- **45 focused tests in six suites passed**, including **15 new wellness tests**. Suites: WellnessDomainTests, WellnessPersistenceTests, OnboardingDomainTests, OnboardingPersistenceTests, PhaseThreeDomainTests and PhaseThreePersistenceTests. Result: `/tmp/cecy-local-wellness-unit.xcresult`.
- **All three new UI flows have passing evidence across reruns**, not a single green full-suite run:
  - Cancellation and profile save → relaunch → clear → relaunch passed in `/tmp/cecy-local-wellness-ui-retry.xcresult` (that run still had one symptom-test failure).
  - Digestive logging and relaunch passed in the final focused rerun: `/tmp/cecy-local-wellness-digestive-final.xcresult` (1/1).
  - Initial results remain in `/tmp/cecy-local-wellness-ui.xcresult`. Test fixes explicitly dismiss the keyboard, wait for the sheet, avoid swiping an untouched sheet away, and require controls to be fully above the tab bar before tapping. XCTest had reported a partly covered Today button as hittable. Recorded symptoms are checked in Insights → Observations, not Today.
- **Unsigned iOS Release build passed** (`generic/platform=iOS`, `CODE_SIGNING_ALLOWED=NO`); log: `/tmp/cecy-local-wellness-release.log`. This is not signed-device acceptance.
- Initial Debug build failed after an editor write reintroduced unrelated stale cloud-appearance symbols. Those accidental changes were removed; the final source diff contains only the local prerequisite changes.
- Simulator emitted an invalid-frame warning during the dynamic allergy form update; functional save/clear checks passed after correcting test interactions. Minimum-OS/iPad/Dynamic Type/VoiceOver/layout and signed-device protection checks remain manual acceptance gates, not declared complete.
- Historical full-suite regressions remain deferred. These focused results do not replace the 113/114 unit and 19/30 UI baseline recorded in Phase 6 validation or claim release readiness.

## Acceptance checks

- [x] New/legacy profile encoding and durable reopening preserve answers and unknown/none distinctions.
- [x] Invalid or duplicate allergy input is rejected without mutating committed data.
- [x] Profile save and reset rollback retain original answers on failure; clear/reset work durably.
- [x] Digestive-change CRUD, duplicate rejection, ratings, symbols and insight evidence work through existing paths.
- [x] Profile export includes wellness only with consent and keeps old formats compatible when absent.
- [x] Preferences cannot alter cycle predictions or bypass existing signed-out access gates.
- [x] Focused UI flows verify draft cancellation, explicit Save, clearing, relaunch persistence and digestive logging.
- [x] Debug test targets and Release build pass; remaining device/accessibility gates are disclosed.

Next, report the local implementation to the user and await their direction before review/implementation of the remaining steps in `PHASE_8_AI_IMPLEMENTATION_PLAN.md`; do not start AI integration in this detour.
