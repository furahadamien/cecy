# Cecy — Implementation Plan

Native, privacy-first iOS menstrual cycle tracker.

Created: September 29, 2026

## Purpose and tracking

This document tracks the phased implementation plan derived from the product brief. It is a planning document, not authorization to implement all phases at once.

- Mark a task `[x]` only after its implementation and relevant validation are complete.
- Update the phase status and record decisions, blockers, and validation results below.
- Complete each phase's acceptance criteria before expanding scope.
- Optional integrations may be reordered or deferred based on product validation.

Authorized remaining sequence: **6 → 9A → 9B → 8 → 7**. See [phase order](PHASE_ORDER.md).

### Progress overview

| Phase | Focus | Status |
| --- | --- | --- |
| 0 | Foundations and product rules | Complete — September 29, 2026 |
| 1 | Smallest useful vertical slice | Implemented; automated checks passed; manual acceptance pending |
| 2 | Everyday period tracking | Implemented; automated checks passed; manual acceptance pending |
| 3 | Symptoms and local insights | Implemented; automated checks passed; manual acceptance pending |
| 4 | Prediction quality | Implemented; automated checks passed; manual acceptance pending |
| 5 | Privacy controls, export, and reminders | Implemented; UI/Release passed; protection unit assertion unresolved |
| Pre-6 | Four-period onboarding, local profile, Apple identity | Implemented; validation and device gates in ONBOARDING_MILESTONE.md |
| 6 | Optional HealthKit integration | Implemented; 13 Phase 6 unit / 3 focused UI checks and Release passed; full-suite/device gates open |
| 7 | Subscriptions | Deferred |
| 8 | Optional AI explanations | Deferred |
| 9A | Optional personal cloud synchronization | Deferred |
| 9B | Optional partner sharing | Deferred |

## Product and architecture guardrails

- Native iOS: Swift, SwiftUI, async/await, and preferred SwiftData persistence.
- New-user setup uses Sign in with Apple for identity; subsequent local tracking does not require a network connection. Existing users retain records and can link identity in Settings. No backend or health-data synchronization in the pre-6 milestone.
- Keep health records on-device by default; optional integrations require informed consent.
- Prefer native Apple frameworks and minimal dependencies.
- Dependency flow: views → feature state/view models → use cases/domain services → repositories → persistence and system integrations.
- Keep business logic out of views, predictions out of persistence models, and domain calculations independent of SwiftUI and SwiftData where practical.
- Derive cycles, statistics, predictions, and insights from raw observations rather than duplicating persisted calculations.
- Use deterministic software for facts; reserve AI for explanation.
- Observe, do not diagnose. Never imply predictions are reliable contraception.
- Present uncertainty honestly and distinguish confirmed observations from predictions.
- No advertising SDKs or reproductive-health events sent to generic analytics providers.
- Keep basic prediction, privacy controls, deletion, and access to personal data available without a subscription.
- Build a calm, accessible interface, not an all-pink imitation of existing trackers.
- Do not preemptively build infrastructure for hypothetical cross-platform requirements.

### Authorized detour before Phase 6

See [Onboarding milestone](ONBOARDING_MILESTONE.md). The revised handoff requires four period starts, an editable local profile and Apple identity while retaining the existing prediction engine. The onboarding detour is implemented. Phase 6 read-only Health import is now underway; cloud sync remains deferred. Local records/profile and preferences are excluded from future system backups; earlier backups are not erased. Apple sign-in alone provides neither health-data backup nor cross-device recovery.

## Phase 0 — Confirm foundations and product rules

**Goal:** Resolve storage, calculation, and privacy decisions before building features.

**Decisions and acceptance specification:** [Phase 0 foundations](PHASE_0_FOUNDATIONS.md).

Completed scope: repository audit, documented rules, iOS/iPadOS 17 baseline for app/test targets, and removal of unused cloud/push declarations. At the end of Phase 0 the canvas was sample-only, with no tracking logic or SwiftData container; Phase 1 now replaces the production flow.

### Tasks

- [x] Review the existing Xcode template, deployment target, capabilities, and tests.
- [x] Choose the minimum supported iOS version, accounting for SwiftData availability.
- [x] Plan the transition from the current Core Data template to SwiftData; determine whether existing data needs preservation before removing template storage.
- [x] Define calendar-day semantics rather than elapsed 24-hour intervals.
- [x] Define daylight saving and travel/time-zone behavior.
- [x] Define inclusive period duration and cycle-day counting.
- [x] Define validation for duplicate starts, overlapping periods, missing end dates, future observations, and historical corrections.
- [x] Define insufficient-history and unusual/incomplete-record prediction behavior.
- [x] Establish warm neutral colors, muted accents, typography, spacing, and accessible recorded-versus-predicted indicators.
- [x] Document first-slice acceptance tests.

### Completion criteria

- [x] Storage and date-handling decisions are documented.
- [x] First-slice acceptance tests are defined.
- [x] No optional integrations or backend infrastructure have been introduced.

## Phase 1 — Build the smallest useful vertical slice

**Goal:** Enter previous periods and immediately see useful, locally calculated information.

**Implementation:** Local V1 SwiftData storage, atomic onboarding, pure Swift baseline calculations, Today, Calendar, interval history, and minimal Settings are connected. The original canvas is DEBUG-only. Legacy Core Data source/model are excluded from the app target; existing device stores are untouched.

**Scope:** Internal prototype. Draft correction is supported; saved-record editing/deletion UI remains Phase 2. No symptoms or optional services were added.

**Remaining manual verification:** iOS 17 runtime, physical-device offline use, VoiceOver reading order, contrast, right-to-left layouts, iPad/split-screen/orientation behavior, and lifecycle refresh while forms are open. Storage protection and backup verification remain release gates.

### Lightweight architecture

Introduce only the boundaries needed for this slice; avoid empty services and speculative abstractions.

- [x] App: composition, startup, and navigation.
- [x] Features: onboarding, Today, Calendar, and minimal Settings.
- [x] Domain: plain Swift period values, cycle calculations, and prediction results.
- [x] Data: SwiftData models and a period repository.
- [x] Shared: minimal reusable formatting and UI components.
- [x] Keep SwiftData objects inside the data layer where practical; pass plain Swift values into calculations.

### Local storage

- [x] Persist period starts, optional ends, identifiers, and creation/update timestamps.
- [x] Derive cycles from consecutive period starts instead of persisting duplicate cycle records.
- [x] Explicitly disable cloud synchronization.
- [x] Handle save and startup failures recoverably rather than using template-style fatal errors.
- [x] Establish schema-versioning practices before real user data accumulates.

### Minimal onboarding

- [x] Briefly explain local storage and prediction limitations.
- [x] Allow entry of several historical period starts and correction before completion.
- [x] Allow users without historical records to continue.
- [x] Avoid account creation and notification/HealthKit permission requests.

### Deterministic calculations

- [x] Calculate historical cycle lengths.
- [x] Calculate current cycle day from the latest recorded start.
- [x] Calculate the basic statistics needed for prediction.
- [x] Implement one documented statistical approach for a next-period range.
- [x] Provide a plain-language explanation and appropriately qualified confidence.
- [x] Distinguish insufficient history, an available estimate, and a window that has passed without another recorded period.
- [x] Never invent cycle starts or silently reset the cycle day.

Do not combine weighting, outlier exclusion, and complex confidence scoring unless justified.

### Today and Calendar

- [x] Today: current cycle day when known.
- [x] Today: prediction range when supported, with confidence or an insufficient-history message.
- [x] Today: quick period-start logging.
- [x] Calendar: recorded starts and confirmed bleeding days.
- [x] Calendar: distinctly presented predicted window.
- [x] Calendar: basic date selection and record viewing.
- [x] Do not imply that days following a start-only record are confirmed bleeding days.

### Validation

- [x] Test zero, one, and multiple recorded periods.
- [x] Test unsorted and duplicate inputs.
- [x] Test leap years, month boundaries, daylight saving, and time-zone behavior.
- [x] Test prediction changes after historical corrections.
- [x] Test persistence across relaunches.
- [ ] Test the complete flow with connectivity disabled on a physical device. The implemented slice has no feature networking or cloud dependency; the automated simulator run did not disable host connectivity.

### Completion criteria

- [ ] Final acceptance: verify the implemented launch → onboarding → local save → Today → Calendar flow with connectivity disabled, and finish the manual accessibility/device checks below.

**Gate:** Do not start AI, subscriptions, HealthKit, or cloud work before this slice works correctly.

## Phase 2 — Complete everyday period tracking

**Goal:** Make the core tracker reliable for ongoing use.

**Design:** [Phase 2 system and interaction decisions](PHASE_2_DESIGN.md).

**Implemented scope:** Saved-period editing and confirmed deletion, optional overall flow and private notes, confirmed-end entry, descriptive statistics, and confirmed local-data reset. Existing V1 records migrate in place to V2; no prediction algorithm changes or optional services were introduced. Unknown end dates remain unknown, not assumed ongoing bleeding.

**Validation status:** 29 domain/repository/state tests passed, including V1 migration and reset rollback. All 4 Phase 1 UI regressions passed; the corrected Phase 2 UI rerun passed all 3 new flows. Debug test builds and the Release simulator build passed. Manual iOS 17, physical-device/offline, VoiceOver/contrast, iPad/RTL/orientation, and storage-protection checks remain open; these are not established by simulator tests.

### Tasks

- [x] Add and edit period starts and ends.
- [x] Delete individual records with appropriate confirmation.
- [x] Support optional notes and a clearly defined flow representation.
- [x] Handle ongoing periods and conflicting dates.
- [x] Refresh calculations after every relevant edit.
- [x] Improve empty states, validation, save failures, and onboarding re-entry.
- [x] Add average and median cycle length to basic Insights.
- [x] Add cycle-length history, distribution, and variability.
- [x] Calculate average period duration from completed records only.
- [x] Establish Today, Calendar, Insights, and Settings as the four primary destinations.
- [x] Implement delete-all-data behavior.

### Completion criteria

- [x] Daily logging and historical correction work reliably.
- [x] Every displayed statistic is traceable to recorded data.

## Phase 3 — Add symptoms and meaningful local insights

**Goal:** Surface personal patterns without overwhelming the user.

**Design:** [PHASE_3_DESIGN.md](PHASE_3_DESIGN.md). Implemented and automatically verified on `phase-3`; manual release checks remain pending. No prediction algorithm changes or optional integrations.

### Tasks

- [x] Add extensible symptom types, optional severity, and optional notes.
- [x] Support the planned symptom categories: cramps, headache, bloating, fatigue, mood changes, acne, back pain, nausea, breast tenderness, sleep quality, energy, and cravings.
- [x] Build fast logging sheets accessible from Today and Calendar.
- [x] Support symptom editing and deletion.
- [x] Define repeated same-day log behavior.
- [x] Implement a separate deterministic pattern engine for symptom timing relative to recorded period starts.
- [x] Detect recurring symptom observations, recent cycle-length changes, variability changes, and period-duration changes.
- [x] Represent insights as structured domain values with supporting counts, date ranges, and confidence.
- [x] Limit Today to a small number of relevant observations.

### Evidence and safety rules

- [x] Do not interpret missing symptom logs as symptom absence.
- [x] Require sufficient observations before describing a pattern.
- [x] Distinguish prediction confidence from insight confidence.
- [x] Do not present temporal association as causation.
- [x] Defer phase-based observations where phase estimation is insufficiently supported.

### Completion criteria

- [x] Insights are reproducible in unit tests.
- [x] Insights explain their supporting evidence and remain descriptive, not diagnostic.

## Phase 4 — Strengthen prediction quality

**Goal:** Make uncertainty useful and defensible.

**Design:** [PHASE_4_DESIGN.md](PHASE_4_DESIGN.md). Chronological replay of current corrected records, comparable median/mean/recent-weighted candidates, and evidence-aware Low/Moderate confidence. Production window dates remain unchanged. No schema changes or optional integrations.

**Interpretation:** Replay is not an audit of forecasts actually issued or data known at the time. It excludes the target and later intervals from each prediction but reconstructs history from current records. Synthetic comparisons establish behavior, not real-world calibration.

### Tasks

- [x] Evaluate the initial algorithm against transparent baseline approaches.
- [x] Use chronological backtesting with only preceding recorded intervals at each prediction point; disclose that historical entry/edit availability cannot be reconstructed.
- [x] Measure prediction error and observed coverage of predicted windows.
- [x] Evaluate recent weighting and robust statistics only where they improve results.
- [x] Document treatment of unusually long or short cycles; never silently discard raw observations.
- [x] Refine confidence using history quantity, variability, and prediction-performance evidence.
- [x] Explain which records informed an estimate.
- [x] Avoid numerical probability claims unless calibrated.

### Completion criteria

- [x] The prediction policy is documented, tested, replaceable, and avoids unsupported certainty.

**Validation:** 52 unit/storage/state tests, all 12 UI flows, and Release simulator build passed. See [PHASE_4_VALIDATION.md](PHASE_4_VALIDATION.md) for synthetic comparisons and the decision to retain the median window. Confidence remains uncalibrated; manual release checks remain open.

## Phase 5 — Add privacy controls, export, and reminders

**Goal:** Prepare the local product for dependable real-world use.

**Design and evidence:** [PHASE_5_DESIGN.md](PHASE_5_DESIGN.md) and [PHASE_5_VALIDATION.md](PHASE_5_VALIDATION.md). Locking, JSON export, discreet reminders and coordinated reset are implemented. No health-schema migration, networking or third-party dependencies.

**Verification incomplete:** All 15 UI flows and Release build passed. 64 of 65 unit tests passed; one test has four protection-attribute readback failures on Simulator. Its assertions remain intact. Approval was requested to separate device-only readback from simulator-safe filesystem checks. Physical-device protection must not be inferred from these results.

### Privacy and security

- [ ] Verify iOS Data Protection on a signed device for the real store and recreated sidecars. Complete protection is requested in code and signing configuration; readback remains unresolved on Simulator.
- [x] Explain backup behavior and external-copy/deletion limitations without claiming backups were inspected.
- [x] Add optional Face ID/Touch ID locking with system device-passcode fallback; cancellation and stale replies remain locked.
- [x] Implement app-switcher shielding above app-owned sheets and scene-activation synchronization. Actual snapshots remain a manual gate.
- [x] Keep health records and notes out of application logs; diagnostic fixtures are synthetic only.

### Export and deletion

- [x] Add versioned JSON export with civil dates, IDs, metadata, flow and observations; notes require explicit consent.
- [x] Consider a human-readable report: defer PDF/report UI until after the JSON foundation.
- [x] Implement protected temporary export writes, backup exclusion and scoped cleanup/retry. Device-level protection verification remains open above.
- [x] Clear derived state, temporary exports and owned reminders on reset; retain the security lock preference.

### Notifications

- [x] Add opt-in local daily logging and pre-window reminders behind an isolated service.
- [x] Use discreet notification content with no health details.
- [x] Reconcile schedules after saved record, preference, date/time-zone changes and unlocked foreground refresh.
- [x] Handle denied/revoked permissions and scheduling failures; serialize replacement and reset races.

### Completion criteria

- [ ] Final privacy acceptance: signed-device protection, actual authentication/fallback, app-switcher snapshots, backup and notification-delivery checks.
- [x] JSON export content/note consent and cleanup are covered by unit and UI tests.
- [x] Reminder choices and reset are verified using injected delivery; real OS delivery remains a device gate.

## Phase 6 — Add optional HealthKit integration

Implementation and acceptance details: [design](PHASE_6_DESIGN.md), [validation](PHASE_6_VALIDATION.md). No write or background-sync scope.

**Goal:** Complement local records without making Apple Health a dependency or the only source of truth.

### Tasks

- [x] Select a narrow initial set of supported data types.
- [x] Request permissions only when the user enables the relevant feature.
- [x] Isolate HealthKit behind a dedicated service.
- [x] Define provenance, deduplication, conflicts, and import/export direction.
- [x] Prevent read/write feedback loops.
- [x] Explain what disabling integration or deleting data does and does not remove from Apple Health.
- [x] Treat unavailable reads carefully; an empty result is not proof that records do not exist.

### Completion criteria

- [ ] The app remains fully functional without authorization.
- [ ] Integration cannot silently duplicate or overwrite records.

## Phase 7 — Introduce subscriptions

**Goal:** Monetize advanced value without restricting basic tracking.

### Tasks

- [ ] Decide free/premium boundaries based on product validation.
- [ ] Add a dedicated StoreKit 2 subscription manager.
- [ ] Implement purchasing, verified entitlements, restoration, and subscription management.
- [ ] Handle pending purchases, renewals, refunds, revocations, expiration, and offline behavior.
- [ ] Test using StoreKit configuration and sandbox tools.
- [ ] Keep basic prediction, privacy controls, deletion, and access to personal data available without a subscription.
- [ ] Preserve records when premium access expires.
- [ ] Use App Store Connect aggregate metrics initially; do not add health-event analytics.

### Completion criteria

- [ ] Verified entitlements, not local toggles, control premium access.
- [ ] Purchase flows pass lifecycle testing.

## Phase 8 — Add optional AI explanations

**Goal:** Explain deterministic findings without replacing them.

### Tasks

- [ ] Begin with a bounded explanation or summary feature, not an unrestricted chatbot.
- [ ] Add explicit opt-in and clear disclosure of external processing.
- [ ] Build a local AI context builder that selects only relevant summarized information.
- [ ] Exclude identifying information, private notes, and unrelated history by default.
- [ ] Create a thin, preferably stateless Azure Function relay; never embed the OpenAI API key in the app.
- [ ] Add server-side secrets, request validation, payload/token limits, rate/spending limits, and appropriate abuse protection.
- [ ] Disable sensitive-payload logging, including infrastructure diagnostics that could capture requests.
- [ ] Verify provider retention and processing policies before release.
- [ ] Validate structured responses before displaying them.
- [ ] Separate recorded observations from general educational information.
- [ ] Provide safe failure states when offline, limited, or unavailable.
- [ ] Keep the core app usable with AI disabled.

### Completion criteria

- [ ] No AI request occurs without consent.
- [ ] Transmitted data is minimized for the specific feature or question.
- [ ] Responses do not diagnose or contradict locally calculated facts.

## Phase 9 — Add optional cloud capabilities

Treat personal synchronization and partner sharing as separate projects.

### Phase 9A — Personal synchronization

- [ ] Evaluate SwiftData–CloudKit behavior and migration implications.
- [ ] Define conflict resolution, deletion propagation, account changes, and unavailable-iCloud behavior.
- [ ] Preserve full local functionality.
- [ ] Accurately describe security properties rather than promising unverified encryption guarantees.

### Phase 9B — Partner sharing

- [ ] Verify CloudKit sharing support before choosing the implementation.
- [ ] Evaluate direct CloudKit or Core Data with NSPersistentCloudKitContainer only if justified by actual limitations.
- [ ] Publish a separate minimal shareable status, not the private database or raw internal persistence objects.
- [ ] Add category-level consent and owner-controlled share preferences.
- [ ] Keep initial partner access read-only.
- [ ] Keep full history, private notes, medication/sexual information, AI conversations, HealthKit records, and historical symptoms private by default.
- [ ] Show sharing state and data freshness.
- [ ] Make revocation straightforward; explain that previously viewed or copied information cannot be recalled.

### Completion criteria

- [ ] Only explicitly selected information is shared.
- [ ] Cloud failures cannot block private tracking.
- [ ] Synchronization and sharing lifecycle scenarios are tested independently.

## Quality gates for every phase

Apply these checks repeatedly, not only at release:

- **Accessibility:** Dynamic Type, VoiceOver, sufficient contrast, non-color indicators, meaningful labels, Reduce Motion, and appropriate native controls.
- **Testing:** pure domain tests, repository tests, and focused UI tests for critical flows.
- **Privacy:** review every new field, permission, log, and network request.
- **Medical language:** observe, do not diagnose; never imply predictions are reliable contraception.
- **Reliability:** migrations, recovery, interrupted saves, calendar boundaries, and historical corrections.
- **Scope:** no dependency or infrastructure without a current requirement.
- **UX:** fast logging, honest uncertainty, limited onboarding, no constant upselling, and clear information hierarchy.

## Delivery checkpoints

| Checkpoint | Scope | Complete |
| --- | --- | --- |
| Working prototype | Phases 0–1 | [ ] |
| Core local alpha | Phase 2 | [ ] |
| Insights beta | Phases 3–4 | [ ] |
| Public-release candidate | Phase 5 plus accessibility, privacy, and release review | [ ] |
| Optional product expansion | HealthKit, subscriptions, AI, then cloud capabilities | [ ] |

## Explicitly outside the initial scope

Community forums, social feeds, pregnancy mode/planning, fertility treatment management, medical diagnosis, user chat, Android/web clients, custom authentication, custom database/backend infrastructure, Redis, Firebase, advertising, complex wearables, large educational libraries, an AI chatbot, and partner sharing in the first prototype.

## Decisions log

Record important choices and their rationale as implementation proceeds.

| Date | Phase | Decision | Rationale / consequences |
| --- | --- | --- | --- |
| September 29, 2026 | 0 | iOS/iPadOS 17 minimum; iPhone/iPad only | SwiftData availability without requiring an iOS 27-only feature. App/test configurations aligned; minimum-OS runtime verification still required. |
| September 29, 2026 | 0 | Remove unused cloud/push declarations | No optional service required for the local-first baseline. |
| September 29, 2026 | 0 | Separate local SwiftData V1 store in Phase 1 | Do not reinterpret generic template timestamps as menstrual records; leave old device stores untouched. |
| September 29, 2026 | 0 | Validated Gregorian date-only values | Dates remain stable across travel; duration is inclusive and cycle day starts at 1. |
| September 29, 2026 | 0 | Baseline V1 prediction policy | Minimum three completed intervals, at most six recent lengths, median center and padded observed range. Explicit provisional Low/Moderate confidence; see foundations for exact rules. |
| September 29, 2026 | 0 | Keep canvas fixtures separate | Real domain results replace mock values in Phase 1; no production seeding. |

## Blockers and open questions

- iOS 17 runtime validation remains required before release; installed simulators are 26.2 and 27.0.
- No menstrual schema was found in the repository. Old device stores were not inspected and must remain untouched. Reassess if prior distributed health-data builds are discovered.
- Date handling and baseline prediction rules are implemented and unit-tested. Phase 4 added chronological reconstruction and synthetic comparisons; independent real-world calibration remains open and confidence is provisional.
- Full accessibility, physical-device signing, storage protection, and backup verification remain release requirements.
- Free/premium boundaries: deferred until product validation.

## Validation log

| Date | Phase | Build / tests / review | Result / follow-up |
| --- | --- | --- | --- |
| September 29, 2026 | Canvas | Debug iOS Simulator build | Passed; preview compilation is not a full accessibility audit. |
| September 29, 2026 | 0 | Project/plist validation and audit | Project parses; unused cloud/push declarations removed on disk. No app data deleted. |
| September 29, 2026 | 0 | Debug simulator build-for-testing with iOS 17 minimum | Passed for app and both test targets. Tests compiled, not executed; cases remain templates. |
| September 29, 2026 | 0 | Release simulator build with iOS 17 minimum | Passed. Non-blocking App Intents metadata warning; no AppIntents dependency is expected. No signing/minimum-OS runtime claim. |
| September 29, 2026 | 0 | Acceptance specification | Cases A01–A24 documented in foundations. Planned Phase 1 checks, not passing feature tests. |

## Next authorized implementation scope

Phase 5 is implemented on `phase-5`, but its protection test and manual release gates remain open. Do not label the full test suite green or begin Phase 6 without authorization. Local authentication and notifications remain optional; HealthKit, cloud, subscriptions and AI are deferred.

### Phase 1 verification record

- Debug build-for-testing passed on the iPhone 17 Pro simulator destination (iOS 26.2).
- Initial run: all 20 domain/repository/session tests passed (including a parameterized storage round trip with and without history).
- Initial UI run: onboarding, history/prediction/duplicate protection, and skip/log/relaunch passed. The large-text assertion required scrolling to the expanded detail; the corrected full rerun passed all four UI tests.
- Tests use synthetic observations, fixed clocks, and isolated stores. Unit-test host composition never opens production storage. No Simulator application window was launched.
- Final full Debug test run: **passed**, 20 Swift Testing tests across 2 suites plus 4 XCTest UI tests on iPhone 17 Pro / iOS 26.2. A final unit-only rerun after test concurrency-warning cleanup also passed all 20 tests.
- Release generic iOS Simulator build: **passed** for arm64 and x86_64 with iOS 17 deployment target. Only the expected App Intents metadata warning remains; no AppIntents dependency is needed.
- Build/test results: `/tmp/cecy-phase1-verified.xcresult`, `/tmp/cecy-phase1-unit-final.xcresult`; Release log: `/tmp/cecy-phase1-release.log`. These are local temporary artifacts, not repository files.
- `git diff --check`: passed. No optional capabilities or dependencies were added.
- Automated checks do not establish minimum-OS runtime compatibility, physical-device storage protection, a full accessibility audit, or disconnected-network behavior. Those remain unchecked above.


### Phase 2 verification record

- Design and acceptance: [PHASE_2_DESIGN.md](PHASE_2_DESIGN.md).
- **29 Swift Testing tests passed** across 4 suites on iPhone 17 Pro / iOS 26.2. Includes in-place V1-to-V2 file migration, metadata round trips, note limits, statistics, edit/delete recomputation, reset durability, and rollback/retry when saves or legacy cleanup fail.
- **4 Phase 1 UI regressions passed** in the full run: history/prediction/duplicate prevention, large text Calendar, onboarding drafts, skip/log/relaunch.
- Initial new UI run found an adaptive confirmation-dialog cancellation issue and a test tap targeting the switch's label rather than its control. Saved-period deletion now uses an explicit two-action alert; the edit test verifies the actual switch value before saving.
- **3 Phase 2 UI tests passed** on the corrected rerun: delete cancellation/confirmation and recalculation; confirmed end and note persistence plus discarded-edit preservation; reset cancellation/confirmation and onboarding after relaunch.
- **Debug test builds and Release generic iOS Simulator build passed** (arm64/x86_64, iOS 17 deployment target). Expected App Intents metadata warning only. This is not an iOS 17 runtime or signed-device test.
- Evidence: `/tmp/cecy-phase2-full.xcresult` (29 unit tests and 4 regression UI passes, plus the two initial failures), `/tmp/cecy-phase2-ui-verified.xcresult` (3 corrected UI passes), and `/tmp/cecy-phase2-release.log` (Release success). Temporary local artifacts, not committed files.
- No additional editor or Simulator application windows were opened. All fixtures use isolated synthetic records. Production data was not reset during testing.
- Reset removes current logical records and onboarding state; only confirmed production reset also removes the allowlisted old template store/sidecars. It does not purge backups or guarantee secure overwriting of storage pages.
- No commit or push was performed as part of implementation. Phase 3 and optional integrations remain unstarted.

### Phase 3 verification record

- Design: [PHASE_3_DESIGN.md](PHASE_3_DESIGN.md). One observation per type/day; optional symptom severity versus separate energy/sleep ratings; no missing-log absence inference.
- Additive V3 schema preserves frozen V1/V2 models. Reset includes observations, ratings, and notes. No CloudKit, network client, AI, subscription, or new dependency was added.
- **42 Swift Testing tests passed across 6 suites** on iPhone 17 Pro / iOS 26.2. Includes V1/V2-to-V3 file-backed migration, CRUD/identity, validation, rollback/retry/reset, pattern thresholds, fully elapsed windows, leap/DST/date-line boundaries, and correction recomputation.
- All **7 existing Phase 1/2 UI regression tests passed** in `/tmp/cecy-phase3-ui.xcresult`. The initial run also passed evidence navigation but failed two symptom interaction checks. The Calendar accessibility grouping and Today test scrolling were corrected; the focused rerun passed **all 3 Phase 3 UI flows plus the large-text Calendar regression**, with no failures. Across the two runs, all 10 UI flows passed.
- Debug test compilation and Release generic simulator build passed. Final Release rebuild includes the fully elapsed-window rule and accessibility improvements.
- Final focused run: `/tmp/cecy-phase3-verify.xcresult` reports **46 tests passed, zero failures** (42 Swift Testing tests and 4 UI tests; parameterized cases produce additional executions). Initial unit run: `/tmp/cecy-phase3-unit.xcresult`; final Release log: `/tmp/cecy-phase3-release-final.log` reports BUILD SUCCEEDED. Temporary local artifacts, not repository files.
- No extra editor or Simulator application windows were opened. Tests use isolated synthetic records; production data was not reset. No commit or push performed.
- iOS 17 runtime, physical-device/offline behavior, signing/data protection, dark mode/iPad layout, and manual VoiceOver/Dynamic Type audits remain release gates.

- Final review: new observation timestamps default to creation time and are assigned by the repository; the existing Phase 2 file-backed V1 fixture now exercises the V1 → V2 → V3 migration chain. Current-store reset is transactional; legacy file cleanup is separate and cannot be rolled back. No confirmed blocking findings. `git diff --check` passed.

### Phase 4 verification record

- Design: [PHASE_4_DESIGN.md](PHASE_4_DESIGN.md); evaluation and decision: [PHASE_4_VALIDATION.md](PHASE_4_VALIDATION.md).
- Production retains V1 median/window dates and uses V2 evidence-aware confidence. Replays are derived locally from current records, not stored or described as previously issued forecasts. No raw records, schemas, entitlements or dependencies changed.
- **52 Swift Testing tests passed across eight suites**, including all earlier domain/storage/state regressions and ten new replay/confidence/state tests. Final run includes golden totals for all six synthetic fixtures and three candidates.
- **All 12 UI flows passed** in one complete run: two new source/evidence/sparse-history flows plus all ten Phase 1–3 regressions, including large-text Calendar, editing, symptoms, reset and relaunch.
- **Debug test builds and Release generic iOS Simulator build passed** on the iOS 26.2 test destination / iOS 17 deployment target. No iOS 17 runtime or signed-device claim. Existing test trailing-closure warnings and expected App Intents metadata warnings remain non-blocking.
- Result bundles: `/tmp/cecy-phase4-final.xcresult`, `/tmp/cecy-phase4-ui.xcresult`; initial passing domain comparison: `/tmp/cecy-phase4-unit-verified.xcresult`; Release log: `/tmp/cecy-phase4-release.log`. Temporary local artifacts, not repository files.
- An initial compiler error identified the Calendar explanation call missing the new arguments; corrected before passing verification. Final review confirmed replay failures clear stale evidence and both confidence paths use the same deterministic V1 replay.
- `git diff --check` passed. No Simulator application was launched; tests used isolated synthetic records, never production storage. No commit or push performed.
- Minimum-OS runtime, physical-device/offline behavior, storage protection/backup behavior and manual accessibility/layout checks remain release gates. Synthetic results are not representative medical evidence or calibration.

### Phase 5 verification record

- Implementation/design: [PHASE_5_DESIGN.md](PHASE_5_DESIGN.md); detailed results and device checklist: [PHASE_5_VALIDATION.md](PHASE_5_VALIDATION.md).
- **64 of 65 unit/storage/state tests passed** across ten suites. One test reports four failed protection-attribute assertions on Simulator; the full unit suite remains failing and was not weakened to manufacture a pass.
- **All 15 UI flows passed** on the final rerun, including the 12 Phase 1–4 regressions and three new privacy/export/reminder flows. Initial navigation/scroll/share-sheet failures are retained in earlier result bundles.
- **Debug test targets compile and Release generic simulator build passed** for arm64/x86_64, targeting iOS 17. Tests ran on iPhone 17 Pro / iOS 26.2. This is not signed-device or minimum-OS runtime verification.
- Result bundles: `/tmp/cecy-phase5-unit-checked.xcresult`, `/tmp/cecy-phase5-ui-final.xcresult`; Release log: `/tmp/cecy-phase5-release-final.log`. Temporary local artifacts, not committed files.
- Complete Data Protection entitlement is connected to both app configurations; generated Info.plist includes the Face ID purpose string. File encryption/locked-device behavior still requires physical verification.
- `git diff --check` passed. No Simulator application was launched. Test stores, preferences, exports, authentication and notifications are isolated from production. No commit or push performed.
