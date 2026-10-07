# Cecy — Irregular-Cycle Support Implementation Plan

**Date:** October 7, 2026
**Status:** Phases 1–4 and Phase 5 local insights/summary implemented. Phase 6 automated validation performed; release acceptance remains open. Clinical guidance and broader context policy remain gated. See [implementation results](IRREGULAR_CYCLE_IMPLEMENTATION_RESULTS.md).
**Source baseline inspected:** `dc32512` — `Merge pull request #30 from furahadamien/ui/clear-reminder-details`. Working tree was clean before adding this document.

## 1. Objective and scope

Make Cecy useful when users cannot recall their last period, do not know their usual cycle length, or experience unpredictable bleeding. Recording, understanding variation, and preparing for care must remain useful even when a date cannot responsibly be estimated.

This is an additive, phased change—not a forecast-engine rewrite. Preserve the existing regular-cycle experience, historical records, local-first architecture, and native service boundaries. No plan can guarantee zero regressions; the safeguards and release gates below are required to detect and contain them.

**The original plan was documentation only.** Subsequent implementation and validation are recorded in the linked results. The source map below describes the original baseline; historical reports do not prove a later candidate passes.

### Initial delivery

- Explicit unknown answers during onboarding, without fabricated defaults or dates.
- Consistent handling of forecast uncertainty across existing surfaces.
- Daily bleeding/spotting observations and explicit recording coverage.
- Descriptive variation insights, appropriate check-ins, and a user-controlled appointment summary.

### Deliberately outside the initial delivery

- Changing Apple sign-in requirements, name/DOB requirements, account switching, or the user registry.
- Changing the median-window mathematics or introducing clinical definitions of irregularity.
- Diagnosis, automated PCOS detection, confirmed ovulation, or contraceptive guidance.
- Biomarker-based fertility prediction, automatic episode reconstruction, and probabilistic approximate-date algorithms.
- Cloud sync, subscriptions, analytics SDKs, new backend infrastructure, or automatic HealthKit writes.
- Automatic transmission of new health/context fields to AI.

## 2. Verified implementation map

Paths below are relative to the repository root. Recheck them against HEAD when implementation begins.

| Area | Current source and behavior | Implementation implications |
|---|---|---|
| Composition and routing | `cecy/cecyApp.swift`, `cecy/App/TrackerRootView.swift`, `cecy/App/TrackerSession.swift` | Preserve privacy/account gates, foreground cancellation, tab navigation, and isolated Debug fixtures. |
| Profile and setup | `cecy/Domain/UserProfile.swift`: `LocalProfile`, `OnboardingDraft.validate`; `cecy/Domain/CycleSetupPolicy.swift`; `cecy/Features/Onboarding/OnboardingFlowView.swift`; `cecy/Features/Onboarding/ProfileFields.swift` | Length properties are optional, but setup requires lengths and at least one start. Draft construction and view initialization supply 28/5. Every default/validation/resume path must be addressed together. |
| Final setup commit | `cecy/App/TrackerSession.swift`: `finishSetup`; `cecy/Data/SwiftDataPeriodRepository.swift`: `prepareOnboarding`, `completeOnboarding` | UI-only optionality is insufficient. Repository completion independently requires both lengths and a period. Preserve staged saving, identity matching, retries, and completion-last behavior. |
| Predictability | `cecy/Domain/UserProfile.swift`: `CyclePredictability`; `cecy/Features/Onboarding/ProfileFields.swift`; `cecy/Domain/PrivacyData.swift` | Values are `usually`, `sometimes`, `rarely`, `notSure`. Currently selected in UI/exported, not used as prediction evidence. Profile saves do trigger session republication; this does not make the predictability preference measured evidence. |
| Periods and primary forecast | `cecy/Domain/CycleAnalysis.swift`: `Period`, `PeriodValidation`, `BaselinePredictionEngine`, `TrackerSnapshot`, `PeriodRepository`; `cecy/Domain/PredictionEvaluation.swift` | Last-six interval median; primary window withheld when spread exceeds 14 days. Entered length supplies a starter only without measured intervals. Confidence/replay has separate evidence rules. |
| Display projections and phases | `cecy/Domain/PossibleOvulation.swift`: `CycleForecast.calculate`; `cecy/Domain/CyclePhases.swift`: `CyclePhaseTimeline` | Display forecast can use an explicitly labelled usual-length reference when primary history is unsuitable. Projections never create records or roll the primary reminder forward. Preserve this distinction while improving eligibility. |
| UI consumers | `cecy/Features/Today/TodayView.swift`, `cecy/Features/Today/CyclePhaseRingView.swift`, `cecy/Features/Calendar/TrackerCalendarView.swift`, `cecy/Shared/CycleForecastView.swift`, `cecy/Shared/ActivityCalendarStrip.swift`, `cecy/Shared/ExpandableMonthCalendar.swift` | Audit all independent labels, markers, countdowns, next-date selections, and detail explanations—not only the main card. |
| Historical logging | `cecy/Domain/PeriodLogSelection.swift`; `cecy/Features/Logging/PeriodEntryView.swift`; `cecy/Features/Logging/PeriodRecordActions.swift`; `cecy/Features/Today/DailyLogCard.swift`; `cecy/Shared/RecordedDayCard.swift` | Preserve explicit new-period versus continuation/edit routing. The current under-30-day continuation suggestion is a UI heuristic, not a clinical rule; do not silently extend or repurpose it. |
| Persistence | `cecy/Data/SwiftDataPeriodRepository.swift`; `cecy/Data/TrackerSchemaV2.swift` through `TrackerSchemaV6.swift` | Active schema V6; V1 definition lives in the repository file. `TrackerMigrationPlan` lives in V2. Explicit saves, candidate validation, autosave disabled, and rollback already exist. Profile uses a Codable payload in V4. |
| Recalculation | `cecy/App/TrackerSession.swift`: `mutate`, `publish`, `withPredictionUpdate`, `deleteAllAndWait` | Publish only committed changes; update activity index, forecasts, statistics, and insights; invalidate stale AI. Preserve reset/save exclusion and cancellation semantics. |
| Statistics and insights | `cecy/Domain/CycleStatistics.swift`, `CycleInsights.swift`, `InsightChartData.swift`, `PreparedRecordAnswers.swift`; `cecy/Features/Insights/` | Reuse recorded facts and missing-log caveats. Do not turn typical lengths or daily observations into extra cycle intervals. |
| Reminders | `cecy/Domain/PrivacyData.swift`: `ReminderPlanner`; `cecy/App/TrackerPrivacy.swift`: `trackingChanged`; `cecy/Services/ReminderService.swift`; `cecy/Shared/ReminderSetupFields.swift` | Daily reminder and one primary-window reminder. Preserve explicit opt-in, scheduling/DST rules, discreet defaults, and optional detail text. |
| Export/privacy | `cecy/Domain/PrivacyData.swift`: `TrackerExport`; `cecy/Features/Settings/PrivacySettingsView.swift`; `cecy/Services/ProtectedFiles.swift` | Existing JSON format versions and independent notes/profile/sexual-information choices must remain meaningful. No restore implementation is implied. |
| Apple Health | `cecy/Domain/HealthImport.swift`; `cecy/App/HealthImportReview.swift`; `cecy/Services/HealthKitService.swift`; repository `importHealthStart` | Reviewed start-only imports with source receipts and deduplication. Do not infer daily coverage or an end from imported samples. |
| AI | `cecy/Domain/AIContextBuilder.swift`, `AIModels.swift`, `AIRequestValidation.swift`; `cecy/App/AIRequestCoordinator.swift`, `TrackerPrivacy.swift`; `cecy/Services/AIService.swift` | Five existing operations, catalog/consent v2, allowlisted aggregates, editable symptom review, and persisted `reserveDailyInsightAttempt`. Preserve contracts, cancellation, timeouts, and no automatic repeat after edits. |

## 3. Non-negotiable compatibility rules

1. **Existing data stays intact.** Preserve UUIDs, dates, optional ends, notes, flow, symptoms, sexual activity, profiles, onboarding completion, and import receipts. No reset/reinstall requirement.
2. **Legacy values keep their meaning.** An existing 28-day cycle or 5-day period cannot be identified as a default versus a deliberate choice from its value. Preserve it; do not convert it to unknown or prompt every existing user again.
3. **Unknown is not zero, today, or a default.** Unanswered setup, explicitly unknown, and a known value are distinct states.
4. **No record is not confirmed absence.** A symptom-only day does not establish that bleeding was absent. An unknown period end is not continuous bleeding or a confirmed one-day duration.
5. **Preserve civil-date and write constraints.** Reuse `LocalDay`; prevent future factual entries, duplicate starts, and overlapping episodes. Profile input bounds are not medical thresholds and must not become new limits on genuine historical records.
6. **Preserve computation for eligible existing histories.** Center/window/confidence/backtest calculations remain unchanged in this initiative. Any eligibility change must have an explicit acceptance test and release note.
7. **One committed mutation, one consistent snapshot.** Coupled episode/daily changes save atomically. Failures retain the previous store and retryable draft, without publishing false success.
8. **No identity or privacy redesign.** Preserve Apple/registry sequencing, lock, backup exclusion, export cleanup, logout versus reset, and durable deletion behavior.
9. **AI remains optional.** New local fields do not enter requests automatically. No extra request because a profile or daily record changed; existing daily reservation survives edits, failures, and relaunch.
10. **UI improvements preserve accessibility.** Keep contextual selected-date actions, future-disabled logging, large-text lists, VoiceOver labels, record/estimate distinctions, and native navigation.

## 4. Product decisions to close before the affected phase

These decisions do not block baseline testing or architecture characterization. They do block shipping their respective behavior.

| Decision | Recommended initial scope | Approval/evidence |
|---|---|---|
| Self-reported predictability | Reuse existing values; improve labels and explain purpose. Keep reported pattern, observed variation, and forecast confidence separate. | Product wording review. Do not map “rarely” directly to a diagnosis or a permanent ban on forecasts. |
| Unknown setup answers | Allow explicit unknown last start, usual cycle length, and bleeding duration. Keep Apple, name, and DOB requirements unchanged. | Approved empty-state and completion journeys. |
| Approximate dates | Defer initially. Offer unknown instead of asking users to invent an exact date. | Separate design later for date precision and exclusion from exact calculations; no arbitrary midpoint stored as fact. |
| Typical-length reference with unsuitable history | Keep an optional educational reference to the entered length, but do not let it restore a dated forecast when shared policy withholds one. | Approve the intentional change from today's labelled dated-reference fallback. |
| Fertility/phase eligibility | Withhold personalized dates/phase assignments when evidence or context is unsuitable; retain general education and recorded bleeding. | Written policy matrix and qualified health-content review. Irregularity alone is not a diagnosis. |
| Daily answer semantics | One explicit daily state: bleeding, spotting, no bleeding, or unsure; no row means unrecorded. Optional flow only when meaningful. | Confirm whether mixed spotting/bleeding requires another representation before fixing the schema. |
| Episode/day conflicts | Explicit review, never silent merging, overwriting, or double-counting. Recommended rules in section 6. | Product and engineering approve conflict/edit/delete cases before data migration. |
| Care guidance and report | Deterministic, user-selected summary; clinician-reviewed static guidance available offline. | Qualified review before publishing thresholds/escalation instructions. No generated text required for safety. |
| New AI context | Defer new bleeding/coverage/context fields from outbound requests. | Separate backend-contract, privacy, and consent decision if later requested. |

## 5. Forecast and onboarding design

### 5.1 Shared eligibility without replacing the engine

Introduce a small pure domain policy, provisionally `ForecastAvailabilityPolicy` in `cecy/Domain/`. Its result should explicitly separate:

- Recorded facts and counts.
- Dated period-estimate availability and reason.
- Entered-length reference and its source.
- Eligibility for expected bleeding, ovulation/fertile markers, and personalized phase.
- Eligibility of the primary period-window reminder.

Suggested reason categories: no confirmed start, unknown length with insufficient intervals, variable history, unsuitable context, and invalid/unavailable calculation. Final type names are implementation details; reason semantics are not.

| Evidence case | Intended behavior |
|---|---|
| No period starts, with or without profile lengths | Logging and descriptive history work; no manufactured date, cycle day, or phase. |
| One confirmed start, unknown usual cycle | Show the recorded start and elapsed time; no dated period prediction. |
| One confirmed start with a usable entered length | Preserve the existing Low-confidence starter when approved policy allows it. Not measured-history evidence or proof of ovulation. |
| Usable measured intervals, unknown profile lengths | Continue calculating from measured intervals. Missing profile assumptions must not unnecessarily disable an evidence-supported estimate. |
| History withheld for variation | Explain why. A saved usual length may remain a reference, not an alternate dated prediction or reminder anchor. |
| Known cycle estimate, unknown bleeding duration | Period timing may remain available; do not invent bleeding days or force a phase ring. |
| Unsuitable physiological context | Apply the approved context policy to the relevant inferred output; do not hide real records or assume all contexts affect all outputs identically. |

Calculate the policy once with the committed snapshot in `TrackerSession.publish`; consumers render it rather than rediscovering fallback rules. Introduce the policy first in parity mode, then enable only approved behavior changes with tests.

Keep mathematical replay separate from operational display eligibility. Existing replay reconstructs estimates from current corrected records, not saved historical forecasts. Do not retroactively claim today's context was known in the past. Context epochs and context-aware evaluation are deferred.

Daily reminders stay independent of forecast availability. A period-window reminder uses only an eligible primary estimate; display projections must not roll it forward. Reconcile stale notifications after committed relevant changes, never from an unsaved draft.

### 5.2 Setup states and backward-compatible profile decoding

Use existing optional values plus minimal explicit answer/provenance metadata if needed. Keep one authoritative value per field. Missing metadata on an old payload means legacy/unspecified provenance, not a rejected answer or forced reset.

Update together:

- `OnboardingDraft` initialization and validation.
- `OnboardingFlowView` initial 28/5 assignment, per-step guards, review, and resumed setup.
- Cycle/period controls and `ProfileSettingsView` so unknown values are not silently reseeded on edit.
- Repository `prepareOnboarding` and `completeOnboarding` validation.
- `TrackerSession.finishSetup` stages and completed zero-period routing.

An explicit unknown answer counts as answered for the approved new setup flow; it must not create a `Period`. Draft retries remain idempotent, and onboarding completion is still committed last after the matching Apple identity is securely linked.

Existing completed profiles remain completed. Interrupted legacy setup retains its existing draft values and can resume safely. No universal re-onboarding or new identity requirement is introduced.

## 6. Daily bleeding model, persistence, and reconciliation

### 6.1 Proposed minimum model

Add a separate daily observation value/entity rather than coercing bleeding into `SymptomKind` or redefining existing `Period` rows. Candidate fields: stable ID, `LocalDay`, explicit daily state, optional daily flow, optional episode ID, and created/updated timestamps. Add provenance only for actual known sources; do not claim inferred confirmation.

For the first version, recording coverage comes from an explicit daily answer. Do not add another independently writable “complete day” flag, and do not infer coverage from opening the app or logging a symptom. UI distinguishes explicit unsure from a day with no answer.

Existing period episodes remain the sole source of start-to-start intervals. A daily observation does not independently start a cycle. Creating/updating an episode from daily observations is an explicit reviewed operation, not background inference.

Store the episode association in one place. Avoid contradictory relationships or implicit cascading deletion. Validate linkage and uniqueness in the repository; follow existing validation conventions rather than relying on UI guards alone.

### 6.2 Recommended conflict rules

| Action or conflict | Rule |
|---|---|
| Daily bleeding/spotting without a known episode | Save standalone; no automatic period start. |
| Repeated save for one day | Explicit edit/update, or a conflict requiring review; never duplicate or silently merge independent inputs. |
| New period versus continuation | Preserve existing routes and ID stability; offer uncertain daily logging without forcing an episode interpretation. |
| No-bleeding/spotting conflicts with an explicitly recorded bleeding range | Explain the conflict and offer an explicit episode correction or cancellation. Retain the draft; do not silently overwrite either fact or publish an inconsistent result. |
| Episode boundary edit affects linked daily rows | Preview/review affected associations; commit the approved reconciliation atomically. Do not generate daily rows for the new range. |
| Delete one episode | Recommended default: retain daily observations as standalone and unlink them, disclosed in confirmation. Deleting both requires explicit scope confirmation. |
| Delete one daily observation | Do not silently change an episode start/end or delete symptoms/activity from that day. |
| Existing episode flow versus daily flow | Retain episode-level flow as recorded. Do not spread it across days or silently rewrite it from a daily value. |
| Imported period start | Preserve receipt/sample deduplication and its recorded acceptance provenance. Local corrections must not rewrite the source receipt or create HealthKit writes. |
| Delete all data | Include all new records/metadata in the existing coordinated local reset and privacy cleanup. Preserve documented external-copy/Apple/registry limitations. |

An interruption or failed save must leave neither orphaned links nor a half-created period. Reuse the repository's explicit candidate-validation/save/rollback pattern. The mutation gate must cover the complete operation. Derived state, reminder reconciliation, and AI invalidation follow successful commit only.

### 6.3 Migration strategy

1. Profile-only optional metadata may fit the existing Codable payload without a SwiftData version change; verify decoding of old fixtures and do not bump the store version unnecessarily.
2. A new daily observation entity requires a new schema version, provisionally V7. Do not alter historical schema definitions in place; extend the migration plan and production/in-memory factories intentionally.
3. Prefer a demonstrably safe additive migration. Do not label it lightweight until tests prove the actual model transition works.
4. Old periods migrate unchanged. Never generate daily bleeding, no-bleeding, or coverage rows from an old date range, profile length, or Health sample.
5. Validate supported V1–V6 upgrade paths and final reopen behavior, not just a fresh V7 store. Preserve IDs, relationships, notes, profile payloads, onboarding state, and receipts.
6. Failed opens/migrations preserve the original store and show a recoverable error. Never delete or replace a failed store with an empty one.

## 7. Insights, summary, reminders, and AI boundaries

- Reuse existing statistics/charts to show observed interval variation, known episode durations, and sample sizes. Add daily bleeding/spotting counts and explicit recording coverage separately; distinguish confirmed episode duration from counts of daily observations.
- Keep an open interval open. Long gaps can reflect missing records; offer “Any bleeding since your last record?” with yes/no/not-sure rather than asserting a missed period. A single answer must not automatically backfill a range of daily negatives.
- Support calendar-time and recorded-start-relative symptoms without assigning unsupported hormonal phases. Pinning preferred symptoms and optional functional impact can follow the core recording work; do not enlarge the initial schema for unapproved fields.
- Provide an on-device appointment-summary preview and native sharing. Include only user-selected facts/context, with dates, sample sizes, unknowns, and coverage limitations. Omit identity, private notes, and sexual information unless explicitly selected under the relevant export choices.
- Preserve existing JSON formats for existing content. Assign a documented new format version when including new data; never silently omit new records while labelling an export complete. Database version and export version are separate. Do not promise re-import/restore.
- Keep check-ins opt-in and discreet. Reuse existing reminder controls before adding new schedules. Snooze/pause or episode follow-up alerts are later refinements with separate notification reconciliation tests.
- Do not pass the new model wholesale to AI. Existing contract-compatible aggregate facts may continue; preserve explicit missing-data caveats and do not insert fabricated cycle days or zero-valued unknown measurements.
- Native policy governs presentation and eligibility, but cannot guarantee the semantic correctness of generated prose. Validate any changed AI explanation behavior with synthetic fixtures; retain deterministic facts and limitations visibly. If the current contract cannot represent an optional new feature honestly, defer that remote feature pending approved contract/consent work rather than weakening the native feature.
- No consent grant, profile edit, record edit, migration, or availability change silently enables daily preparation or resets its daily-attempt reservation.
- Clinician-reviewed care guidance must be proportionate and accessible without AI. No new diagnostic thresholds or urgent-care rules are invented during engineering implementation.

## 8. Ordered implementation phases and gates

Each phase is a small, reviewable change set. Do not combine storage migration, onboarding redesign, forecast-policy changes, and an AI contract change in one release-sized patch.

| Phase | Deliverables and affected modules | Acceptance / stop gate |
|---|---|---|
| **0 — Baseline and decisions** | Recheck source map, repository status, supported destinations, existing fixture isolation, and current test results. Resolve the phase-specific decisions above. Document real failures separately from stale automation. | Reproducible baseline, no unrelated edits overwritten, approved first-slice scope. No UI test assertion removed merely for a green run. |
| **1 — Policy foundation** | Pure forecast-availability model; characterization tests; integrate `TrackerSession` and consumers in parity mode before approved irregular-case behavior changes. | Existing eligible regular/sparse starter math unchanged; no reference-to-prediction promotion; primary reminders and replay remain distinct. No store migration. |
| **2 — Unknown-friendly onboarding** | Minimal backward-compatible profile answer metadata if needed; all setup/default/review/profile-edit/repository guards updated; zero-period completed experience. | Unknown/no-history journey reaches working tabs after the existing Apple flow; relaunch preserves unknowns. Known-input, legacy, interrupted, sign-out/reconnect, and registry journeys still pass. |
| **3 — Daily model and migration** | Domain validation, additive V7 if justified, snapshot/repository APIs, atomic reconciliation, reset/export plumbing, V1–V6 upgrade fixtures. Keep new UI hidden until this gate passes. | No fabricated history, double counting, orphan links, partial saves, receipt corruption, or store-loss fallback. Reopen and injected failure tests pass. |
| **4 — Daily logging and presentation** | Explicit bleeding/spotting/no-bleeding/unsure entry; reviewed episode association; historical edits/deletes; shared Today/Calendar markers and day details. | Existing new/continuation/edit routes still work. Cross-tab consistency, future guards, large text, VoiceOver labels, cancellation and relaunch pass. |
| **5 — Descriptive value and care preparation** | Variation/coverage insights, deterministic appointment summary and versioned export, suitable reminder copy/eligibility; reviewed offline guidance. | Numbers match records, missing information stays explicit, export opt-ins preserved, forecasts/AI are not required for usefulness. |
| **6 — Release validation** | Full applicable unit/UI suites, unsigned Release build/archive, artifact/privacy checks, physical/signed-device acceptance, final scoped diff and rollout notes. | Explicit release decision based on executed evidence. No “full pass” assembled from selected tests across unrelated revisions. |

**Recommended first implementation slice:** phases 0–1, followed by phase 2. This provides safer uncertainty and no-history support before introducing a new daily-record schema. Do not start with a predictive algorithm replacement.

**Later, separately approved:** dated context changes/epochs, approximate date support, additional symptom-impact fields, advanced model research, extended reminders, and AI context expansion. Context epochs must preserve older observations, not delete them or silently redefine replay.

## 9. Regression and validation matrix

All automated scenarios use synthetic records, isolated stores, fixed clocks/timezones, and existing service doubles. Never use a production store, real health records, native account writes, live AI/registry calls, or real HealthKit operations as an accidental test side effect.

| Area | Required cases | Existing suites to extend or retain |
|---|---|---|
| Setup/profile | Known, explicitly unknown, unanswered, no starts, only symptoms, resume before/after staged save, failed final commit, old payloads, 28/5 legacy values, profile edits without reseeding | `cecyTests/OnboardingTests.swift`, `CycleSetupRefreshTests.swift`; `cecyUITests/cecyUITests.swift`, `TodayDetailsAndWelcomeUITests.swift` |
| Identity and registry | Mandatory Apple authorization, cancel/stale response, same-account reconnect, activation only after completed setup, reset/deactivation retry and partial failure | `cecyTests/UserRegistryLifecycleTests.swift`, `UserRegistryServiceTests.swift`; existing onboarding/logout/reset UI cases |
| Forecast | Zero/one/many starts; nil profile lengths; 14-day boundary and above; unknown ends; prolonged gaps; context policy; preserved median/padding/confidence; reference withholding across all surfaces | `cecyTests/CycleDomainTests.swift`, `CycleForecastTests.swift`, `AdaptiveForecastTests.swift`, `CyclePhaseTests.swift`, `DailyInsightsAndOvulationTests.swift` |
| Projection versus evidence | No fabricated periods, no rolled-forward primary reminders, historical replay unchanged, future-only projections labelled appropriately | Existing adaptive/forecast/history tests plus dedicated policy tests |
| Dates and validation | DST, timezone travel, leap/year boundaries, exact today/future rules, duplicates/overlaps, long genuine recorded intervals | Existing domain, historical logging, and privacy/reminder suites |
| Storage and migration | Fresh/new store; all supported V1–V6 upgrades; old JSON profiles; reopen; corrupt store; injected save failure; atomic episode/day reconciliation; edit/delete link integrity | `cecyTests/PhaseTwoTests.swift` through `PhaseSixTests.swift`, `LaunchReadinessTests.swift`, plus new daily/migration fixtures |
| Mutation lifecycle | Duplicate taps, pending save versus reset/logout, background/cancel before commit, committed save not misreported as failed, rollback without unrelated data loss | `cecyTests/FinalEngineeringTests.swift`, `PredictionUpdateProgressTests.swift` |
| Daily semantics | Absent versus explicit unsure/no bleeding; symptom-only coverage; standalone spotting; conflicting day/episode; retaining/unlinking on deletion; no episode-derived backfill | New daily bleeding domain/repository/UI suites; retain `DailyLogTests.swift`, `HistoricalLoggingTests.swift` |
| Calendar/Today | Same selected-day records/markers across collapsed/expanded/list views; historical routing; future-disabled actions; no unsupported phase; no clipped legend/cards | Existing calendar layout/grouping, daily log, phase, forecast-card and historical UI suites |
| Health import | Start-only preserved, repeated sample idempotent, timezone confirmation, local edit/delete receipt behavior, no generated ends/coverage | Existing Health import cases in phase-six suites |
| Export/deletion/privacy | Old JSON semantics, new version, selection allowlists, no accidental notes/identity/activity, cleanup after cancel/background, all new records deleted on reset | Existing phase-five/six, sexual-activity, launch-readiness and reset suites |
| AI | Catalog v2 unchanged, payload allowlists, nil facts not zero, new fields absent, consent renewal semantics intact, once/day persisted attempt, manual priority, cancellation/stale output, reviewed save | `cecyTests/AICatalogV2Tests.swift`, `AIServiceTests.swift`, `PhaseEightTests.swift`, `DailyInsightsAndOvulationTests.swift`; `cecyUITests/PhaseEightUITests.swift` |
| Reminders | Daily independent from forecast; forecast suppression cancels stale alert; explicit details choice preserved; permission denied; DST; no extra projected-cycle notifications | `cecyTests/ReminderLayoutTests.swift`, existing privacy/reminder suites and UI cases |
| Accessibility/performance | Narrow/iPad layouts, largest Dynamic Type, VoiceOver, contrast/non-color distinctions, reduced motion, keyboard; dense synthetic multi-year daily records without quadratic per-cell work | Existing UI/layout suites plus measured simulator/device scenarios; do not infer performance from bounded projection tests |

Add focused new test files for policy, unknown onboarding, daily observations, reconciliation, migration, and summary/export rather than overloading unrelated historical suites. Actual type/test names are chosen during implementation.

### Execution order

1. Record HEAD, clean/dirty status, configuration, simulator/device OS, and baseline failures.
2. Run relevant existing suites and new characterization tests before behavior edits.
3. For each phase, run focused unit/persistence tests, affected UI journeys, and source diagnostics.
4. At the final candidate, run the full unit and UI targets, then Release build/archive with isolated derived data. Retain command logs and result bundles outside ephemeral storage for sign-off.
5. Perform explicitly authorized native/physical checks: file protection and locked access, actual signed upgrade, Apple authorization, Health permissions, notification delivery, Mail/share, offline tracking, iPhone/iPad, supported OS coverage, and accessibility.
6. Simulator-skipped physical protection is **not passed**. Document unavailable checks and owner disposition. A successful unsigned archive is not signed distribution or clinical acceptance.

## 10. Rollout, rollback, and stop conditions

- Use small commits/change sets with separate review of policy, profile semantics, migration, and UI. Preserve unrelated work; no destructive resets, branch changes, or production-data cleanup.
- Any feature gate must be local/in existing infrastructure, default safely, and cover every consumer consistently. It is not a substitute for migration tests.
- Introduce new storage before exposing its editors. Disabling a new UI must retain and keep new data interpretable; do not silently omit it from all history/export surfaces.
- After a schema upgrade, **do not reinstall an older binary against the upgraded store** without proven compatibility. Prefer a forward corrective release; UI rollback is not database rollback.
- Migration failure preserves the store. No erase-and-recreate workaround, automatic restore claim, or destructive downgrade.
- Stop if an existing record changes without explicit user action, legacy onboarding restarts, the identity/registry sequence changes, an AI payload expands, a stale forecast notification remains, or a coupled save partially commits.
- Investigate new crashes/layout warnings, performance regressions, accessibility failures, or failed acceptance assertions. Repair demonstrated stale automation without weakening save/relaunch/cancel/uncertainty requirements.
- Existing unrelated release gates remain open: public privacy-policy access, registry authorization/disclosure concerns, Apple token-revocation obligations, provider retention/safety evidence, and signed-device/distribution acceptance. This feature must not claim to close them.

## 11. Definition of done

- A new user with unknown dates/lengths completes the existing identity-protected setup, saves a first observation, relaunches, and can use Today, Calendar, Insights, Settings, export, and deletion without fabricated history.
- Existing regular-cycle fixtures retain expected recorded data and approved forecast behavior.
- Every intentionally changed irregular/context-affected forecast surface agrees on availability, reason, and limitations; typical references cannot bypass a withheld date.
- Daily observations, episodes, import receipts, statistics, summaries, and calendar markers remain consistent through create/edit/delete/cancel/failure/relaunch.
- All supported migrations preserve old facts; new daily history is never invented.
- Existing privacy, account/registry, AI consent/contracts/rate limits, reminder choices, and accessibility safeguards remain intact.
- Core tracking and deterministic summaries remain useful without AI or network availability after the existing setup requirements are satisfied.
- Tests/builds actually executed, skipped device checks, remaining warnings, intentional behavior changes, and release-owner decisions are recorded for the exact candidate revision.

## 12. Next action

Implementation now includes daily logging, shared Today/Calendar presentation, reviewed corrections, recording coverage, and protected appointment-summary sharing. Existing reminder controls and AI contracts are unchanged; no additional check-in schedule or range-backfilling questionnaire was added.

Before release, obtain a clean full-suite run on the frozen candidate and complete physical/signed-device, supported-OS, accessibility, and native-service acceptance. The passing focused rerun is not a full-suite pass. Qualified review is still required before adding clinical guidance or broader context-specific fertility rules. Preserve the V7 forward-correction safeguards and existing privacy/account release gates.
