# Release readiness validation — October 3, 2026

**Decision: NOT RELEASE-READY.** Full automated validation completed, but required workflow/accessibility acceptance has failures and privacy, AI safety, native-service and distribution gates remain unresolved. Successful compilation and mock AI responses are not launch sign-off.

This documentation-only review continues the existing P1 work. It supersedes earlier targeted-run results only as evidence of the current **complete** suite; it does not erase earlier failures or passes. Acceptance reference: [PRODUCT_READINESS_AND_ENGINEERING_HANDOFF.md](PRODUCT_READINESS_AND_ENGINEERING_HANDOFF.md), read in full. Implementation/data-flow map: [P1_LAUNCH_VALIDATION.md](P1_LAUNCH_VALIDATION.md). Historical execution: [P1_LAUNCH_RESULTS.md](P1_LAUNCH_RESULTS.md) and [P1_RESUMPTION_RESULTS.md](P1_RESUMPTION_RESULTS.md).

## 1. Scope, provenance and reproducibility

- Repository: `/Users/furahadamien/Dev/cecy`; branch `engineering/p1-launch-readiness`; HEAD `8e7c654e13b318a7ac92e0c7989467fa424506c0` **plus the pre-existing dirty working tree**, not a committed release candidate.
- Preserved all existing app/test edits, untracked P1 reports/tests, and the unrelated `.github/agents/Principal Sofware Engineer.agent.md` edit. No app/test/configuration changes, new features, assertion weakening, commits, pushes, deployments or submissions in this review. This report is the only new workspace file.
- Resumed the already-running full-suite process rather than launching duplicate tests. Waited for its natural completion, then built a fresh unsigned Release archive using separate derived data. No failed test was rerun or relabelled as passing.
- Environment: macOS 27.0.1; Xcode 27.0 (27A266a); iPhone 16e Simulator, iOS 26.2 (23C54), arm64; English/en_US. Fixture clock is September 29, 2026, deliberately distinct from the review date.
- Debug suite: scheme `cecy`, both test targets, serial execution, signing disabled, per-test default/maximum allowances 300/360 seconds, diagnostic collection disabled. No test-selection restriction. Exact invocation: `full-suite.command.json` below.
- Release archive: scheme `cecy`, Release, generic iOS destination, `CODE_SIGNING_ALLOWED=NO`, fresh `ReleaseDerivedData`, archive `cecy-unsigned.xcarchive`; exact invocation is retained at the beginning of `release-archive.log`.
- Available simulator runtimes inventoried: iOS 26.2 and 27.0. Only 26.2 was executed; neither iOS 17 deployment-floor nor iOS 27 runtime acceptance is established. iPad remains unexecuted.
- Device inventory reported a paired physical iPhone on iOS 26.7.1. No installation, signing, native authorization, health-data access or tests were performed on that device. Device availability is not physical acceptance; use an explicitly authorized, isolated synthetic-data device before doing so.
- Only synthetic records and existing service/authentication fixtures were exercised. No live AI requests, real Apple authorization, email sends, network isolation changes, provisioning changes or App Store Connect edits.

### Evidence directory

**`/tmp/cecy-release-review-20261003`** contains:

| Artifact | Purpose |
|---|---|
| `full-suite.command.json`, `.log`, `.status`, `.xcresult` | Complete invocation, interaction log, exit code and authoritative results/attachments |
| `full-suite.summary.json`, `full-suite.tests.json`, `ui-results.json` | Machine-readable totals, test tree and all 71 UI outcomes/durations |
| `release-archive.log`, `.status`, `.xcresult`, `cecy-unsigned.xcarchive` | Fresh unsigned Release build evidence |
| `release-artifact-inspection.json` | Actual archived bundle metadata and string/manifest inspection |
| `baseline-status.txt`, `baseline-tracked.diff`, `final-tracked.diff` | Dirty-tree provenance; tracked diffs compare byte-for-byte unchanged |
| `reviewed-source-fingerprints.json`, `test-source-inventory.json` | Source/configuration fingerprints and test inventory |
| `available-devices.json`, `xcdevices.json`, `runtimes.txt` | Local destination inventory, not device-test results |

Preserve these artifacts outside temporary storage before any release decision. Device inventories contain local identifiers; do not publish them indiscriminately. Earlier targeted evidence remains in `/tmp/cecy-p1.gQXvct` and is not counted again here.

## 2. Executed results

| Validation | Status | Result |
|---|---|---|
| Complete unit target | **PASS**, simulator scope | 267 declared tests across 50 Swift Testing suites: **266 passed, 0 failed, 1 skipped**; runner reported 8.333 seconds |
| Complete UI target | **FAIL** | **71 tests: 56 passed, 15 failed, 0 skipped**; 3018.732 seconds of test execution |
| Combined full run | **FAIL** | **338 tests: 322 passed, 15 failed, 1 skipped**; exit **65**; approximately 51.5 minutes elapsed; finalized at 13:06:58 local time |
| Fresh unsigned Release archive | **PASS**, build only | Exit **0**, `ARCHIVE SUCCEEDED`; not a signed archive, install, distribution validation or App Review approval |
| Source preservation | **PASS** | Final tracked diff equals pre-run tracked diff; `git diff --check` passed |

Use the result summary's **top-level** totals. Its per-device pass count is 330 because six parameterized test declarations produce fourteen invocations, adding eight case executions; this is not eight additional declared tests or extra UI coverage.

Skipped: `PhaseFivePrivacyTests.completeProtectionCoversExportsStoresAndSidecars`, explicitly unavailable on Simulator because iOS file-protection attributes are not exposed there. Portable export/backup/cleanup assertions still ran. This skip does not waive complete protection or locked-device testing.

Four runtime warnings were recorded: **“Invalid frame dimension (negative or non-finite).”** They occurred in three passing symptom-description AI scenarios (cancellation/background, consent/save/revoke, network-failure/manual fallback) and the passing wellness save/relaunch/clear scenario. Their source/root cause and visible impact remain unverified; capture layout stacks in focused reproduction rather than treating a passing assertion as absence of warnings. Expected corrupt-store errors in the integrity fixtures are not production data-loss findings.

### Complete UI suite inventory

| Suite | Passed | Failed |
|---|---:|---:|
| ContactSupportUITests | 1 | 0 |
| DailyInsightsAndOvulationUITests | 4 | 1 |
| DeviceFeedbackRoundFiveUITests | 7 | 0 |
| DeviceFeedbackRoundFourUITests | 2 | 1 |
| DeviceFeedbackRoundThreeUITests | 2 | 1 |
| DeviceFeedbackRoundTwoUITests | 3 | 0 |
| DeviceFeedbackUITests | 3 | 1 |
| HistoricalLoggingUITests | 3 | 0 |
| LaunchReadinessUITests | 2 | 0 |
| OnboardingUITests | 3 | 2 |
| PhaseEightUITests | 5 | 0 |
| PhaseFiveUITests | 3 | 3 |
| PhaseFourUITests | 2 | 0 |
| PhaseSixUITests | 3 | 0 |
| PhaseThreeUITests | 1 | 2 |
| PhaseTwoUITests | 3 | 0 |
| SexualActivityUITests | 1 | 2 |
| VisualRefreshUITests | 2 | 0 |
| WellnessPrerequisiteUITests | 3 | 0 |
| cecyUITests | 3 | 2 |
| **Total** | **56** | **15** |

### Every failed test and next diagnostic

All locations below are under `cecyUITests/`. **FAIL describes the executed acceptance test, not proof of fifteen independent product defects.** No baseline full-suite comparison was executed to assign introduction/regression ownership. Test fixtures and exact interactions remain in the named source methods and result bundle.

| ID | Test / location | Observed failure and impact on acceptance | Next action; source-supported triage, not a claimed fix |
|---|---|---|---|
| UI-01 | `DailyInsightsAndOvulationUITests.testOvulationMarkerMatchesAcrossCalendars`; helper line 23 | Selected September 16; “Possible ovulation · Estimate” was not hittable after bounded scrolling. Marker checks passed before detail check. | Inspect selected-detail versus upcoming-card query scope and viewport. `ProjectedCycleDetails` still renders this title; do not conclude ovulation calculation is missing. Require visible uncertainty detail after selection. |
| UI-02 | `DeviceFeedbackRoundFourUITests.testTodayLoggingStaysBelowPredictionAndCalendarKeepsMarkers`; line 69 | Expected Symptoms below Period: y=213.667 was below the required minimum 257.667. | `TrackerCompactLogActions` intentionally uses a horizontal row when it fits and stacks at accessibility sizes. Reconcile this older unconditional vertical assertion with approved compact layout; retain hit-target, ordering and routing checks. |
| UI-03 | `DeviceFeedbackRoundThreeUITests.testFlowChipsSaveAndHealthGoalPersists`; line 83 | Period sheet did not dismiss after selecting Heavy and tapping Save. Goal persistence assertions were not reached. | `PeriodEntryView` disables Save until New period/Add bleeding days is chosen when continuation exists; this test does not choose. Inspect enabled state/fixture and exercise the intended explicit choice before flow/relaunch acceptance. Do not bypass the guard. |
| UI-04 | `DeviceFeedbackUITests.testTodayStripCentersBrowsesAndMatchesMonthActivities`; line 49 | October 1 strip element not found after one swipe. Later activity save/calendar comparisons not reached. | Capture horizontal viewport/lazy-cell state, use bounded date navigation, and retain cross-calendar persistence checks. Not evidence of lost activity records. |
| UI-05 | `OnboardingUITests.testLogoutCancelRelaunchAndSameAccountReconnect`; unknown source line, in `OnboardingUITestSupport.swift` | `confirmLogout` query matched nested buttons in one alert; tap could not be resolved. | Result hierarchy shows nested identical identifiers and an Alert/Sheet automation mismatch. Scope the native control unambiguously, then require durable logout and same-account reconnect. Native Apple behavior remains separate. |
| UI-06 | `OnboardingUITests.testMeasurementWheelsAreOptionalClearableAndConvertUnits`; `OnboardingUITestSupport.swift:247` | One picker wheel remained instead of zero after clearing height. | Inspect collapse animation/state and confirm visible clearing, not just immediate tree count. Keep optionality, conversion and persistence requirements. |
| UI-07 | `PhaseFiveUITests.testReminderChoicesPersistAndResetDisablesThem`; line 163 | Wait for saved daily reminder label “On” timed out (waiter result 2 vs 1). Relaunch/reset checks not reached. | Inspect actual switch state, native thumb hit location, save result and injected delivery state. Require durable saved value and reset reconciliation; no native-delivery claim. |
| UI-08 | `PhaseFiveUITests.testSettingsRemainAccessibleAtLargestTextSize`; helper line 25 | Could not reveal `predictionSettings`. Failure hierarchy was already on **Privacy and export**, not root Settings. | Investigate navigation/scroll interaction and target viewport before declaring a missing row. Repeat all essential largest-text settings actions and physical VoiceOver traversal. |
| UI-09 | `PhaseFiveUITests.testSettingsSummaryAndDetailNavigation`; line 74 | “Internal prototype” static text not found after About navigation attempt. | Confirm destination and label exposure. Separately, the fresh Release executable **does contain** prototype copy; this test failure is not evidence that release copy was removed. |
| UI-10 | `PhaseThreeUITests.testCalendarRatingsMarkerAndReset`; helper line 29 | `symptomRating_energyLevel` Button not found before rating selection; save/reset not reached. | Hierarchy shows Energy selected, form at its top, date below viewport; helper waits for rating existence before scrolling. Inspect lazy form materialization/type and preserve rating/save/relaunch/reset assertions. |
| UI-11 | `PhaseThreeUITests.testTodayObservationDuplicateEditCancelDeleteAndRelaunch`; helper line 29 | `symptomRating_headache` Button not found before first save; later CRUD/duplicate checks not reached. | Same pre-scroll existence boundary as UI-10; require actual rated symptom CRUD and duplicate protection, not merely chip selection. |
| UI-12 | `SexualActivityUITests.testCalendarRecordsPastDayAndDoesNotOfferFutureLogging`; line 91 | Expected future `logSexualActivity` to be absent, but it exists. | Current calendar intentionally presents disabled future logging with explanation; new largest-text future-disabled tests pass. Verify disabled/routing semantics instead of treating existence as permission to write. |
| UI-13 | `SexualActivityUITests.testMultipleActivitiesPersistCanBeEditedCancelledAndDeleted`; unresolved tap | No “Discard changes” button after Cancel; hierarchy had returned to activity history. | Inspect whether the edit actually changed the draft and confirmation semantics before cancellation. Later deletion acceptance not completed; prior targeted passes do not override this result. |
| UI-14 | `cecyUITests.testHistoryPredictionCalendarAndDuplicateProtection`; line 85 | Expected Today window label to contain “Sep 28”; fails before calendar/duplicate checks. | `PredictionSummary` displays the remaining window using `max(today, earliest)`; fixture today is September 29. Reconcile original domain window versus remaining UI window and then execute duplicate-protection steps. |
| UI-15 | `cecyUITests.testLargeTextCalendarList`; helper line 33 | Could not reveal old sentence “End not recorded. No later bleeding days are assumed.” | Current `PeriodRecordSummary` uses “End not recorded” badge; inspect actual selected record/copy and list position. Keep explicit unknown-end semantics and large-text reachability checks. |

These are bounded diagnostic recommendations, not permission for broad UI redesign, model changes or weaker behavioral assertions. Focused fixes/rechecks and another full run are still required.

## 3. P0 and selected P1 disposition

Status vocabulary: **PASS** = evidenced for the stated scope; **FAIL** = observed unmet assertion/requirement; **PARTIAL** = some evidence but acceptance incomplete; **NOT TESTABLE** = evidence unavailable or execution requires external access/authorization. A source path existing is not end-to-end acceptance.

The original handoff asserted **zero confirmed P0 defects**. This review does not retroactively change that historical assessment. It now confirms a concrete submission obstacle: **no accessible in-app privacy-policy link** in the reviewed app. Release prototype copy and missing icon are also evidenced submission-readiness defects. The icon remains the explicitly deferred asset task, **not a waived public-release requirement**. UI failures and unknown server behavior are not automatically promoted to P0 safety/data-loss defects.

| Handoff task | Status | Evidence / remaining acceptance |
|---|---|---|
| CE-01 — implementation evidence | **PASS**, repository scope | Existing workflow/data-flow map rechecked against entry/root/session, active SwiftData repository/schema, forecast domain, AI client/models/consent, settings/auth/support, project and tests; external deployment gaps explicit below |
| CE-02 — local records/predictions | **PARTIAL** | All units, migration/failure-preservation fixtures, historical logging, period edit/delete/reset/relaunch pass. Rated-symptom/activity/duplicate UI matrix has failures; real upgrade/timezone/locked-store checks open |
| CE-03 — AI/wellness/privacy | **PARTIAL** | Five client operations and consent/write boundaries traced; all five AI UI cases pass. Server/provider retention, deployed contracts, semantic/allergy safety, operational controls and qualified escalation review not verified; policy access missing |
| CE-04 — core completion | **FAIL** | Clean setup/new period/relaunch and period reset now pass in full run; other required workflow acceptance remains red (UI-03–15 as applicable) |
| CE-05 — calendar uncertainty/accessibility | **PARTIAL** | Both selected-day largest-text placement/future-guard regressions and grid identity pass; current/later/context markers largely pass. Ovulation detail and legacy large-text record-detail test fail; physical traversal open |
| CE-06 — runtime/accessibility | **FAIL** | Complete suite executed, not passing; four layout warnings. Physical protection/VoiceOver, offline device, supported OS/device matrix, full contrast/targets/keyboard and dense-history performance remain open |
| CE-07 — assets/disclosures/release | **FAIL** | Fresh unsigned archive passes; missing in-app policy link/icon and prototype copy confirmed. Public policy/support, Apple obligations, final metadata/privacy and signed distribution unaccepted |

CE-08–11 and subscriptions, sync, partner sharing, Android/web, custom backend accounts, analytics expansion and advanced HealthKit remain outside this launch-validation task. Their absence is not a defect.

## 4. Workflow acceptance map

Paths are relative to `cecy/`; test suite names resolve under the two test directories. PASS rows are limited to specified local/simulator behavior; shared device/remote gates in sections 6–7 still apply.

| Workflow | Status | Implementation and executed evidence / limitation |
|---|---|---|
| First launch | **PARTIAL** | `cecyApp` → `TrackerSession.live/load` → `TrackerRootView`; isolated clean/returning simulator launches pass, corrupt-store fail-closed units pass. Signed clean device/minimum OS not exercised |
| Onboarding | **PARTIAL** | `OnboardingFlowView`, `finishSetup`, `prepareOnboarding/completeOnboarding`; clean setup/log/relaunch, draft interruption, profile and Apple-cancel cases pass; measurement UI-06 fails |
| Sign in with Apple/logout | **PARTIAL** | `AppleSignInSection`, `AppleAccount`, signed-out root gate; zero requested name/email scopes, local Keychain identity in production. Fixtures bypass Apple; logout UI-05 fails; native auth/revocation and submission applicability unresolved |
| Historical periods | **PASS**, simulator scenarios | `HistoryEntryView`, `PeriodLogSelection`, session/repository; all three HistoricalLogging UI cases pass including continuation and preserving earlier records/upcoming projections |
| Initial/sparse prediction | **PASS**, computational scope | `CycleCalculator`, `BaselinePredictionEngine`, `EvidencePredictionEngine`; zero/one/variable history and profile-reference units pass; one-start/chart and sparse-replay UI pass; no clinical accuracy claim |
| Today/Home | **PARTIAL** | `TodayView`, `PredictionSummary`, `ActivityCalendarStrip`; core Day 1/relaunch passes; strip/layout/window assumptions UI-02/04/14 fail |
| New period | **PARTIAL** | `PeriodEntryView` explicit New period/Add bleeding days and session mutation; clean new-period save survives two launches (93.869 seconds). Flow UI-03 and full duplicate UI-14 remain incomplete |
| Period edit/delete/reset | **PASS**, simulator scenarios | All three PhaseTwo UI tests pass, including discarded edit, confirmed deletion/recalculation and typed reset returning durably to onboarding; transactional failure units pass |
| Manual symptoms/ratings | **PARTIAL** | `SymptomEntryView`, atomic batch and repository CRUD; units and digestive-symptom relaunch pass; rated CRUD UI-10/11 fail before save |
| Sexual activity | **PARTIAL** | `SexualActivityEntryView`, local CRUD/export guards and markers; all domain/persistence units and largest-text choices/export-default UI pass; UI-12/13 fail |
| Natural-language symptoms | **PASS**, mocked client boundary | `AISymptomEntryView` → normalizer → editable review → explicit confirmed batch save; consent/save/relaunch/revoke and failure/manual fallback pass. This does not validate live extraction accuracy |
| Calendar | **PARTIAL** | `TrackerCalendarView`; all leading offsets grid identity, compact controls and new contextual largest-text guards pass; UI-01/15 remain red; VoiceOver unexecuted |
| Ovulation/fertility | **PARTIAL** | `PossibleOvulation`, `ProjectedCycleDetails`; bleeding/fertile distinction, future projections and context warning UI pass, detail visibility UI-01 fails; medical/safety wording review open |
| Insights | **PASS**, local evidence scope | `CycleHistoryView`, `CycleStatisticsView`, `ObservationsView`, `CycleInsightEngine`; chart/scope, supporting evidence and reconstructed prediction-history UI and deterministic units pass |
| AI explanations | **PASS**, mocked presentation boundary | `AIFeatureView(.insight)` retains the local InsightCard; exact local text survives declined consent, success and failure. Generated prose remains separate and is not semantic truth-validated |
| Wellness recommendations | **PARTIAL** | Prerequisite/context units, severe-symptom notice, mocked generation and preference save/relaunch/clear UI pass; allergy/diet/exercise compliance and concerning-symptom live safety unverified |
| Cycle summaries | **PARTIAL** | `AIContextBuilder` complete-cycle facts and sparse fallback; mock summary UI and privacy-bound units pass; deployed semantic fidelity unverified |
| Cycle questions | **PARTIAL** | Prepared local answers, bounded scoped context, capped question input and mock UI pass; deployed diagnosis/contraception/confirmed-ovulation response boundaries unverified |
| Profile/settings | **PARTIAL** | `ProfileSettingsView`, `WellnessPreferencesView`, file-backed profile; profile identity, measurements, preferences and appearance persistence cases pass; UI-06/08/09 fail |
| Notifications | **PARTIAL** | `ReminderService`, `TrackerPrivacy`, local planner; denial/rescheduling units pass and generic body contains no health details; UI-07 fails before durable save acceptance; actual permission/delivery/lock screen untested |
| Contact support | **PARTIAL** | `ContactSupportView` is session-independent; recipient + generic subject only; support unit/UI pass. Native Mail/send/monitoring and public support URL not verified |
| Network/AI failure | **PASS**, injected client cases | `RemoteAIService`, `AIRequestCoordinator`; malformed/missing nullable safety fields, timeout/offline, rate/server errors, cancel/stale responses and manual fallback tested. No live gateway or real airplane-mode acceptance |
| Export | **PARTIAL** | Explicit JSON share, independent notes/profile/activity opt-ins; unit allowlists and share cancellation pass; physical protection and external-destination handling not exercised |
| Deletion/privacy | **PARTIAL** | Typed reset/local identity/consent/reminder/export cleanup and partial-failure units pass; no claim of secure erasure, external-copy removal or Apple token revocation; missing policy link is a separate FAIL |
| Apple Health (existing optional import) | **PARTIAL** | `HealthImportReview`, `HealthKitService`, reviewed-start/receipt persistence; all three fixture UI cases and migration/conflict units pass. No native permission/read/write execution; production is read-only |
| Empty/error/loading states | **PARTIAL** | Sparse/no estimate, unavailable/empty Health, persistence startup failure and AI terminal states have unit/UI evidence; complete native error/permission/accessibility matrix not executed |
| Long-term behavior | **PARTIAL** | Six-interval model, bounded projections and a 3650-day time jump unit pass. This is not a dense ten-year history UI benchmark, longitudinal accuracy study or actual supported upgrade |

### Deterministic facts and persistence findings

The active tracker store is **SwiftData backed by Core Data**, schema V6, with five lightweight transitions V1→V2→V3→V4→V5→V6. `Persistence.swift` is an inactive timestamp-template store, not the production tracker path. Active configuration disables CloudKit. Repository autosave is disabled; writes validate candidate snapshots and roll back on failure. Session publication recalculates overview/forecast/statistics/insights after committed mutations and invalidates stale AI.

Constructed migration fixtures **exist and passed**: `v1StoreMigratesInPlace`, `v2MigrationPreservesMetadataAndSkippedOnboarding`, `v3MigrationPreservesLegacyHistoryAndOnboarding`, `v4MigrationPreservesAllExistingRecords`, `v5MigrationAndReopenPreserveEveryRecordAndReceipt`. `LaunchReadinessTests` verifies corrupt bytes survive startup/retry, unreadable profile payload does not erase healthy records, and signed-out partial reset reports accurately and retries. These are not signed old-app→new-app upgrade tests.

Predictions use up to six recent measured intervals, median center, shortest/longest plus padding, and withhold history-based windows above the supported spread; entered usual length supplies a clearly labelled starter/reference fallback, not recorded history. Evidence-based confidence remains provisional rather than a calibrated probability. Confirmed end dates refine bleeding duration; unknown ends do not infer bleeding. Ovulation uses a calendar offset and illustrative uncertainty, with a six-day estimated fertile window and specific context cautions. Later periods remain display-only assumptions and do not create records. Units establish reproducibility/invariants, **not clinical predictive validity**.

## 5. AI, wellness and privacy acceptance

| Requirement | Status | Evidence and remaining boundary |
|---|---|---|
| Consent before dispatch, revocation and daily opt-in | **PASS**, client scope | Versioned consent must persist; revoke fails closed for the session if persistence fails; daily preparation is separate and reserves one local civil-day attempt before dispatch. Granting consent itself sends nothing |
| Field-level minimization | **PASS**, inspected typed client | `AIModels`/`AIContextBuilder` and request tests; details below. Free text and aggregates are health information, not anonymized |
| Reviewed extraction only; no silent facts | **PASS**, client scope | Service/coordinator do not write repository records. Editable symptom review and explicit save are required; batch conflict/rollback units and consent/save UI pass |
| Deterministic explanation provenance | **PASS**, local presentation | Local InsightCard remains unchanged through decline/success/failure; AI interpretation is distinguished |
| Transport/recovery | **PASS**, tested client boundaries | HTTPS, ephemeral session, no cookies/cache/credential store, redirects refused, 32768-byte requests/131072-byte responses, 75-second configured deadlines, no automatic manual-request retry; mock terminal/stale/cancel tests pass |
| Gateway/provider contracts, retention and operational controls | **NOT TESTABLE** in this review | No authoritative deployed configuration, logging/retention/deletion, rate/abuse/token/cost evidence or authorized live test. Hardcoded public HTTPS endpoint/no client secret is not itself a demonstrated vulnerability |
| Wellness safety/personalization | **PARTIAL** | Explicit allergy/activity/diet/exercise/goal prerequisites, unknown ≠ no allergies, severe-symptom notice and typed context tested. Response validation checks shape/bounds, not reliable allergen exclusion or medical appropriateness |
| Semantic safety of all shipped AI prose | **NOT TESTABLE** in this review | Require authorized synthetic evaluations for fabricated facts, severe symptoms, diagnosis, contraceptive assurance and confirmed-ovulation inference, plus qualified escalation review. Disclaimers and nullable safety messages alone do not establish safety |
| Accurate privacy policy/access | **FAIL** | Consent identifies Azure/OpenAI, but no accessible in-app public policy link is implemented; actual downstream policies have not been reconciled |

Five existing operations are wired; no new operation or backend was added:

- `normalize_symptoms`: only user-entered `text` (up to 2000 characters); date/history not automatically attached. Text may itself contain identifying or sensitive information.
- `explain_insight`: `insightType` and allowlisted local metric/units/evidence/caveat and applicable comparison/timing/count facts.
- `daily_wellness_recommendation`: optional cycle day, current symptom type/severity, activity level, exercises, dietary preference, allergies and goals. No supported measured phase is invented.
- `cycle_summary`: period label, available cycle/average/period lengths, common symptoms and local observations; missing measurements use the existing bounded question route.
- `answer_cycle_question`: bounded question and scoped count/length/variability/symptom/timing facts. See the prior field-level map for every typed optional field; current `AIModels.swift` remains the wire definition.

Computed contexts exclude raw snapshots, civil dates, record IDs, stored private notes, sexual-activity records, Apple identity and HealthKit identifiers. The remote endpoint receives transport metadata and user text; downstream retention is unknown. Outputs/caches are session memory; reviewed, confirmed symptoms become ordinary local records. Support does not receive a session or automatic attachments. Export explicitly warns that JSON is not encrypted and external copies leave Cecy's control. Reset explains backup/export/Health/Apple authorization limitations rather than promising complete external deletion.

## 6. Runtime, manual and accessibility verification

**Manual app/device journeys performed: none.** This review inspected source, automation logs/hierarchies, archive metadata/strings and current public Apple guidance. It did not manually operate the device/simulator UI, inspect screenshot pixels, run VoiceOver, send email or make live AI requests. Automated screenshots/attachments, where present, are evidence artifacts, not a completed visual/contrast review.

| Requirement | Status | Evidence / next required execution |
|---|---|---|
| Saved data after relaunch / cancel / rollback | **PARTIAL** | Multiple period/profile/preference/AI-confirmed symptom journeys and all integrity units pass; rated symptom/activity matrix still red |
| Actual supported upgrades and timezone changes | **NOT TESTABLE** without isolated device/upgrade setup | Constructed migrations/date/DST/clock-travel fixtures pass; execute authorized signed upgrade and device timezone/lifecycle checks |
| Core tracking in airplane mode | **PARTIAL** | Local repository/calculation and injected unavailable services are independent of AI; real network-isolated journey not run. First setup's existing Apple requirement needs explicit offline/launch-positioning decision |
| AI loading, cancellation, timeout and stale work | **PASS**, injected client scope | Coordinator watchdog uses shortened test deadline; HTTP timeout/offline injected. Not a measured live 75-second end-to-end outage |
| Dynamic Type / essential controls | **PARTIAL** | Several largest-text cases pass; settings UI-08 and calendar UI-15 fail. Minimum through maximum sizes and all forms still need acceptance |
| VoiceOver | **NOT TESTABLE** in executed evidence | Calendar has date/status labels, selected traits, contextual actions and accessible-list adaptation; announcements/error focus exist. These do not replace physical traversal/interpretation |
| Contrast, grayscale, rendered targets | **PARTIAL** | Non-color marker distinctions and selected 44-point runtime checks exist. Complete light/dark 4.5:1 normal/3:1 large/control measurements and actual full hit regions not measured |
| Reduced Motion / keyboard | **PARTIAL** | Native UI adaptation and keyboard-aware reset test evidence exist; physical reduced-motion, software/hardware keyboard and all focus paths unexecuted |
| Protected files / locked storage / app switcher | **PARTIAL** | Complete-protection requests, backup exclusion, scoped cleanup and lock fixtures verified; one device-only protection test skipped; locked-device reads/app-switcher privacy unverified |
| Ten-year dense history performance | **NOT TESTABLE** from current evidence | The 3650-day projection test bounds forecast count, not dense data or latency. Still measure p95 calendar response over 30 warmed interactions against the proposed ≤250 ms device target, or obtain an evidence-based approved replacement |
| Crash/layout/runtime quality | **PARTIAL** | Full suite completed without a reported crash failure; fifteen assertion/interaction failures and four invalid-frame warnings remain. No crash-free/stress claim |

## 7. App Store / release checklist (handoff section 13)

Fresh archive inspection: bundle `xyz.thabo.cecy`, name `cecy`, version 1.0/build 1, minimum iOS 17.0, iPhone/iPad, SDK `iphoneos27.0`. Face ID and read-only HealthKit purpose strings are present. Source entitlements request Apple sign-in, HealthKit and complete protection. No embedded provisioning profile; unsigned archive does not establish signed entitlements.

No tested Debug-fixture marker strings were found in the Release executable; fixture composition is also guarded by `#if DEBUG`. This is bounded source/string evidence, not exhaustive security verification. **“Internal prototype”, “Use synthetic records for now.” and “optional prototype service” are present in the fresh Release binary.** No compiled `CFBundleIcons` or `PrivacyInfo.xcprivacy` was found. Source AppIcon slots have no filenames.

| Checklist item | Status | Evidence / next action |
|---|---|---|
| App icon | **FAIL — known deferred asset** | Empty source slots/no compiled icon. Supply approved release artwork before public submission; no artwork added here |
| Display name | **PARTIAL** | Actual bundle `cecy`, in-app Cecy; approve installed/listed branding |
| Screenshots | **NOT TESTABLE** | No approved App Store set reviewed; automation images are not approved metadata. Capture final shipped UI with synthetic data at required sizes |
| Description | **NOT TESTABLE** | No approved store text reviewed; align free/local-first/AI/estimate claims |
| Keywords | **NOT TESTABLE** | App Store Connect not inspected |
| Privacy policy | **FAIL** | No implemented accessible in-app policy link; public owner-approved HTTPS policy/metadata still needed. Do not invent URL or retention terms |
| Support URL | **NOT TESTABLE** | Email route exists; no approved public account-free support page verified |
| Support email | **PARTIAL** | `support@thabo.xyz`, generic subject, no automatic payload; monitoring/send/reply not exercised |
| App Privacy | **NOT TESTABLE** | Need app/SDK/gateway/provider/support reconciliation and actual App Store Connect answers |
| Health disclosures | **PARTIAL** | Recorded/inferred separation and non-contraception/unconfirmed-ovulation cautions in source/tests; qualified review and final marketing claims unaccepted |
| AI disclosures | **PARTIAL** | Explicit processors/consent and corrected onboarding copy; deployed retention/safety/public policy still unverified |
| Age rating | **NOT TESTABLE** | Review actual audience, health/AI content and regional obligations in App Store Connect |
| Sign in with Apple | **PARTIAL** | Native path exists, fixture path is Debug-only. Required local-only signup must be reconciled with guideline 5.1.1(v); no native test or approval evidence |
| Account deletion | **PARTIAL** | Durable local reset exists; explicitly does not revoke Apple's authorization. Resolve applicable token-revocation/account obligations; Keychain removal is not token revocation |
| Privacy manifests | **PARTIAL** | None in source/archive; focused app-source search found no direct covered UserDefaults/uptime/file-timestamp/disk-capacity/active-keyboard use. No third-party package references found. Final API/SDK/archive privacy audit still required; do not fabricate declarations |
| Permissions | **PARTIAL** | Accurate Face ID/read-only Health purpose strings and native wrappers; real denial/recovery/delivery unexecuted |
| Release configuration | **PARTIAL** | Fresh unsigned Release build and bounded fixture exclusion pass; endpoint ownership/deployed behavior, signed provisioning/device/distribution validation open; prototype copy is an additional **FAIL** for submission completeness |
| Review access | **NOT TESTABLE** | Prepare accurate native Apple setup, local-use/AI consent/prerequisite instructions; Debug flags are not reviewer access |
| Metadata | **NOT TESTABLE** | Categories, free price, rating, URLs, legal submission entity, screenshots and reviewer notes not audited |

Public guidance retrieved October 3, 2026: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) (page dated June 8, 2026), especially 2.1/2.2 completeness/prototype, 5.1.1(i) in-app policy, 5.1.1(v) account sign-in/deletion, 5.1.2 third-party AI permission; [account deletion guidance](https://developer.apple.com/support/offering-account-deletion-in-your-app/) including Sign in with Apple token revocation; [required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api). This is an engineering assessment, not legal or App Review certification.

## 8. Launch Definition of Done — every requirement

| # | Requirement | Status | Disposition |
|---|---|---|---|
| 1 | Reproducible Release build for supported targets | **PARTIAL** | Fresh generic iOS unsigned archive passes; signed/supported-device release acceptance open |
| 2 | Essential setup/logging/correction/history/calendar journeys pass | **FAIL** | Fifteen UI failures; several fail before their later acceptance steps |
| 3 | Saved data survives relaunch and supported upgrades | **PARTIAL** | Relaunch and constructed migration fixtures pass; actual upgrade and incomplete CRUD matrix remain |
| 4 | Reproducible forecasts separate from records | **PASS**, deterministic implementation scope | Unit invariants, explicit display-only projections and committed-mutation publication verified; not clinical validation |
| 5 | No unsupported confirmed-ovulation/contraceptive assurance | **PARTIAL** | Local copy/markers are cautious; shipped live generated prose and qualified safety review not verified |
| 6 | AI cannot silently save observations or alter deterministic facts | **PASS**, client architecture scope | Explicit reviewed save, no coordinator repository writes, immutable local calculation inputs/provenance, passing client tests |
| 7 | Remote processing/retention/consent match disclosures | **PARTIAL** | Client field map/consent tested; authoritative downstream evidence absent and public policy link missing |
| 8 | Offline core and AI-failure usability | **PARTIAL** | Injected failures/manual fallback pass; actual airplane-mode/native auth boundaries unexecuted |
| 9 | Essential large-text and VoiceOver journeys | **FAIL** | Largest-text settings/calendar tests fail; VoiceOver not performed |
| 10 | Support/privacy URLs work and metadata matches build | **FAIL** | Missing in-app policy link, no approved URLs/metadata audit; actual Release still contains prototype copy |
| 11 | Confirmed P0 defects closed and regression-tested | **FAIL** | Concrete privacy-policy submission obstacle remains; original handoff's empty P0 list is not present-day sign-off |
| 12 | Remaining P1 fixed or explicitly decided with user-impact rationale | **FAIL** | No release-owner disposition closing the listed failures or required external/device gates |

## 9. Required next actions

1. **Engineering:** triage UI-01–15 using retained hierarchies and actual current UX. Correct stale/ambiguous automation only where demonstrated; keep real save/relaunch/duplicate/cancel/uncertainty assertions. Fix any reproduced app defect at the smallest scope. Capture invalid-frame warning stacks. Re-run affected scenarios and the complete suite; preserve failures as well as passes.
2. **Release/product/privacy owners:** supply approved public policy/support content and monitored route, implement accessible policy navigation, reconcile prototype wording with the actually accepted release, and complete artwork/metadata. The app-icon task remains deferred in this review, not waived for launch.
3. **Gateway/privacy/safety owners:** provide authoritative deployed contracts, processor data handling/retention/deletion, access/rate/abuse/token/cost controls, and authorize synthetic live contract/safety evaluations. Validate allergy/preference/severity and factual boundaries or explicitly withhold unverified optional AI surfaces through an approved scoped change. Do not add subscriptions/accounts/backend infrastructure by assumption.
4. **Authentication/release owner:** resolve mandatory Apple setup and deletion/token-revocation applicability under current guidance. Validate native success/cancel/revocation/offline behavior on an isolated authorized device; do not embed a secret or replace authentication speculatively.
5. **Device QA:** complete deployment-floor/current iPhone/iPad matrix, physical file protection and locked access, signed upgrades/timezone changes, real offline flows, notifications/Health/Mail, VoiceOver, full Dynamic Type/contrast/targets/keyboard/Reduced Motion and dense-history performance.
6. **Release owner:** preserve artifacts durably, review the exact dirty-tree changes into a reproducible candidate, obtain signed distribution validation, and explicitly resolve every required FAIL/PARTIAL/NOT TESTABLE item before sign-off.

**Final disposition:** verification is complete for this tool-accessible review; release acceptance is not. No claim of a fully passing suite, absence of production defects, live AI safety, signed distribution readiness or App Store readiness is made.
