# Cecy — Implementation Plan

Native, privacy-first iOS menstrual cycle tracker.

Created: September 29, 2026

## Purpose and tracking

This document tracks the phased implementation plan derived from the product brief. It is a planning document, not authorization to implement all phases at once.

- Mark a task `[x]` only after its implementation and relevant validation are complete.
- Update the phase status and record decisions, blockers, and validation results below.
- Complete each phase's acceptance criteria before expanding scope.
- Optional integrations may be reordered or deferred based on product validation.

### Progress overview

| Phase | Focus | Status |
| --- | --- | --- |
| 0 | Foundations and product rules | Complete — September 29, 2026 |
| 1 | Smallest useful vertical slice | Implemented; automated checks passed; manual acceptance pending |
| 2 | Everyday period tracking | Not started |
| 3 | Symptoms and local insights | Not started |
| 4 | Prediction quality | Not started |
| 5 | Privacy controls, export, and reminders | Not started |
| 6 | Optional HealthKit integration | Deferred |
| 7 | Subscriptions | Deferred |
| 8 | Optional AI explanations | Deferred |
| 9A | Optional personal cloud synchronization | Deferred |
| 9B | Optional partner sharing | Deferred |

## Product and architecture guardrails

- Native iOS: Swift, SwiftUI, async/await, and preferred SwiftData persistence.
- No required account, backend, or network connection for core tracking.
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

### Tasks

- [ ] Add and edit period starts and ends.
- [ ] Delete individual records with appropriate confirmation.
- [ ] Support optional notes and a clearly defined flow representation.
- [ ] Handle ongoing periods and conflicting dates.
- [ ] Refresh calculations after every relevant edit.
- [ ] Improve empty states, validation, save failures, and onboarding re-entry.
- [ ] Add average and median cycle length to basic Insights.
- [ ] Add cycle-length history, distribution, and variability.
- [ ] Calculate average period duration from completed records only.
- [ ] Establish Today, Calendar, Insights, and Settings as the four primary destinations.
- [ ] Implement delete-all-data behavior.

### Completion criteria

- [ ] Daily logging and historical correction work reliably.
- [ ] Every displayed statistic is traceable to recorded data.

## Phase 3 — Add symptoms and meaningful local insights

**Goal:** Surface personal patterns without overwhelming the user.

### Tasks

- [ ] Add extensible symptom types, optional severity, and optional notes.
- [ ] Support the planned symptom categories: cramps, headache, bloating, fatigue, mood changes, acne, back pain, nausea, breast tenderness, sleep quality, energy, and cravings.
- [ ] Build fast logging sheets accessible from Today and Calendar.
- [ ] Support symptom editing and deletion.
- [ ] Define repeated same-day log behavior.
- [ ] Implement a separate deterministic pattern engine for symptom timing relative to recorded period starts.
- [ ] Detect recurring symptom observations, recent cycle-length changes, variability changes, and period-duration changes.
- [ ] Represent insights as structured domain values with supporting counts, date ranges, and confidence.
- [ ] Limit Today to a small number of relevant observations.

### Evidence and safety rules

- [ ] Do not interpret missing symptom logs as symptom absence.
- [ ] Require sufficient observations before describing a pattern.
- [ ] Distinguish prediction confidence from insight confidence.
- [ ] Do not present temporal association as causation.
- [ ] Defer phase-based observations where phase estimation is insufficiently supported.

### Completion criteria

- [ ] Insights are reproducible in unit tests.
- [ ] Insights explain their supporting evidence and remain descriptive, not diagnostic.

## Phase 4 — Strengthen prediction quality

**Goal:** Make uncertainty useful and defensible.

### Tasks

- [ ] Evaluate the initial algorithm against transparent baseline approaches.
- [ ] Use chronological backtesting with only history available at each prediction point.
- [ ] Measure prediction error and observed coverage of predicted windows.
- [ ] Evaluate recent weighting and robust statistics only where they improve results.
- [ ] Document treatment of unusually long or short cycles; never silently discard raw observations.
- [ ] Refine confidence using history quantity, variability, and prediction-performance evidence.
- [ ] Explain which records informed an estimate.
- [ ] Avoid numerical probability claims unless calibrated.

### Completion criteria

- [ ] The prediction policy is documented, tested, replaceable, and avoids unsupported certainty.

## Phase 5 — Add privacy controls, export, and reminders

**Goal:** Prepare the local product for dependable real-world use.

### Privacy and security

- [ ] Verify iOS Data Protection for the persistent store and related files.
- [ ] Review and accurately explain backup behavior; local-first does not mean device backups cannot contain app data.
- [ ] Add optional Face ID/Touch ID locking with an intentional fallback policy.
- [ ] Obscure sensitive app-switcher content where appropriate.
- [ ] Keep health records and notes out of logs and diagnostics.

### Export and deletion

- [ ] Add JSON or CSV export.
- [ ] Consider a human-readable cycle report after the export foundation works.
- [ ] Handle temporary export files securely.
- [ ] Ensure delete-all-data clears derived caches and scheduled reminders.

### Notifications

- [ ] Add opt-in local period and symptom reminders behind a dedicated service.
- [ ] Default to discreet notification content.
- [ ] Reschedule after edits and prediction changes.
- [ ] Handle denied or revoked permissions gracefully.

### Completion criteria

- [ ] Privacy controls work across app lifecycle transitions.
- [ ] Exports accurately reflect recorded data.
- [ ] Reminders remain optional and under user control.

## Phase 6 — Add optional HealthKit integration

**Goal:** Complement local records without making Apple Health a dependency or the only source of truth.

### Tasks

- [ ] Select a narrow initial set of supported data types.
- [ ] Request permissions only when the user enables the relevant feature.
- [ ] Isolate HealthKit behind a dedicated service.
- [ ] Define provenance, deduplication, conflicts, and import/export direction.
- [ ] Prevent read/write feedback loops.
- [ ] Explain what disabling integration or deleting data does and does not remove from Apple Health.
- [ ] Treat unavailable reads carefully; an empty result is not proof that records do not exist.

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
- Date handling and baseline prediction rules are implemented and unit-tested. Phase 4 still needs to evaluate prediction accuracy and coverage; confidence is provisional.
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

Phase 1 is authorized and implemented as an internal prototype. Finish recorded validation gates and review the app before authorizing Phase 2. Saved-record correction/deletion, symptoms, and all optional integrations remain outside this implementation.

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
