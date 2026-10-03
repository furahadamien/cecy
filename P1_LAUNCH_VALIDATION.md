# P1 first-public-release implementation and validation

Assessment: October 3, 2026. Companion to [the product handoff](PRODUCT_READINESS_AND_ENGINEERING_HANDOFF.md), not release approval.

## Scope and provenance

- Base: `8e7c654e13b318a7ac92e0c7989467fa424506c0`; branch `engineering/p1-launch-readiness`, created before these edits. Results apply to that base plus the working-tree diff, not to a new committed release.
- The pre-existing edit to `.github/agents/Principal Sofware Engineer.agent.md` is unrelated and preserved.
- Scope is CE-01 through CE-07: evidence, records/predictions, existing AI/privacy, existing workflows, calendar accessibility, reliability, release reconciliation. These are launch-quality tasks. No P2/P3, new AI capabilities, prediction policy, data schema, backend, sync, sharing, subscription, analytics, or account changes.
- Evidence directory: `/tmp/cecy-p1.gQXvct`. Preserve its logs, command files and result bundles outside `/tmp` before release. Only synthetic records and mock AI/Apple/Health services are used. No live gateway requests, email sends, provisioning changes, uploads, or distribution validation.
- Environment: Xcode 27.0 build 27A266a; iPhone 16e Simulator, iOS 26.2 build 23C54, UDID `0FD63CC6-7E36-4D2B-8C56-EE58D5DC25E6`; Debug with signing disabled. Only this runtime/device is exercised unless separately recorded below. This does not cover the iOS 17 deployment floor or physical-device behavior.

## CE-01 — implementation map

**Architecture:** `cecyApp` creates `TrackerSession.live()` and `TrackerRootView`. Root gates protected preferences, app lock, signed-out identity, storage failure, onboarding, and the four native tabs. Views call session mutation methods; the session publishes fresh local calculations after committed repository writes. The active store is **SwiftData backed by Core Data**, schema V6, with explicit V1→V2→V3→V4→V5→V6 lightweight migrations. `SwiftDataPeriodRepository` disables autosave, validates candidates and rolls back failed saves. Production configuration uses `cloudKitDatabase: .none`, not synchronization. `Persistence.swift` and the timestamp-only Core Data template are not the active tracker store; template cleanup is limited to explicit reset.

Project: `cecy.xcodeproj`, one discovered scheme `cecy`, targets `cecy`, `cecyTests`, `cecyUITests`, Debug/Release configurations. File-system-synchronized app/test groups include the added Swift files without project edits. App/test builds establish inclusion; filenames alone do not establish passing tests. Deployment is iOS 17.0, device families iPhone/iPad; version 1.0/build 1, bundle ID `xyz.thabo.cecy`. Test/fixture compositions are `#if DEBUG` and use unique temporary stores, not production data. Release selects native Apple/Health services and `RemoteAIService`.

### Every Section 6 workflow

“Implemented” means the source path exists and is wired, not that every manual acceptance criterion passed. Unit coverage is exercised by the complete unit target. UI coverage listed here is an inventory; **only executed runs below establish fresh UI results**. Source paths are under `cecy/`; tests are under `cecyTests/` or `cecyUITests/`.

| Workflow | Implementation / source trace | Relevant tests and remaining boundary |
|---|---|---|
| First launch | Implemented: `cecyApp.swift` → `App/TrackerSession.swift:live/load` → `App/TrackerRootView.swift` | `TrackerPersistenceTests`, `cecyUITests`; physical clean/returning launch and minimum OS pending |
| Onboarding | Implemented: `Features/Onboarding/OnboardingFlowView.swift`, `HistoryEntryView.swift`, `TrackerSession.finishSetup` | `OnboardingTests`, `CycleSetupRefreshTests`, `OnboardingUITests`; staged completion is distinct from an arbitrary durable draft; native Apple authorization pending |
| Sign in with Apple | Implemented: `AppleSignInSection.swift`, `Services/AppleAccount.swift`, root signed-out gate | `OnboardingTests`, `UXImprovementsTests`; new setup requires Apple identity, returning local use is not a server account; review applicability remains open |
| Historical periods | Implemented: Calendar/Today dated callbacks → `PeriodLogSelection` → `PeriodEntryView` → repository | `HistoricalLoggingTests`, `HistoricalLoggingUITests`; selected-day routing and relaunch cases |
| Initial prediction | Implemented: session publication → `CycleCalculator`, prediction/forecast domain policies | `CycleDomainTests`, `CycleSetupRefreshTests`, `CycleForecastTests`, `AdaptiveForecastTests`; starter estimate uses entered typical length, not invented observations |
| Today/Home | Implemented: `Features/Today/TodayView.swift`, `Shared/CycleForecastView.swift` | Device-feedback, daily-insight and historical UI suites; explicit missing/reference/projection states |
| New period | Implemented: `Features/Logging/PeriodEntryView.swift`, `TrackerSession.save/withPredictionUpdate` | `TrackerPersistenceTests`, `PredictionUpdateProgressTests`, `cecyUITests`; save/rollback, cancellation and relaunch |
| Edit/delete history | Implemented: `PeriodRecordActions.swift`, session `update/delete`, repository | `PhaseTwoTests`, `HistoricalLoggingTests`, `PhaseTwoUITests`; identity-preserving correction, confirmation and recomputation |
| Symptoms | Implemented: `SymptomEntryView.swift`, session/repository symptom CRUD | `PhaseThreeTests`, `DeviceFeedbackTests`, `PhaseThreeUITests`; date/value/duplicate validation |
| Sexual activity | Implemented: `SexualActivityEntryView.swift`, dated local CRUD and markers | `SexualActivityTests`, `SexualActivityUITests`; explicit export inclusion, no automatic AI/support inclusion |
| Natural-language symptoms | Implemented client: `AISymptomEntryView.swift` → normalizer → editable review → explicit `addSymptoms` | `PhaseEightTests`, `AIServiceTests`, `PhaseEightUITests`; service output itself does not save observations |
| Calendar | Implemented: `TrackerCalendarView.swift`; selected-day list logging fixed here | `LaunchReadinessUITests`, calendar metric tests, existing grid/forecast suites; physical VoiceOver still pending |
| Insights | Implemented: `CycleHistoryView.swift`, `ObservationsView.swift`, statistics/charts, deterministic `CycleInsightEngine` | `PhaseThreeTests`, `PhaseFourTests`, device-feedback suites; conservative descriptive evidence, not clinical validation |
| AI explanations | Implemented client: `AIFeatureView(.insight)` → `AIContextBuilder.insight` → service; deterministic `PredictionExplanation` is separate | `PhaseEightTests`, `PhaseEightUITests`; local `InsightCard` now retained, generated prose explicitly labelled |
| Wellness | Implemented client: existing wellness entry → context prerequisites → AI; local severe-symptom notice | `WellnessPrerequisiteTests`, `PhaseEightTests`, AI UI suites; allergy/preference payloads are not proof that generated advice obeys them |
| Cycle summaries | Implemented client: `AIFeatureView(.summary)` → bounded summary context; sparse data uses question contract without guessing missing lengths | `PhaseEightTests`, `DeviceFeedbackRoundFourTests`, `PhaseEightUITests`; semantic correctness of live prose unverified |
| Cycle questions | Implemented client: prepared local answers plus bounded scope/question routes | `PhaseEightTests`, `DeviceFeedbackRoundThreeTests`, `DailyInsightsAndOvulationTests`, AI UI suites; not a broad chatbot |
| Profile information | Implemented: `ProfileSettingsView.swift`, `WellnessPreferencesView.swift`, repository JSON profile | Onboarding, wellness, device-feedback and setup-refresh suites; legacy optional fields remain unknown |
| Notifications | Implemented: `TrackerPrivacy`, `Services/ReminderService.swift`, local notifications | `PhaseFiveTests`, `PhaseFiveUITests`; injected denial/rescheduling/cancel coverage, actual delivery/lock-screen checks pending |
| Contact support | Implemented: `TrackerSettingsView` → `ContactSupportView.swift`; explicit native composer/mailto/copy | `ContactSupportTests`, `ContactSupportUITests`; recipient/generic subject only, no automatic attachments; delivery not verified |
| Network/AI failure | Implemented: `RemoteAIService`, `AIRequestCoordinator`, independent manual workflows | `AIServiceTests`, `PhaseEightTests`, `PhaseEightUITests`; mocks cover errors/timeouts/stale results, not production gateway availability |

Additional implemented controls: local lock/biometrics, explicit scoped export/reset, and reviewed read-only HealthKit import (`HealthImportReview`, `HealthImportSettingsView`). `PhaseFiveTests`, `PhaseSixTests` and their UI suites cover these; no advanced HealthKit or new integrations added.

### Reconciled document conflicts

- Older four-start setup requirements are superseded by `CYCLE_SETUP_REFRESH.md` and current one-start setup with entered typical lengths. Older blanket “profile never affects prediction” language excludes these explicitly entered lengths; no new medical inference is introduced.
- Older whole-window ovulation markings/context suppression are superseded by `OVULATION_FORECAST.md`, `ADAPTIVE_CYCLE_FORECAST.md` and current shared forecast details. Current/later projections already explain assumptions and uncertainty. The overview-only “How this estimate works” button is not the sole explanation.
- Historical “all calendar logging below dates” applies to grid presentation, not the accessibility-list correction here. Recorded-day logging now edits the existing period; disabled-existing-period assertions predate `HISTORICAL_LOGGING_FIX.md`.
- Prior AI plans are not proof of current backend behavior. All five iOS clients ship in source; server implementation, provider retention and safety evaluation remain outside this repository.
- Old full-suite counts/deferrals in `IMPLEMENTATION_PLAN.md` and phase validation documents remain historical, not evidence of this build passing. This checkpoint resumes in-scope P1 verification, not P2/P3 work.

## CE-02 — records and deterministic prediction

Existing complete unit target covers civil-day/month/year/leap/time-zone boundaries, model validation, transactional create/edit/delete, save failures, duplicate/overlap rejection, deterministic predictions, mutation refresh, outliers/context, missing history, and absence of inferred observation writes. Migration fixtures originate from V1 (`PhaseTwoTests`), V2 (`PhaseThreeTests`), V3 (`OnboardingTests`), V4 (`SexualActivityTests`), V5 (`PhaseSixTests`); V6 legacy profile payloads reopen in `WellnessPrerequisiteTests`.

Added `LaunchReadinessTests`:

1. Invalid SQLite bytes survive two failed loads without replacement, false success, or a writable empty fallback.
2. An unreadable file-backed profile payload fails closed across reopening/retry while healthy period rows and the invalid payload remain intact.
3. Signed-out reset honestly reports partial cleanup when Keychain removal fails after record deletion, keeps the identity gate, and completes on retry without false confirmation.

These passed in the reproduction run. No persistence or prediction implementation change was justified by these tests. Corrupt-file tests are **not** substitutes for every migration-failure or real signed-upgrade scenario. Physical timezone-change/upgrade checks remain open. Reset across SwiftData, Keychain and notification services is deliberately not represented as one atomic transaction.

## CE-03 — existing AI, wellness and privacy boundaries

### Outbound field-level map

All five operations POST `{task, context}` to the existing HTTPS Azure endpoint defined in `Services/AIService.swift`. `Domain/AIModels.swift` defines the exact wire fields; `Domain/AIContextBuilder.swift` bounds them:

| Operation | Context fields sent |
|---|---|
| `normalize_symptoms` | `text` (1–2,000 characters), deliberately user-entered. Identifying/health details typed here are transmitted; this is **not** automatic redaction. No automatic record-date/history attachment. |
| `explain_insight` | `insightType`; `facts`: `metric`, `units`, `evidence`, `caveat`; applicable `previousMetric`, `recentMetric`, `previousRecordCount`, `recentRecordCount`, `symptom`, `startsAnalyzed`, `matchingStarts`, `timingWindow` |
| `daily_wellness_recommendation` | optional `cycleDay`; `symptoms` (`type`, nullable `severity`); `activityLevel`, `preferredExercises`, `dietaryPreference`, `foodAllergies`, `userGoals`. No invented `estimatedPhase`. Explicit prerequisite answers required. |
| `cycle_summary` | `periodLabel`, `cycleLength`, `averageCycleLength`, `periodLength`, `commonSymptoms`, `observations` (locally constructed descriptive facts/caveats); incomplete measurements use the question contract instead |
| `answer_cycle_question` | `question` (1–100 characters); `facts`: `scope`, `caveat`, optional `cyclesAnalyzed`, `averageCycleLength`, `minimumCycleLength`, `maximumCycleLength`, `populationStandardDeviationDays`, `symptom`, `daysAnalyzed`, `recordedDays`, `matchingStarts`, `timingWindow`, `minimumRecordedOffsetDays`, `maximumRecordedOffsetDays`; optional multi-symptom list with symptom/count/window/offset fields. Daily preparation also uses this existing operation. |

Allowlisted computed contexts do not encode the snapshot, civil dates, record IDs, stored private notes, sexual-activity records, identity/measurement profile fields or HealthKit metadata. Aggregates remain health information. User-entered normalization text/allergy strings must not be described as anonymized. The endpoint also necessarily receives transport metadata; downstream logging/retention is unverified.

Consent: `AIConsentView` names Azure/OpenAI and selected text/facts/preferences, enables nothing remotely by itself, and offers decline. `TrackerPrivacy` persists versioned consent; revocation blocks requests immediately and reports a failed durable write. `TrackerSession.canUseAI` additionally gates lock, identity, onboarding, loading and saves. Daily automatic preparation is separately opt-in; its once-per-civil-day attempt is reserved durably before the request. Outputs and the wellness cache are session memory, not saved/exported; invalidation clears them. Confirmed symptom suggestions become ordinary local observations only after editable review and explicit save.

Transport: ephemeral session, no cache/cookies/credential store, no redirects, 32,768-byte request and 131,072-byte response limits; request/resource/coordinator deadlines 75 seconds. Manual requests have no automatic retry and coordinators reject overlapping/stale/cancelled results. The client does not carry an API secret or add account credentials. None of this proves server authentication, rate/abuse protection, token/cost limits or zero retention.

**Small fixes:** replace onboarding’s absolute cloud claim with accurate local-storage/consented-online-processing copy; retain the existing deterministic `InsightCard` on the explanation screen, independent of request state; label AI supporting prose as interpretation rather than verified records. Tests require the local text to survive decline, success and failure unchanged. No payload expansion or consent-policy change.

**Open release acceptance:** inspect authoritative gateway/provider configuration, field-level request handling/logging/retention/deletion, authentication/rate/abuse/token/cost controls, synthetic contract/evaluation results, qualified escalation wording, allergy/diet/exercise conflicts, severe symptoms, diagnosis and contraception/confirmed-ovulation cases. Current response validation checks structure, enums, bounds and required nullable safety fields; it does **not** prove semantic truth or enforce allergy exclusions in generated prose. Do not ship optional AI as safety-verified based only on mocks or disclaimers. No live cost-incurring tests were authorized/performed.

## CE-04/05 — workflow and calendar changes

**Reproduction:** largest-text calendar, synthetic September 2026, select September 1. In `calendar-reproduction-and-units.xcresult`, logging bottom was at y≈10,140.7 while September 2 began at y≈647.7. The first attempted UI helper overscrolled; that failed attempt is retained separately and not counted as a layout reproduction.

**Required behavior / scope:** place exactly one existing logging-actions group immediately after the selected date, before details/the remaining days, in list layout. Grid placement remains below the grid/before the legend. Existing callback date, edit route, symptom/activity sheets and future-day guards remain unchanged. Complexity: small view change plus targeted UI regressions; privacy/storage/network impact: none.

**Acceptance/tests:** `LaunchReadinessUITests` checks early-month largest-text ordering, one action group, 44-point period target, cancel without a period record, selection surviving sheet dismissal, month navigation preserving day 29, and all future actions disabled before the next date. Existing compact grid tests cover placement, dimensions, sheet routes, recorded-period edit and future restrictions. Existing current/later/context forecast UI tests cover already-shared explanations. No duplicate forecast explanation or model change is added. Physical VoiceOver/narrow-device traversal still needs execution.

Existing compact-control tests incorrectly used a 24-point glyph-height limit on accessibility frames that measure the full 44-point button. They now verify text containment and retain target/width/placement checks. This is not pixel-level proof of single-line rendering; physical visual verification remains open.

## CE-06 — execution register and remaining runtime checks

Every test run uses unique synthetic stores. Logs and result bundles retain failed as well as successful attempts. Build/test command files identify exact selections; absence from a selected run is not a pass.

| Evidence basename under `/tmp/cecy-p1.gQXvct` | Observed result |
|---|---|
| `baseline-units` | App and both test targets compiled. Swift Testing reported 263 tests, 49 suites; one protection test failed with four missing-attribute assertions. Only that run’s optional simulator diagnostic collector was stopped after tests finished; result finalized with exit 65. |
| `reproduction` | Three new corruption/reset tests passed; protection probe confirmed the Simulator omits `.protectionKey` entirely. Two old compact UI assertions failed at 44 vs 24 points; first list tests hit helper overscrolling, not the target assertion. |
| `calendar-reproduction-and-units` | All unit suites passed after splitting device-only protection checks (267 tests reported; one explicitly skipped). Corrected early-month test reproduced the layout defect. Future test still had an unrelated long-distance scroll problem; it was changed to assert the date preserved by month navigation. |
| Subsequent regression/release runs | In progress; record final results before closing this checkpoint. |

`PhaseFivePrivacyTests.completeProtectionCoversExportsStoresAndSidecars` is explicitly disabled on Simulator, not silently passed: on a physical device it requires complete-protection attributes on export/file directories, SQLite store/WAL/SHM and a nested file. Portable export-content, backup-exclusion and scoped/idempotent-cleanup checks still execute on Simulator. This test does not replace a locked-device access test.

Still open: physical-device VoiceOver, software/hardware keyboard, Reduced Motion, measured light/dark contrast and complete essential target coverage; current and deployment-floor device/OS matrix; real Apple authorization and HealthKit permissions; actual offline/airplane-mode workflows; app-switcher/locked-device/export cleanup; Instruments and the handoff’s proposed p95 ≤250 ms across 30 warmed calendar interactions with ten years of dense synthetic history. No speculative performance rewrite, target waiver, or full UI-suite pass is claimed.

## CE-07 — Section 13 release checklist

Apple guidance consulted October 3, 2026: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) (page dated June 8, 2026), especially 1.4, 2.1, 5.1.1 and 5.1.2; [required-reason API declarations](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api). This is an engineering audit, not compliance certification.

| Checklist row | Evidence / disposition |
|---|---|
| App icon | `Assets.xcassets/AppIcon.appiconset/Contents.json` has slots without filenames. Approved release artwork is needed; not fixed by successful compilation. |
| Display name | Bundle/product currently `cecy`, in-app branding Cecy. Installed/store branding approval still required. |
| Screenshots | No approved App Store set verified. Capture shipped UI with synthetic data at required sizes after final UI changes. |
| Description | No approved store description verified. Must describe free local-first tracking, estimates and optional external AI accurately. |
| Keywords | App Store Connect values not accessible/verified. |
| Privacy policy | No public policy URL/in-app policy link found. Owner-approved hosted HTTPS policy must cover actual app/gateway/provider/support practices and be linked in-app and in metadata. Do not invent a URL or retention promise. |
| Support URL | In-app email support exists; public account-free support webpage not found/verified. |
| Support email | `support@thabo.xyz` is wired; tests do not prove mailbox monitoring or delivery. Real request/response route pending. |
| App Privacy | Blocked on authoritative provider/gateway/support data handling and App Store Connect reconciliation. Local-first does not mean “data not collected.” |
| Health disclosures | Local estimate/uncertainty/not-contraception copy exists; clinical/predictive validity not established. Qualified wording review pending. |
| AI disclosures | Named processors and explicit consent exist; onboarding overclaim corrected here. Provider policies/retention/public policy and live safety review still pending. |
| Age rating | Actual content, questions, audience and regional obligations require owner/App Store Connect review. |
| Sign in with Apple | Existing identity gate inspected, not added. New setup requires it despite local-only records. Justification under 5.1.1(v), native service and reviewer access need owner review. |
| Account deletion | Local reset and local Keychain-link removal exist. They are not represented as Apple-account deletion or server-side token revocation. Current Apple authorization/deletion applicability must be resolved before submission. |
| Privacy manifests | No manifest found. Focused app-source audit found no direct UserDefaults, uptime, file-timestamp/disk-capacity or active-keyboard use requiring a declared reason. Directory/protection setters and URLSession are not by themselves required-reason APIs. Do not fabricate reasons or claim an empty collection policy; verify the final archive/privacy report and any future SDK additions. |
| Permissions | Face ID and read-only menstrual-flow HealthKit purpose strings exist; entitlements include Apple sign-in, HealthKit, complete data protection. No HealthKit write permission is added. Native denial/delivery/device evidence pending. |
| Release configuration | iOS 17+, iPhone/iPad, version 1.0/build 1; existing HTTPS endpoint; test composition restricted to Debug. Unsigned archive result recorded below when available; signed validation/provisioning remains a separate gate. |
| Review access | Explain Apple setup/local returning use, optional consent, prerequisite wellness answers, no cloud restore, free scope and live AI limitations accurately. Do not present Debug fixture flags as production reviewer access. |
| Metadata | Categories/rating/URLs/screenshots/reviewer notes and legal/submission ownership unverified. |

## Checkpoint decision

Only evidence-backed, in-repository P1 fixes are implemented. External safety/policy/asset, physical-device and signed-distribution gates remain open, not waived or reclassified as P2/P3. CE-03, CE-06 and CE-07 cannot be accepted solely from this repository/test session. Before release, preserve artifacts, complete the outstanding checks and obtain release-owner acceptance.
