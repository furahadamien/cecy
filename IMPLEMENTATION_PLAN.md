# Cecy — Implementation Plan

## October 2 — calendar outline spacing and onboarding copy

Inset period/ovulation outlines in both month calendars and accessibility lists, leaving at least six points between neighboring outlines even when cells have no spacing. Today’s compact strip no longer expands rings beyond its date circles; tap targets and icon rows are unchanged. The welcome CTA now says “Get started”; subsequent steps retain Continue/Back to review. The Apple page adds “Your profile is saved on this device.” directly beneath the heading in secondary Dynamic Type text. Prediction, storage, consent and authentication behavior are unchanged.

Validation: five geometry/marker unit tests and four UI scenarios passed together in one focused run (including compact/large-text calendar layouts and the new welcome/final-page copy). Debug app/test compilation and a separate unsigned iOS Release build succeeded. No live Apple authorization or network features were exercised. Device visual/VoiceOver and prior regression/release gates remain open. No commits or pushes.

## October 2 — historical logging and future-facing period estimates

Calendar period entry now edits existing records or explicitly offers New period versus Add bleeding days. Confirmed ranges update the same record; future starts, ends, symptoms and activity logging remain forbidden. Forecast generation now includes three upcoming centers relative to the actual current day, retaining original nearby projections without creating missing records. Today’s next-period card no longer shows a past center; conflicting history can retain an explicitly labelled Low-confidence reference from a saved typical length. Primary evidence, statistics and reminders remain separate and unchanged. See [HISTORICAL_LOGGING_FIX.md](HISTORICAL_LOGGING_FIX.md) and [ADAPTIVE_CYCLE_FORECAST.md](ADAPTIVE_CYCLE_FORECAST.md) for the revised policy and its limitations.

Validation: all 53 selected unit/persistence tests in nine suites and all three new UI scenarios passed together, including bleeding-range relaunch persistence, editing an existing period, old-start forecasts, retained records after historical insertion and disabled future logging. Debug app/test compilation and unsigned iOS Release build passed (47.3 seconds). Runs were bounded; no retry loop or live requests. Physical-device/accessibility, full regression, older logging-label automation and clinical/release gates remain open. No commits or pushes.

## October 2 — concise Today period-start card

Renamed the card to “Estimated next period start” and removed its gray secondary explanatory paragraphs. Date range, confidence, starter basis, current/overdue status and primary unavailable messages remain; the existing detail link retains the full explanation. No prediction or storage changes. Swift syntax and diff checks passed; no build or simulator rerun for this copy-only follow-up. Previous validation does not establish device acceptance of this edit. Nothing committed or pushed.

## October 2 — shared calendar icon rows and wrapping legend

Merged forecast bleeding/fertile symbols with recorded period, symptom and sexual-activity icons in one eager grid across calendars. The Today strip reserves enough rows for its loaded date range, preventing lazy horizontal sizing from clipping denser dates. Forecast symbols retain distinct identities, colors and accessibility descriptions; prediction logic and saved records are unchanged. Today’s seven legend items now wrap using the shared flow layout instead of horizontal scrolling. Removed the explanatory paragraphs below Calendar’s icon legend; forecast details retain uncertainty and safety information.

Validation: all 20 focused unit/layout/domain tests passed; all four targeted UI checks passed across focused runs (forecast markers in all calendar presentations, normal-size wrapping legend and date bounds, largest-text wrapping, and symbol-only Calendar legend). Debug app/test compilation and unsigned iOS Release build passed (45.4 seconds). The first run also included an older logging test, which failed its unchanged label-height assertion (44-point accessibility frame versus expected 24); this remains an unresolved regression/automation check, not a full-suite pass. No related assertion was weakened or button code changed. Evidence: /tmp/cecy-marker-layout.xcresult, /tmp/cecy-marker-legend.xcresult and /tmp/cecy-marker-layout-release.log. Device visual/VoiceOver and prior full-regression/clinical gates remain open. No commits or pushes.

## October 2 — adaptive four-output calendar forecast

Implemented next-start estimates and uncertainty, expected bleeding dates, a single possible ovulation date, and a distinct six-day estimated fertile window. Retains the existing rolling-six median primary engine and evidence replay; confirmed end dates independently refine bleeding duration. Later-cycle uncertainty now accumulates, with explicitly approximate 10–16-day ovulation offsets. All calendars share markers, date details and context cautions. No fabricated records, biomarkers, automatic AI requests, storage migration or reminder roll-forward. See [ADAPTIVE_CYCLE_FORECAST.md](ADAPTIVE_CYCLE_FORECAST.md) for formulas, example, sources and limitations, superseding the older forecast formulas.

Validation: all 52 selected unit/persistence tests in eight suites and all three targeted calendar UI scenarios passed together on the final source (97.7 seconds), including setup/evidence regressions and the final bleeding outlines. Debug app/test compilation and the separate unsigned iOS Release build passed (36.7 seconds). See the algorithm document for evidence paths. Device/accessibility, full regression, clinical review/calibration and prior release gates remain open. Existing support, daily-insight and progress work is preserved; no commits or pushes.

## October 2 — native developer support implemented

Implemented Settings → About → Contact support for support@thabo.xyz after reviewing Apple MessageUI and SwiftUI OpenURLAction guidance. Uses the native composer after canSendMail succeeds, otherwise system mailto handoff; the visible address and explicit local-only copy remain available. Only the recipient and generic subject are prefilled: no health records, profile, logs or attachments. Cancel, draft, handoff and failure states never claim verified delivery. No backend, dependencies, automatic sending or storage changes.

Validation: six unit tests and the Settings/navigation/copy UI scenario passed together, along with Debug app/test compilation and a separate unsigned iOS Release build. No live email or AI requests. Native Mail, third-party/no-mail configurations, offline behavior and device accessibility remain open; see [CONTACT_SUPPORT.md](CONTACT_SUPPORT.md). Historical full-suite and release acceptance gates are unchanged. Ongoing prediction/insight work is preserved; nothing committed or pushed.

## October 2 — ovulation marker and context correction

Reviewed ASRM and NHS guidance. Replaced the misleading multi-day ovulation markings with one central, explicitly uncertain date per projected cycle. The broader timing envelope remains in an expandable uncertainty explanation, not a fertile window or duration of ovulation. Removed blanket cycle-context suppression: selected factors instead produce specific cautions, including that some hormonal contraception prevents ovulation and the date may not apply. Numerical period predictions and saved profile answers are unchanged. Upcoming selects a non-past central date; a passed estimate does not imply ovulation happened or pregnancy is impossible. Calendar-only accuracy remains limited; biomarkers/clinical validation are not implemented or claimed.

Validation: 24 focused unit tests and all three targeted UI scenarios passed together; Debug app/test compilation and unsigned iOS Release build passed (32.5 seconds). See [OVULATION_FORECAST.md](OVULATION_FORECAST.md) for updated scientific rationale and evidence. This supersedes the previous blanket-context exclusion and range-wide green markings. Full-suite, device/accessibility and clinical/release gates remain open. No backend changes, live AI calls, commits or pushes.

## October 2 — paired future period and ovulation forecast

Replaced the one-cycle ovulation marker with up to three paired future-cycle projections using the same measured/entered cycle length as the period engine. Later period windows widen; ovulation centers and ranges carry those windows back by 14 and 12–16 days respectively. Later cycles explicitly assume preceding estimated periods occur, without creating records or advancing overdue primary predictions/reminders. A shared cached forecast drives all calendars and upcoming-date cards. Selected unreliable cycle contexts suppress only the new ovulation display. Daily-insight behavior is unchanged.

Validation: all 22 focused unit tests (including eight new projection/session checks), both calendar UI scenarios and the unsigned iOS Release build passed. Release took 41.3 seconds; final unit run took 18.0 seconds. One test fixture date was corrected; no algorithm weakening was needed. See [OVULATION_FORECAST.md](OVULATION_FORECAST.md) for formulas, research, assumptions and evidence. Full regression, medical review/calibration and physical-device acceptance remain open. No backend changes, commits or pushes.

## October 2 — possible ovulation and daily insights

Implemented red dashed period-start windows and green dotted possible ovulation in Calendar and both Today calendar presentations. Ovulation is only a rough calendar approximation (estimated next start minus 14 days), not detection, a phase engine or fertility guidance. Insights now has immediate local daily facts and separately consented once-per-day automatic generation; Ask about your records has three offline prepared answers. Existing AI consent never silently enables automatic requests. Daily attempt limits persist locally, generated output remains session-only, and stale/private results are cancelled or cleared. No backend changes or live gateway calls.

Validation: 29 focused unit tests in four suites passed, both new UI scenarios passed across focused runs, and the unsigned iOS Release build passed in 49.8 seconds. See [DEVICE_FEEDBACK_ROUND_6.md](DEVICE_FEEDBACK_ROUND_6.md) for research, implementation limits and evidence. Full-suite, device/accessibility, medical wording/calibration and live gateway/distribution acceptance remain open. No commits or pushes.

## October 2 — fewer repeated dates and smaller logging controls

Removed the full-date subtitle below Today and the full-date line below its calendar strip. Dates identifying records and predictions remain, along with full date accessibility labels. Today and Calendar now opt into the same compact logging style: single-line footnote labels, reduced side padding, a 44-point overall minimum target instead of a 44-point label plus system padding, and intrinsic-width capsules instead of stretched buttons. Controls form a row when they fit and stack at larger text sizes or narrow widths. Other logging entry points keep their existing presentation. Sheet behavior, future-date/overlap guards, activity colors, legend, predictions and prior optimizations are preserved.

Validation: source diagnostics for all six edited app files are clear; the bounded Debug app/test build succeeded (exit 0; /tmp/cecy-compact-logging-build.log). UI assertions were extended for absent repeated dates, compact target sizes, single-line labels and entry sheets but were not executed. Device/VoiceOver and narrow-screen/largest-text runtime review remain pending. No simulator was booted, and nothing was committed or pushed.

## October 2 — compact Today legend and Calendar labels

On `testing/on-device-fixes`, shortened Today’s legend to one row (Period, Estimate, Symptoms, Sex), removed its explanatory paragraph, and reduced date-strip typography, circles, and spacing while preserving at least 44-point date targets. Full meanings remain accessible to VoiceOver; the legend scrolls horizontally at larger text sizes rather than wrapping or shrinking text. Calendar logging labels stay on one line, with an intrinsic-width horizontal row and stacked fallback when space or Dynamic Type requires it. Logging placement, prediction/activity markers, selection guards and earlier optimizations are preserved.

Validation: edited app views have no reported source diagnostics; a bounded Debug `build-for-testing` for the generic iOS Simulator succeeded, including app and test targets (log: `/tmp/cecy-compact-calendar-build.log`). Focused UI assertions were added for legend alignment, compact date targets and single-line button labels, but were not executed. Narrow-screen, largest-text and VoiceOver runtime review remain pending; earlier round-five UI/Release passes do not validate this follow-up. No simulator was booted, no broad regression run was attempted, and nothing was committed or pushed.

## October 2 — simpler cycle setup implemented and focused validation complete

User authorized replacing the four-start onboarding gate with one last-period start, typical period days (default 5) and typical cycle days (default 28), using vertical wheel controls. Apple documents these setup inputs but not its proprietary algorithm; Cecy uses an explicit low-confidence starter policy, then retain the existing recorded-history engine when sufficient history exists. No assumed bleeding end dates or invented periods; legacy missing cycle preferences stay missing. Preserve existing identity/privacy/account workflow. Research and policy are documented in [CYCLE_SETUP_REFRESH.md](CYCLE_SETUP_REFRESH.md). Implementation is complete; 54 focused unit/domain/persistence/AI-context checks passed, including one-start completion, legacy decoding, starter/history transition, no invented bleeding and profile export. Both onboarding UI scenarios passed after an accessibility-container fix and a large-text test visibility correction. The final unsigned iOS Release build passed (47.9 seconds). Physical-device/VoiceOver, historical full-suite and live gateway gates remain open. No backend changes, live AI requests, commits or pushes.

## October 2 — third device-feedback pass implemented and focused validation complete

On `testing/on-device-fixes`: Weather-inspired Today dates with expandable month selection; local Health and wellness tracking goal; simpler question screen with highlighted multiple symptoms and bounded aggregate context; icon-based flow choices; renewed record-card design. Preserve consent, 100-character questions, local calculations, future-date recording restrictions, deletion confirmations and accessible controls. No backend changes or automatic external calls. Multi-symptom payload compatibility will be covered by fixtures; live gateway acceptance remains open. Implemented with 37 focused unit/transport tests and four affected UI scenarios passing across targeted runs, plus Debug/test and final unsigned Release builds (28.9 seconds). Accessibility-container issues and a transient 101-character question-input bug were fixed; the native editor includes keyboard dismissal. See [DEVICE_FEEDBACK_ROUND_3.md](DEVICE_FEEDBACK_ROUND_3.md). Device/visual/accessibility, full-suite and live multi-symptom gateway acceptance remain open; nothing was committed or pushed.

## October 1 — second device-feedback pass implemented and focused validation complete

Authorized: one-decimal numeric presentation, horizontal record-scope choices, calmer loading copy, compact record components, in-memory Today wellness results with preference editing, deterministic Insights charts, collapsible measurement wheels with Metric/Imperial labels, and a static branded launch screen. Preserve full-precision stored facts, explicit request consent, cancellation/privacy invalidation, accessible touch targets and medical safety notices. No automatic external requests or persistent suggestion cache. Use bounded validation; record simulator blockers rather than repeatedly retrying. Warm red sexual-activity icons were also requested and implemented in calendar markers, the legend and logging/record screens. Final app/test compilation passed after removing an editor-inserted duplicate source block. All 17 focused unit tests passed; all three new UI scenarios passed across targeted runs after test-helper corrections. A fresh unsigned iOS Release build passed in 39.1 seconds. Physical-device/launch/accessibility and historical full-suite acceptance remain open; no live gateway calls, commits or pushes were made. See [DEVICE_FEEDBACK_ROUND_2.md](DEVICE_FEEDBACK_ROUND_2.md) for final results and remaining device checks.

## October 1 — visual refresh implemented; runtime acceptance blocked

On `testing/on-device-fixes`, the shared visual refresh is implemented: rounded Dynamic Type typography, light/dark semantic colors, consistent cards/forms/actions, and native Liquid Glass tabs on iOS 26+ with older-OS fallbacks. A fresh unsigned iOS Release build passed in 54.2 seconds. Simulator discovery succeeded, but boot health reported **Data Migration Failed** despite exit 0; focused tests were deliberately not launched and no recovery/retry loop was attempted. Prior temporary test logs were unavailable, so no fresh unit/UI pass is claimed. See [UI_REFRESH.md](UI_REFRESH.md) for evidence and the minimal remaining checks. Runtime/accessibility/device acceptance remains open. No application-code changes, commits or pushes were made during this validation continuation.

## October 1 — device-feedback refinements implemented

On `testing/on-device-fixes`, implemented wrapping activity/diet/allergy choices; concise truthful external-processing disclosure; calmer insight/symptom wording and result styling; a 100-character record-question limit; activity-specific calendar icons and a horizontally scrolling Today date strip; and separate optional gender/partner onboarding steps, editable in Profile. New profile answers stay local, excluded from AI context and predictions. Export requires profile consent, plus sexual-information consent for partner answers. Existing profiles decode without invented answers. Validation: 86 focused unit/storage/transport tests passed, all 11 affected UI scenarios passed across reruns, and the unsigned iOS Release build passed; see [DEVICE_FEEDBACK_VALIDATION.md](DEVICE_FEEDBACK_VALIDATION.md). No backend changes or live gateway calls. Historical full-suite, signed-device and distribution gates remain open.

## October 1 continuation — consolidated AI verification

Reviewed the existing implementation rather than restarting completed work. All five AI paths are present. A fresh combined run passed all 62 tests in eight focused unit/storage/transport suites and all four Phase 8 UI scenarios, using synthetic fixtures only. A fresh unsigned iOS Release build also passed. Results are recorded in [PHASE_8_VALIDATION.md](PHASE_8_VALIDATION.md). The AI plan now includes the actual file map and distinguishes historical proposals from implemented prototype choices. No live gateway requests, new backend resources, or resumption of the deferred full-app/device acceptance are part of this checkpoint.

## October 1 update — AI implementation authorized

The user authorized all five handoff features using the existing Azure gateway. All five iOS paths are implemented: typed networking and durable consent, confirmed symptom normalization, insight explanations, wellness, completed-cycle summaries and bounded questions. Focused evidence: 62 unit/storage/transport tests, four UI scenarios passed across reruns, and Debug/unsigned iOS Release builds; see PHASE_8_VALIDATION.md. No new backend, phase estimator or chat history. Validation and prototype release gates will be recorded in PHASE_8_VALIDATION.md. This supersedes the earlier wait-for-review instructions; historical baseline/device gates remain deferred, not waived.

## October 1 update — local prerequisites before AI

The user authorized implementation of missing local tracking/preferences before AI integration. Digestive-change symptom tracking and optional wellness profile preferences are implemented with passing focused validation (45 unit/storage tests, three UI flows verified across reruns, and Debug/unsigned Release builds); see [LOCAL_WELLNESS_PREREQUISITES.md](LOCAL_WELLNESS_PREREQUISITES.md). That local-only milestone is complete; the user subsequently authorized all AI features, as recorded above. Estimated phase remains deferred pending a defensible calculation policy; it is optional in the API. Existing regression/device gates remain open.

Native, privacy-first iOS menstrual cycle tracker.

Created: September 29, 2026

## Purpose and tracking

This document tracks the phased implementation plan derived from the product brief. It is a planning document, not authorization to implement all phases at once.

- Mark a task `[x]` only after its implementation and relevant validation are complete.
- Update the phase status and record decisions, blockers, and validation results below.
- Whenever work starts, changes scope, or is deferred, update this plan in the same change. Distinguish planning, implementation, validation, and deferral; never mark deferred work complete.
- Complete each phase's acceptance criteria before expanding scope.
- Optional integrations may be reordered or deferred based on product validation.

Current user-directed priority: **One-start cycle setup and transparent starter predictions implemented; focused validation complete.** See [CYCLE_SETUP_REFRESH.md](CYCLE_SETUP_REFRESH.md). This supersedes the former four-start onboarding gate and excludes only the entered typical cycle length from the former blanket “profile answers never affect predictions” rule. All other profile/context choices remain outside prediction calculations. Previous device-feedback work remains in place; historical full-suite/device and live gateway gates remain open.

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
| Pre-8 | Local tracking/preferences needed by AI | Implemented; 45 focused unit/storage tests, three UI flows across reruns, Debug and unsigned iOS Release builds passed. Manual/baseline gates remain open; see LOCAL_WELLNESS_PREREQUISITES.md |
| 8 | Optional AI enhancements | All five iOS paths implemented; 62 focused tests and four AI UI scenarios passed together, plus Debug and a fresh unsigned Release build. See PHASE_8_VALIDATION.md; live contract/prototype/device gates open |
| Post-8 | On-device feedback: UX, activity calendars and optional identity answers | Implemented; 86 focused tests, 11 UI scenarios across reruns, and unsigned Release passed. Physical-device follow-up remains open; see DEVICE_FEEDBACK_VALIDATION.md |
| Post-8 UI | Shared visual refresh and native Liquid Glass navigation | Implemented; fresh unsigned Release passed. Focused runtime tests blocked by simulator boot migration failure; visual/device acceptance remains open. See UI_REFRESH.md |
| Post-8 UX 2 | Charts, inline wellness, compact records, measurement controls, launch screen and red activity icons | Implemented; 17 focused unit tests and three new UI scenarios passed across targeted runs; Debug/test and unsigned Release builds passed. Device/full-suite gates remain open. See DEVICE_FEEDBACK_ROUND_2.md |
| Post-8 UX 3 | Weather-style expandable dates, local wellness goal, multiple-symptom questions, flow choices and renewed cards | Implemented; 37 focused unit/transport tests, four UI scenarios across targeted runs and Debug/unsigned Release passed. Live new-context and device gates remain open. See DEVICE_FEEDBACK_ROUND_3.md |
| 9A | Optional personal cloud synchronization | Deferred |
| 9B | Optional partner sharing | Deferred |

### Deferred regression and acceptance milestone — September 30, 2026

The user deferred the proposed regression-resolution/acceptance milestone to plan AI before cloud sync and partner sharing. No regression fixes or fresh baseline runs were performed as part of this deferral. Historical evidence in [PHASE_6_VALIDATION.md](PHASE_6_VALIDATION.md) remains: 113/114 unit tests and 19/30 full-suite UI tests passed; focused Phase 6 checks and Release build passed. This is not a passing full suite or release sign-off.

- [ ] Reproduce and resolve the protection-attribute unit failure and eleven UI regression failures; run a fresh full baseline and retain result bundles.
- [ ] Complete signed-device privacy, Apple identity, HealthKit, backup/deletion, offline and reminder acceptance.
- [ ] Complete minimum-OS and accessibility/layout acceptance and required privacy disclosures.
- [ ] Resume this milestone at an explicitly recorded checkpoint before release; no resume date has been agreed.

Existing acceptance checkboxes remain open. Deferral does not waive safety, privacy, testing or release requirements. The later October 1 authorization covers all five AI integrations, with explicit in-app consent before any health-data request. Regression/device acceptance is still deferred.

## Product and architecture guardrails

- Native iOS: Swift, SwiftUI, async/await, and preferred SwiftData persistence.
- New-user setup uses Sign in with Apple for identity; subsequent local tracking does not require a network connection. Existing users retain records and can link identity in Settings. No backend or health-data synchronization in the pre-6 milestone.
- Keep health records on-device by default; optional integrations require informed consent.
- Prefer native Apple frameworks and minimal dependencies.
- Dependency flow: views → feature state/view models → use cases/domain services → repositories → persistence and system integrations.
- Keep business logic out of views, predictions out of persistence models, and domain calculations independent of SwiftUI and SwiftData where practical.
- Derive cycles, statistics, predictions, and insights from raw observations rather than duplicating persisted calculations.
- Use deterministic software for facts. The October 1 AI handoff expands AI to natural-language symptom understanding, explanation, summarization, personalization, general wellness suggestions and bounded questions over locally derived facts; never replace local calculations or silently save AI output.
- Observe, do not diagnose. Never imply predictions are reliable contraception.
- Present uncertainty honestly and distinguish confirmed observations from predictions.
- No advertising SDKs or reproductive-health events sent to generic analytics providers.
- Keep basic prediction, privacy controls, deletion, and access to personal data available without a subscription.
- Build a calm, accessible interface, not an all-pink imitation of existing trackers.
- Do not preemptively build infrastructure for hypothetical cross-platform requirements.

### Authorized detour before Phase 6

See [Onboarding milestone](ONBOARDING_MILESTONE.md). The revised handoff requires four period starts, an editable local profile and Apple identity while retaining the existing prediction engine. The onboarding detour is implemented. Phase 6 read-only Health import is implemented; its outstanding acceptance is deferred and cloud sync remains deferred. Local records/profile and preferences are excluded from future system backups; earlier backups are not erased. Apple sign-in alone provides neither health-data backup nor cross-device recovery.

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

## Phase 8 — Integrate optional AI enhancements

**Goal:** Enhance tracking with the five tasks in the October 1 handoff while keeping local data/calculations authoritative and AI optional.

**Original-intent review — September 30, 2026:** Reviewed the initial plan at commit `5784dd8`, foundations and subsequent phase documents. The original proposal was a bounded, opt-in explanation/summary of deterministic findings, with minimized local context, a thin preferably stateless Azure Function relay, server-held OpenAI credentials, validated structured responses and offline-safe core tracking. It did not specify an exact model, AI screen, conversation history, prompts, context schema or AI pricing. No separate product-brief file was found in the workspace or initial commit. Recent GPT UX/model suggestions remain proposals, not original requirements or approved scope. Research is complete; requirements clarification is next. No app changes, API calls or tests were performed for this review.

**Status — October 1, 2026:** The user authorized all five integrations after local prerequisites. Networking, consent, confirmed normalization, explanations, wellness, summaries and bounded questions are implemented. [PHASE_8_VALIDATION.md](PHASE_8_VALIDATION.md) records focused evidence and unresolved contract/prototype/device checks. No backend resources or live requests were made.

### Supplied gateway — reuse, do not recreate

Function App: `cecyaiendpoints`. POST `https://cecyaiendpoints-gqdahecce6g7dufv.westus3-01.azurewebsites.net/api/ai`. Anonymous prototype; no function key/bearer token. The handoff reports stateless processing, validation, 14 backend tests and five deployment smoke-test passes; these were not independently verified here. Model selection, prompts, secrets and retries are server-owned. No new backend, Function App, Firebase, health-data cloud store, custom AI authentication, App Attest or DeviceCheck in this integration.

Rate limiting, quotas and attestation are absent. Treat the endpoint as prototype infrastructure; separately review abuse protection and Azure/OpenAI retention/logging before distribution. Do not mark those missing controls complete or implement them as unrelated iOS scope.

### Planning and review

- [x] Inspect current persistence, symptom taxonomy/ratings, atomic saves, profile fields, facts, UI and privacy lifecycle against the handoff.
- [x] Draft a concrete iOS-only integration plan; backend creation tasks superseded by reuse of the supplied endpoint, not newly implemented here.
- [x] User authorized all five AI features after local prerequisites; implement explicit review, note choice and consent/cancellation policies.
- [ ] Obtain authoritative wire fixtures/schema for constraints not specified in the handoff; confirm normalization limits/status behavior before coding and task-specific enums/facts before later slices.

### Implementation sequence — focused evidence in PHASE_8_VALIDATION.md; live/release gates remain open

- [x] 8.1: Typed five-task `AIService`, DTOs, errors, injected URLSession transport, bounded timeouts/payloads and mock-only automated tests.
- [x] 8.2: Backward-compatible protected AI consent, just-in-time disclosure/settings and cancellation/access-generation gates.
- [x] 8.3: `normalize_symptoms` end-to-end in existing logging: text → explicit request → editable suggestions → user-confirmed atomic `addSymptoms`; preserve manual fallback and optional original note. Later slices are also authorized by the subsequent user request.
- [x] 8.4: Minimal `AIContextBuilder` and on-demand `explain_insight` over existing deterministic evidence.
- [x] 8.5: Only necessary local wellness preferences and Today `daily_wellness_recommendation`; omit unsupported optional estimated phase.
- [x] 8.6: Deterministic completed-cycle facts and `cycle_summary`; no invented duration when end date is unknown.
- [x] 8.7: Bounded question intents/local evidence and `answer_cycle_question` in Insights; no full-history upload or persisted conversation.
- [ ] 8.8: Cross-feature acceptance and separately authorized synthetic manual gateway checks; record actual results in `PHASE_8_VALIDATION.md` when testing begins.

### Explicit adaptations / deferred additions

- Keep SwiftData V6 and repository interfaces; handoff references to Core Data mean local storage, not a migration back to template Core Data.
- First slice needs no new health entity/schema; existing symptom strings/notes and protected preferences suffice. A proposed digestive-change case extends the existing taxonomy, not a second one.
- Local wellness prerequisites are already implemented and validated. AI reuses those preferences; existing tracking goals are not assumed to equal API wellness goals.
- Estimated phase engine, persistent AI summaries/cache and conversation history are not part of the initial integration. Client output stays ephemeral except user-confirmed symptom records/notes.
- Gateway statelessness is not a guarantee of provider zero retention. Minimize context; identifiers/private notes/full history are not automatically sent. User-submitted description/question text itself is sensitive and requires disclosure.

### Completion criteria

- [ ] No request without valid consent and access; disable, background, lock, logout/reset and stale replies cannot expose results or modify data.
- [ ] No AI-proposed symptom persists without review and confirmation; failures/cancel never partially save.
- [ ] All five tasks use only relevant typed inputs; raw history/identifiers and private notes are excluded unless explicitly entered for the current consented request.
- [ ] Deterministic calculations remain authoritative; no AI prediction, diagnosis, silent fact changes or generic chatbot.
- [ ] AI responses are validated and safetyMessage rendered when present; severe symptoms with nil safetyMessage are handled safely without duplicating server prompts.
- [ ] Offline/error/manual fallback, protected preference compatibility, minimal context and each feature's lifecycle are tested.
- [ ] Provider/privacy/prototype hardening and outstanding baseline/device gates reviewed before release; supplied backend tests are not iOS sign-off.

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
| September 30, 2026 | 8 / acceptance | Defer regression resolution and acceptance; prioritize GPT feature planning | User-directed change on `planning/phase-8-gpt`. Existing failures/device gates remain open. Model/hosting and feature scope await agreement; cloud/sharing remain deferred and subscriptions last. |
| October 1, 2026 | 8 | Adopt deployed AI gateway handoff; draft iOS-only integration plan | Reuse `cecyaiendpoints`; SwiftData remains authoritative. Five bounded tasks, normalization first after plan review. No backend recreation or app implementation in this planning change. |

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

The user-authorized device-feedback changes on `testing/on-device-fixes` are implemented with focused validation; see DEVICE_FEEDBACK_VALIDATION.md. Next, recheck them on-device and address specific reported issues. Existing live gateway, provider/privacy, historical full-suite and signed-device gates remain open. No new backend, cloud sync, partner sharing or subscriptions are authorized by this UX milestone. Update this plan for each new task or deferral.


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
