# Phase 8 — Existing AI gateway: iOS integration plan

October 1, 2026 · Branch: `planning/phase-8-gpt`

## Implementation authorization and current evidence

The user resumed AI work after local prerequisites and authorized all five handoff features. All five iOS paths are implemented; all 62 focused unit/storage/transport tests and four AI UI scenarios passed together in the continuation run; Debug and a fresh unsigned iOS Release build also passed. See [PHASE_8_VALIDATION.md](PHASE_8_VALIDATION.md) for actual files, behavior, results and deviations. This supersedes earlier planning-only, wait-for-user and normalization-only stop instructions below. No new backend or live endpoint requests. Contract details absent from the handoff and prototype/device release checks remain open. The remaining text records the original staged design, not current implementation status.

## User-directed local prerequisite detour

The user requested missing local data collection before AI integration. Digestive-change tracking and optional wellness preferences are implemented; 45 focused unit/storage tests, three UI flows verified across reruns, and Debug/unsigned iOS Release builds passed. Manual and full-baseline gates remain open. See [LOCAL_WELLNESS_PREREQUISITES.md](LOCAL_WELLNESS_PREREQUISITES.md) for evidence. That completed local-only milestone did not include AI services or requests. The user has since resumed AI implementation, as recorded above. Estimated phase remains deferred: it is optional in the gateway and the app has no validated phase policy.

**Current status: all five iOS paths implemented; focused automated checks passed, live contract/release gates remain open.** User authorization now covers later slices as well as confirmed normalization. Live endpoint verification remains unperformed.

## Continuation checkpoint — October 1

All five iOS paths are present; the proposed file layout and unchecked pre-coding lists below are historical design/review records, not missing Swift files. Current evidence belongs in PHASE_8_VALIDATION.md.

| Slice | Actual implementation | Status |
| --- | --- | --- |
| Contracts/transport | `Domain/AIModels.swift`, `Services/AIService.swift`, `Services/FixtureAIService.swift` | Implemented; five typed tasks and synthetic transport tests |
| Consent/lifecycle | `App/AIRequestCoordinator.swift`, `TrackerSession`, `TrackerPrivacy`, `Domain/PrivacyData.swift`, `Features/AI/AISharedViews.swift` | Implemented; protected opt-in, explicit submission, cancellation and stale-result rejection |
| Confirmed normalization | `Features/AI/AISymptomEntryView.swift`, existing symptom form/repository | Implemented; editable review and atomic confirmed save |
| Explanations/wellness/summaries/questions | `Domain/AIContextBuilder.swift`, `Features/AI/AIFeatureView.swift`, Today/Insights entry points and shared `CycleInsights` timing evidence | Implemented; local facts authoritative, minimal context, ephemeral output |
| Acceptance | `AIServiceTests.swift`, `PhaseEightTests.swift`, `PhaseEightUITests.swift` | Consolidated run passed: 62 focused tests plus 4/4 AI UI scenarios; fresh unsigned Release passed. Live contract/release gates open |

Implemented prototype decisions: both sleep and energy suggestions initially remain **unrated** for user review (superseding the proposed Low-energy default below); keeping the original description as a private note on each symptom defaults on; requests have a 75-second coordinator deadline; generated prose is ephemeral. These choices are not independent medical/privacy review or gateway-contract verification.

Next: obtain authoritative gateway fixtures/enum limits and separately authorize synthetic live checks; review provider/privacy and prototype distribution controls; resume deferred baseline/device acceptance at an agreed checkpoint. Do not recreate the backend or mark open gates complete based on fixture tests.

## 1. Scope, authority and evidence

The October 1 user handoff expands the original explanation-only proposal to five bounded enhancements: natural-language symptom normalization, insight explanation, daily wellness suggestions, cycle summaries and questions about locally derived history. Product framing: Track → Understand → Act. Not a generic chatbot, remote health database or replacement prediction engine.

Use the existing Function App **`cecyaiendpoints`**, exclusively through:

**POST `https://cecyaiendpoints-gqdahecce6g7dufv.westus3-01.azurewebsites.net/api/ai`**

- Current prototype authorization is anonymous: no function key, bearer token or client OpenAI credential. Do not create another backend, Function App, custom AI authentication, App Attest or DeviceCheck implementation.
- The handoff reports deployment, 14 backend tests and five production smoke tests passing. These are supplied backend results, not iOS results or independently verified evidence from this review.
- The gateway is reported stateless, without health/account/conversation storage and without raw sensitive request/response logging. Do not equate gateway statelessness with zero OpenAI retention or absence of infrastructure metadata; provider processing, logging configuration and privacy-policy wording still need release review.
- No rate limiting, quotas or attestation currently protect the public endpoint. Client duplicate prevention is UX, not abuse protection. Treat integration as prototype-only until a separate backend hardening/release decision; do not implement those backend controls in this iOS slice.
- Exact GPT model, model prompts, secrets and provider retries remain server-owned. No client model picker, direct OpenAI SDK or large medical prompts.
- Existing regression and signed-device acceptance work remains deferred, not resolved. Historical baseline: 113/114 unit and 19/30 full UI tests passed; see `PHASE_6_VALIDATION.md`. New work still needs its own tests; no full-suite-green or release claim until outstanding gates close.

## 2. Reconcile the handoff with the current project

| Handoff assumption / gap | Verified project state | Proposed resolution |
| --- | --- | --- |
| Onboarding/account work is next, before Phase 6 | Onboarding, profile, Apple identity and read-only HealthKit import are implemented on the current branch | Do not repeat them; add AI to the current app |
| Core Data is the source of truth | `SwiftDataPeriodRepository` uses local SwiftData V6; `Persistence.swift` and the template `.xcdatamodeld` are excluded from the app target | Interpret the intent as local repository-owned storage. Keep SwiftData, V1–V6 history and `cloudKitDatabase: .none` |
| Existing plan says create an Azure relay | User supplies an already deployed Azure gateway | Supersede creation/model-hosting selection tasks with integration; no backend project |
| AI only explains findings | New handoff includes normalization, wellness and bounded personal questions | Expand Phase 8 explicitly; local calculations stay authoritative |
| API has 13 symptom codes | `SymptomKind` now has 13 cases, including local digestive changes; `CommonSymptom` has parity | Local prerequisite implemented. Wire mapping and AI review remain deferred; no parallel persisted taxonomy |
| All severities map to numbers | Sleep uses Poor/Fair/Good; energy uses Low/Typical/High | Explicit mappings and review; never map severe to Good sleep or High energy |
| Estimated phase is an existing local fact | No supported estimated-phase engine exists | Omit optional `estimatedPhase`; do not invent luteal/follicular/ovulation states or add a phase engine here |
| Wellness preferences already exist | Local prerequisite now adds optional activity/exercise/diet/allergy/wellness-goal values, separate from tracking goals | Reuse the local profile block/editor. Validate server enum mapping and required context later; unanswered is not explicit none |
| Cycle summary always has required facts | Period ends can be unknown; cycle duration requires a subsequent start | Gate summary eligibility on real facts; no guessed period length or profile-duration substitution |
| Any question can be supplied relevant facts | No question intent resolver exists; timing evidence is private inside the insight engine | Add bounded local intent selection and reusable deterministic evidence, not a full-history upload or another AI routing endpoint |
| Handoff examples are a complete machine schema | No backend schema/source is present here; optionality, bounds and allowed enum values are only partly documented | Obtain contract fixtures/schema from the existing service owner before each slice; never invent defaults to satisfy validation |

## 3. Reuse map

All paths below are relative to the repository root.

| Existing file / symbols | Reuse |
| --- | --- |
| `cecy/App/TrackerSession.swift`: `snapshot`, `today`, `overview`, `statistics`, `predictionReplay`, `insights`, `addSymptoms`, `saveSymptom`, `publish`, `live` | One committed source snapshot, dependency composition, current access gates and existing write/recompute pipeline |
| `cecy/Domain/Symptoms.swift`: `SymptomKind`, `SymptomEntry`, `SymptomValidation`, `qualifiesForTiming` | Domain taxonomy, optional ratings/notes, one kind/day rule and timing semantics |
| `cecy/Data/SwiftDataPeriodRepository.swift`: `addSymptoms`, `saveSymptom`, `saveProfile` | Validate candidate data, single-save batch insertion, rollback, repository-assigned timestamps; no AI persistence bypass |
| `cecy/Features/Logging/SymptomEntryView.swift` | Manual selection, per-kind rating, note/date validation, discard confirmation and save error UX |
| `cecy/Domain/CycleAnalysis.swift`: `Period.duration`, `CycleInterval`, `CycleOverview`, `TrackerSnapshot` | Confirmed inclusive bleeding duration, start-to-start intervals and current cycle day |
| `cecy/Domain/CycleStatistics.swift`: `RecordedStatistics`, `CycleStatistics.calculate` | Mean, median, spread, standard deviation and recorded sample counts |
| `cecy/Domain/CycleInsights.swift`: `CycleInsight`, `TimingSupport`, `CycleInsightEngine` | Existing qualifying insights, prior/recent metrics and timing evidence; preserve thresholds and missing-log caveats |
| `cecy/Domain/PredictionEvaluation.swift`: `PredictionEvidence`, `PredictionReplay` | Existing confidence reasoning and reconstructed history; not probability calibration |
| `cecy/Domain/UserProfile.swift`: `LocalProfile`, `TrackingGoal` | Existing tracking goals and optional local wellness preferences; profile answers are not dated symptoms |
| `cecy/Domain/PrivacyData.swift`, `cecy/App/TrackerPrivacy.swift`, `cecy/Services/ProtectedFiles.swift` | Protected local preference storage, durable save-before-publish, backup exclusion, reset and access control |
| `cecy/App/TrackerRootView.swift`, `cecy/Shared/PrivacyShield.swift`, `cecy/App/HealthImportReview.swift` | Root lifecycle/privacy cover and cancellation/generation pattern; do not reuse HealthKit draft state for AI |
| `cecy/Features/Today/TodayView.swift`, `cecy/Features/Insights/ObservationsView.swift`, `cecy/Features/Insights/CycleHistoryView.swift` | Existing feature destinations; keep the four-tab shell |
| `cecy/Features/Settings/TrackerSettingsView.swift`, `PrivacySettingsView.swift`, `ProfileSettingsView.swift` | Future AI consent management and external-processing copy; reuse the existing local wellness editor |

The project uses iOS/iPadOS 17+, Observation, Swift async/await and default MainActor isolation. New DTOs/pure calculations should follow existing explicit `nonisolated`/`Sendable` conventions. MainActor observable feature state must not perform synchronous networking. Xcode uses file-system-synchronized app/test groups; add files in the existing target folders, verify membership, and avoid unnecessary project or dependency changes.

## 4. Proposed layers and files

Data path: repository → immutable snapshot → deterministic facts → task-specific context builder → AI use case → `AIService` → remote transport. UI calls feature state, never URLSession. Normalization needs only user-submitted text and bypasses health-history context building.

The context builder belongs **before** the typed service call, not inside the transport. Neither `RemoteAIService` nor its DTOs fetch SwiftData or hold the private snapshot.

### Foundation and first slice

| New file under `cecy/` | Types / responsibility |
| --- | --- |
| `Domain/AIContracts.swift` | `AITask`, typed context/result values for five tasks, transport-only symptom/severity enums; no persistence or SwiftUI |
| `Domain/AISymptomMapping.swift` | `AISymptomMapper`, stable review candidates, explicit rating translation and unsupported/conflict results |
| `Services/AIService.swift` | Injectable `AIService` with the five async throwing operations; `AIServiceError`, unavailable implementation for safe defaults |
| `Services/AITransportDTOs.swift` | Generic encoded `AIRequest<Context>`, validated success/error envelope decoding and error-code DTO; camelCase keys as supplied |
| `Services/RemoteAIService.swift` | Existing endpoint, injected URLSession, generic bounded POST/decode routine and five thin typed operations |
| `App/AIRequestCoordinator.swift` | Shared request/access generation, cancellation, response invalidation and ephemeral result cleanup; no repository ownership |
| `Features/AI/AISymptomEntryState.swift` | First use case/state: validate text, enforce consent/access, normalize, map, review and prepare a confirmed batch |
| `Features/AI/AISymptomEntryView.swift` | Describe how you feel; loading, editable result review, conflicts, Save/Edit/Cancel and manual fallback |
| `Features/AI/AIConsentView.swift` | Just-in-time disclosure and Enable AI / Not now |
| `Features/Settings/AISettingsView.swift` | Enable/disable AI, consent disclosure, prototype availability and clearing ephemeral results |

`AIService` operation signatures follow the handoff: `normalizeSymptoms(text:) → SymptomNormalizationResult`, `explainInsight(context:) → InsightExplanationResult`, `getWellnessRecommendation(context:) → WellnessRecommendation`, `generateCycleSummary(context:) → CycleSummaryResult`, `answerCycleQuestion(context:) → CycleQuestionResult`. All are async/throws. Use MainActor isolation consistently with current injected service boundaries; Foundation async URLSession performs the I/O. No singleton or new actor infrastructure is necessary for this small first slice.

### Later files — create only with their slice

- `Domain/AIContextBuilder.swift`: validated, minimal per-task contexts from supplied local facts; no networking, fetching, device identifiers or raw record encoding.
- `Domain/CycleAIFacts.swift`: explicit completed-cycle summary calculation and shared timing evidence extraction where current public domain values are insufficient.
- `Domain/CycleQuestionIntent.swift`: bounded question intents, selected symptom/window, clarification/unsupported states.
- `Domain/WellnessPreferences.swift` is already implemented as a local prerequisite. Reuse it; verify and explicitly map server enums when AI wellness starts. Never send local Codable payloads wholesale.
- `Features/AI/AIInsightExplanationView.swift` and `AIInsightExplanationState.swift`.
- `Features/AI/DailyWellnessView.swift` and `DailyWellnessState.swift`; reuse the already implemented `Features/Settings/WellnessPreferencesView.swift`.
- `Features/AI/AICycleSummaryView.swift` and `AICycleSummaryState.swift`.
- `Features/AI/AskCecyView.swift` and `AskCecyState.swift`.
- A small `Shared/AISafetyMessageView.swift` when prose-result features arrive; render optional nonempty safety text prominently, with accessible text, not color alone.

## 5. Wire contract and remote behavior

One POST endpoint, `Content-Type: application/json`, `Accept: application/json`, JSONEncoder/JSONDecoder and explicit Codable DTOs. Preserve the top-level `{task, context}` shape; no metadata, identity, conversation or model fields added without a contract change.

| `AITask` case / server value | Request context | Success `data` |
| --- | --- | --- |
| `normalizeSymptoms` / `normalize_symptoms` | `text`: nonempty, maximum 2,000 characters | `symptoms`: up to 20 objects with API `type` and nullable `severity` |
| `explainInsight` / `explain_insight` | `insightType`, bounded `facts` object | `title`, `explanation`, `supportingObservation`, nullable `safetyMessage` |
| `dailyWellnessRecommendation` / `daily_wellness_recommendation` | Optional `cycleDay`, `estimatedPhase`; required `symptoms`, `activityLevel`, `preferredExercises`, `dietaryPreference`, `foodAllergies`, `userGoals` | `movementSuggestions`, `foodSuggestions`, `hydrationSuggestion`, `recoverySuggestions`, `explanation`, nullable `safetyMessage`; at most six items per suggestion list |
| `generateCycleSummary` / `cycle_summary` | Required `periodLabel`, `cycleLength`, `averageCycleLength`, `periodLength`, `commonSymptoms`, `observations` | `summary`, `highlights`, nullable `safetyMessage` |
| `answerCycleQuestion` / `answer_cycle_question` | `question`, bounded `facts` object | `answer`, `supportingFacts`, nullable `safetyMessage` |

Use dedicated facts structs for each supported insight/question. An explicitly encoded associated-value enum can wrap those structs into `facts` without adding a discriminator/key absent from the server schema. Do not use `[String: Any]`, export DTOs or unrestricted arbitrary JSON throughout the app. Enum names used by the gateway need an adapter, not renamed persisted domain raw values.

Transport policy:

- Use an injected ephemeral URLSession: no URLCache, cookies or credential persistence; HTTPS only, no ATS exceptions. Reject redirects rather than forwarding sensitive bodies to a different endpoint. No raw payload/question/result logging or health-bearing accessibility IDs.
- Validate before send: nonblank text, agreed Unicode character-count semantics, finite numeric facts and required fields. Enforce a conservative encoded UTF-8 body cap of 32,768 bytes before upload. The server's parsed-JSON guard is not necessarily identical to encoded byte size; confirm Unicode/size boundaries with contract fixtures, never truncate silently.
- Proposed initial total client deadline: 75 seconds, cancellable, with request/resource timeouts configured consistently. Backend reports 20 seconds per OpenAI attempt plus two retries, so a 20-second total client limit would be too short for that path. Confirm actual gateway/platform behavior; 75 seconds is a proposal, not a promised SLA. Bound downloaded responses too (provisional 128 KiB cap, verify against valid maximum fixtures).
- No automatic client retry or background upload. One active submission per feature and coordinator-level duplicate prevention; expose Cancel/Retry. The user must explicitly retry. Rapid taps, view reappearance and day changes must not generate requests automatically.
- Check HTTP status and envelope: a 2xx `{success:false,error:...}` is still failure; non-2xx is never a successful result. Reject malformed/mismatched/oversized bodies, absent required data, unknown taxonomy/severity and impossible numeric values. Missing/null `safetyMessage` is supported; no safety guarantee inferred from presence or absence.
- `INVALID_REQUEST` → `.invalidRequest`; `UNSUPPORTED_TASK` → `.unsupportedTask`; `AI_UNAVAILABLE` → `.unavailable`; `AI_RESPONSE_INVALID` → `.invalidResponse`; `INTERNAL_ERROR` → `.serverError`. Unknown error code/non-JSON error → safe server/invalid-response error according to status. URLError → `.networkError` or `.timedOut`; preserve cancellation as cancellation, not an error banner. Future 429/503 → temporarily unavailable, no retry loop; unexpected 401/403 → unavailable/configuration issue, not an invented login flow.
- Generic user message: “Cecy couldn’t process that right now. Try again in a moment.” For symptom failure add “Your records haven’t changed.” Keep text/question and manual paths available; never display raw server messages/codes.
- `TrackerSession.live()` is the sole production composition point. Default constructors, previews, unit and UI test compositions use unavailable/mock service and isolated storage, never the production endpoint.

## 6. Consent, privacy and lifecycle

Propose an optional `AIConsentRecord` field in `PrivacyPreferences` with accepted notice version and timestamp. Absence means off. Use backward-compatible decoding; adding a default Bool with synthesized decoding alone must not break old JSON. Keep existing preference file version compatible or explicitly migrate it; verify lock/appearance/reminder values remain unchanged.

- Explain before the first submission: selected text and relevant facts are sent through Cecy's Azure service to OpenAI, not the full history; AI is optional and may be wrong. Show exactly what task will use. Free text can contain sensitive/identifying details; invite omission of names/contact details. Do not promise automatic anonymization or zero provider retention.
- Enable AI / Not now. Save consent successfully before sending; failed consent persistence sends nothing. For the initiating action, Enable AI may resume that one explicitly requested submission while the view/access token is still valid. Not now preserves the draft and manual logging.
- Use one versioned opt-in for the clearly disclosed five-task scope plus per-request visibility. Later new categories/processing changes require updated consent. Export, HealthKit, Apple sign-in and partner permissions never imply AI consent.
- Settings can disable AI. Immediately cancel/gate new requests and discard ephemeral responses even if persisting revocation fails; visibly require retry, do not report a durable disable until saved. Do not automatically resume on relaunch/unlock.
- Reset clears AI consent along with ancillary preferences while preserving the lock preference; include signed-out reset and partial-reset failure cases. Logout cancels requests/clears drafts/results; proposed consent retention matches preserved local preferences and same-account binding, but cannot permit signed-out requests.
- Requests check `privacy.canAccess`, signed-in/local-access state, completed onboarding, foreground state and current consent before send, before display, and before saving. Do not hold `session.isSaving` for network duration; tracking remains usable.
- Reuse the cancellation-generation pattern from `HealthImportReview`, not its state. Stop on view dismissal, background, app lock/access loss, logout, consent revocation or reset. Clear sensitive drafts/results on security transitions even with app lock off. Keep drafts on ordinary network failure; background cancellation is intentionally distinct and disclosed.
- Capture draft and source-data revision locally; ignore late replies after text edits, changed source records, date/time-zone context changes or new requests. A source revision is never sent externally. Cancelled HTTP requests may already have reached the gateway/provider: do not claim cancellation retracts data.
- All AI forms/results use the existing root/window privacy shield. Test new sheets explicitly. Existing local export remains consent-controlled; AI consent must never make notes/profile export automatic.

## 7. First vertical slice: natural-language symptom logging

### Taxonomy adapter (proposal for review)

| API type | Existing domain destination / decision |
| --- | --- |
| `cramps`, `headache`, `bloating`, `fatigue`, `acne`, `nausea`, `cravings` | Same-named `SymptomKind` |
| `mood_change` | `.moodChanges` |
| `back_pain` | `.backPain` |
| `breast_tenderness` | `.breastTenderness` |
| `sleep_change` | `.sleepQuality`, initially unrated; user reviews actual Poor/Fair/Good or explicitly leaves unrated. “Change” does not establish poor sleep |
| `low_energy` | `.energyLevel`, suggest Low (`1`) from the meaning of the type, only save after review; API severity is not a Low/Typical/High score |
| `digestive_change` | Map to the now-implemented local `.digestiveChanges`; AI adapter/review implementation is still deferred. Never silently map to nausea/bloating |

For ordinary severity kinds, mild/moderate/severe → 1/2/3; null → nil, never a default moderate. For sleep/energy, display a clear mapping explanation and let the user confirm/change the domain rating; do not persist AI severity as an incompatible health fact. Suggestions are not confirmed observations, even when the service inferred a severity from vague wording.

The user-authorized local prerequisite has added `.digestiveChanges` to `SymptomKind` and `CommonSymptom`, including ordinary logging/profile choices, persistence, export and symbol tests. No new SwiftData schema is required: existing records store strings and ratings, and existing raw values/frozen models remain unchanged. Older app binaries cannot necessarily decode the new kind; no downgrade guarantee. The future AI adapter must still validate all server codes and reject unknown results visibly; no silent data loss.

### Flow and persistence

1. Add “Describe how you feel” to **new-entry** `SymptomEntryView`, reachable through current Today/Calendar logging. Existing record-edit mode stays manual in slice one.
2. Dedicated feature state owns the original text, selected LocalDay, task token, candidates and state: editing → consent → loading → review → saving/saved, with failed/cancelled routes. No repository write on network response.
3. Validate 1–2,000-character nonblank text; preserve the original locally in memory. Show transmission disclosure and explicit submit, not a network call on every keystroke.
4. Map response into stable-ID review candidates. Empty array is a valid “No symptoms identified” state with manual selection, not an empty batch save. Unknown wire values or more than 20 results are invalid responses, not partial success.
5. Show detected kinds, editable ratings, date and note preview with Save/Edit/Cancel. Any repeated kind returned by AI must be explicitly resolved; do not silently choose the strongest severity. Flag already-recorded kind/day conflicts and permit removal or separate navigation to existing manual edit; no automatic overwrite/upsert or mixed partial commits.
6. Reuse/extract the existing manual field controls with a small explicit draft-transfer interface; do not duplicate the form's validation/taxonomy. Manual fallback keeps text and valid selections. Do not interpret generic mention of past/future days in text as a record date; selected date is authoritative.
7. Offer “Keep description as a private note,” default on with visible preview/edit/removal, following the handoff's preservation intent. Existing batch UI already copies one note to each selected symptom; disclose that behavior. Preserve user text only, not a fabricated AI narrative. Existing private notes are never automatically submitted with subsequent requests.
8. On explicit Save, build confirmed `SymptomEntry` values and call `TrackerSession.addSymptoms` once. Revalidate against current snapshot/today/access and unique kind/day at commit. Repository owns timestamps/transaction; any failure preserves the full review draft and existing records. Disable double-save and dismiss only after commit. Session recomputes insights using the existing pipeline.
9. Cancel leaves records unchanged; ordinary navigation with unsaved work uses the existing discard pattern. On security transitions discard sensitive transient state. Retrying normalization does not add duplicate stored records.

**Storage impact of slice one:** no new health entity, no new SwiftData schema, no Core Data work. Add backward-compatible AI consent to protected preferences; reuse `SymptomEntry.notes` and the already implemented digestive-change taxonomy extension.

## 8. Later vertical slices

### 8B — Insight explanations

- Add an on-demand “Explain this” action beside an existing `InsightCard` in `ObservationsView`. Always retain deterministic title, metrics, evidence and original explanation if AI is off/fails.
- `AIContextBuilder.insight` accepts a qualifying `CycleInsight` and a typed local evidence value. It sends category-specific metrics/counts, units and necessary limitations, not `sourceIDs`, exact record timestamps or raw arrays of observations.
- `cycleLength`, `cycleVariability`, `bleedingDuration` map to confirmed server `insightType` values. Only `cycle_variability_change` is demonstrated by the handoff; verify accepted labels/facts before adding the others. Standard deviation is not range/spread: name the metric and units explicitly.
- For symptom timing, expose explicit kind/window facts from domain logic; do not parse UI strings or infer them from title text. Refactoring the private timing helper must retain existing insight thresholds and golden outputs.
- `PredictionExplanation` remains local. AI wording for prediction confidence is a later action in this slice only if the existing gateway accepts that insight context; do not invent a new task.
- On response, render `title`, `explanation`, `supportingObservation` and optional `safetyMessage` as AI wording, with trusted facts still visible. Schema checks do not prove medical/factual correctness; maintain consistency evaluation fixtures and no AI-driven changes to numbers, confidence or insights.

### 8C — Today wellness

- Reuse the already implemented optional `LocalProfile.wellnessPreferences`: activity level, preferred exercises, dietary preference, allergy answers and optional wellness goals. Existing `TrackingGoal` values do not equal `manage_symptoms`/`stay_active`; use only reviewed mappings and explicit additional choices, not invented fitness goals.
- Persist through existing profile JSON payload and `saveProfile`. Prefer optional additive Codable fields with explicit legacy decoding/default tests, preserving profile identity and unrelated settings. A SwiftData V7 is not automatically necessary because `ProfileRecord.payload` is already Data; use a payload/version migration if actual encoding changes require it. Review profile export inclusion/disclosure before persisting new health fields.
- Collect preferences in Settings/Profile or a small just-in-time sheet, not mandatory onboarding. Verify exact server enum strings; the handoff's potential values are not a complete validated wire enum. Unknown activity/diet or unreviewed allergies must not silently become “moderately_active,” “none” or allergy-free. Prompt for required answers; arrays may be empty only after an honest choice. Keep uncollected vs explicitly empty distinct locally.
- Context uses today's confirmed symptom records only, mapped to API severity appropriately; no full history/common-symptom profile list. Only Poor sleep/Low energy can serve as adverse sleep/energy observations, and their ratings cannot be converted into unsupported severity—send null when appropriate. Document representation of unrated sleep/energy or withhold until clarified.
- Send optional cycle day if valid. Omit estimated phase. Symptoms/severity have priority; no phase-based rigid prescriptions. Include chosen allergies whenever present. Show supplied preference summary before generation.
- Today “For today” contains movement, food, hydration, recovery and “Why these?”. Explicit Generate/Refresh initially, no scheduled daily API call. Results ephemeral for current day/source revision; invalidate on symptom/profile/date changes. No disk cache in first wellness release.
- Display safetyMessage prominently if present; severe symptom requests can legitimately return nil. Keep a short static non-diagnostic severe-symptom caution in the client independent of that field, with wording reviewed before shipping; do not replicate server medical prompts. Allergy disclosure is not a guarantee that generated meals are safe; include checking ingredients and reject clearly incompatible results where deterministic checks are possible, without claiming comprehensive medical validation.

### 8D — Completed-cycle summaries

- Add on-demand “Your cycle summary” to a completed interval detail from `CycleHistoryView`; no automatic call on period save.
- `CompletedCycleFacts` selects consecutive starts and counts cycle days in `[start, nextStart)`. `periodLength` is the selected period's confirmed inclusive duration, never `LocalProfile.typicalPeriodDays` or an inferred bleeding span.
- Proposed comparison average: up to six completed intervals ending at the selected cycle, including that cycle; disclose the window/count locally and avoid later records when summarizing an older cycle. With only one interval, make clear that the comparison has one record; do not describe a trend. Confirm this policy during slice review.
- Calculate common symptom frequencies/timing and observations locally within the selected interval; do not reuse cross-cycle insights as though they describe one cycle. Missing logs mean unknown, not absence. Encode required arrays as empty only when no recorded observations exist, not a fabricated negative finding.
- All required facts must be available, including confirmed period length. Otherwise retain the ordinary cycle detail and show what is missing; do not send zero/null/unconfirmed facts unless the existing contract explicitly supports them. No backend change unless this is raised and approved as a contract problem.
- Render summary/highlights/safetyMessage with local source facts. Initially ephemeral and regenerable; saved summaries are a separate later decision needing local cache schema, provenance/versioning, invalidation, export and reset tests. No prediction writeback.

### 8E — Ask Cecy, bounded personal questions

- Add “Ask about your records” in Insights, not a fifth chat tab. One ephemeral question/answer, with text retained on ordinary error. No persisted conversation, chat database, server memory, prior-message array or automatic request on typing.
- Start with explicit supported scopes: cycle length/variability, recorded symptom frequency, and before/start-window symptom timing. Suggested prompts and a symptom/window selector make the first interaction deterministic. A small tested local resolver may recognize unambiguous paraphrases; unsupported/ambiguous questions ask for clarification before any health context is sent. Do not promise unrestricted natural-language understanding on the client or add a second remote classifier.
- Extract reusable timing evidence from `CycleInsightEngine` into a pure helper: eligibility, nonoverlapping elapsed windows, up to six eligible starts, requested symptom, matching count, actual day offsets and missing-log limitation. Current insight generation withholds below thresholds; that must not be treated as proof that there were zero observations. Keep observation counts distinct from a claimed recurring pattern.
- For the supplied headache question, count **eligible starts with at least one matching headache log**, not raw headache entries, use the requested pre-period window, and derive min/max from matched offsets. Do not assert “usually” from a single observation or interpret unlogged starts as symptom absence.
- Build a typed question-specific facts object; send current question plus only those facts. Keep IDs, dates, notes, sexual activity, profile identifiers and source provenance local. Insufficient evidence gets an honest local response/clarification; no remote speculation. Empty/unrelated/diagnostic or unsupported requests never trigger a full-history fallback.
- Render `answer`, `supportingFacts`, optional `safetyMessage`, and visible local evidence/caveats. Each follow-up is a new independent question with fresh local facts; no implicit conversational memory. Server owns safety instructions; treat user text as untrusted input and never give a model repository access/tools.

## 9. Persistence and output safety decisions

- Local SwiftData remains authoritative; Azure receives transient selected inputs only. No AI request/results table, raw-history sync, second store or schema redesign.
- Normalized symptoms and optional original description persist only on confirmation. Consent is a separate local protected preference. Local wellness profile changes are now implemented and version-tested in the prerequisite detour; external processing remains postponed to 8C.
- Insight explanations, wellness, summaries and answers initially remain memory-only. No HTTP disk cache. Clear on access loss/logout/reset/consent revocation and invalidate when facts change; regenerated wording is not saved historical evidence.
- Render generated strings as untrusted text; no remote HTML/webviews, executable content, automatic links/actions or automatic health edits. Do not infer semantic trust from strict JSON output.
- Preserve deterministic facts/caveats beside generated prose. Test contradictory claims, prompt injection in typed descriptions/questions, unsupported diagnosis, severe symptoms with nil safetyMessage and malformed output. Model safety prompts are not a deterministic guarantee.

## 10. Contract questions / review decisions

### Needed before first-slice coding

- [ ] Review the future AI taxonomy adapter and proposed sleep/energy review mapping; reject silent data loss. The local digestive-change addition is already user-authorized and implemented.
- [ ] Confirm original-description note default and duplicated-per-symptom note disclosure.
- [ ] Obtain authoritative success/error fixtures (including empty symptoms, null severity and Unicode limits) and HTTP status behavior for the existing endpoint. Confirm the complete supported enum spellings; do not run live tests with real health text.
- [ ] Review consent wording/version, response cleanup on background, and the provisional timeout/response-byte limits.

### Needed before later slices / distribution

- [ ] Obtain exact `insightType`, facts-object schemas/bounds, question/text limits, wellness enums and response-field optionality/length limits. The handoff's citation placeholders are not accessible API documentation.
- [ ] Approve minimal local wellness fields, goals mapping, explicit unknown/allergy answers and profile export policy.
- [ ] Approve cycle summary comparison window and required-fact gating; define question intent support and sparse-history wording.
- [ ] Verify Azure/OpenAI processing/retention and existing privacy disclosures. Document public anonymous endpoint risk and a separately owned hardening gate; no claim that client throttling secures it.
- [ ] Review static wellness caution, ingredient/allergy copy, age-appropriate use and medical-content acceptance with the existing safety policy.
- [ ] Revisit optional saved summaries/caching only if requested; initial proposal remains ephemeral.

## 11. Sequence and acceptance gates

Tests are part of each step, not postponed until all features exist. Create only the files necessary for the current step. Update `IMPLEMENTATION_PLAN.md` as each step starts, passes, changes or is deferred.

| Step | Deliverable | Exit check |
| --- | --- | --- |
| 8.0 — this change | Inspect app, reconcile handoff, record plan and review decisions | Plan reviewed; no new service or app code |
| 8.1 | Five-task typed contract, common remote transport/errors and mocks; normalize path first | Encoding/decoding/status/size/timeout/cancellation fixtures pass; no test contacts Azure |
| 8.2 | Protected versioned consent, settings, coordinator and access lifecycle | No request before consent or after denied access; old preference files and failed writes behave safely |
| 8.3 | Natural-language entry, taxonomy mapping, editable review and atomic confirmed save | Complete first vertical slice tests; manual path unchanged; no write on response/cancel/failure. **Stop for review before later UI** |
| 8.4 | Context builder and on-demand explain_insight | Local insights stay authoritative; minimal payload and invalidation verified |
| 8.5 | Reuse local wellness preferences; add AI Today integration | Required inputs are honest; symptoms drive context; phase omitted; allergies and optional safety text handled |
| 8.6 | Completed-cycle facts and summary | No guessed durations; old-cycle boundaries and source revision tests pass |
| 8.7 | Bounded question intent/evidence and Ask Cecy | Relevant facts only; no history upload/conversation persistence; insufficient/unsupported routes tested |
| 8.8 | Cross-feature review and separately authorized synthetic endpoint smoke tests | Actual iOS results recorded; endpoint hardening and deferred baseline/device gates not mislabeled complete |

Original first-slice acceptance checklist (current implementation evidence is in PHASE_8_VALIDATION.md):

- [ ] Manual symptom entry works with AI disabled, declined, offline or failing.
- [ ] Opening screens does not send text; one user submission sends only `{task:"normalize_symptoms", context:{text:...}}`.
- [ ] Consent is durable and missing/old consent requires opt-in; disable/reset block further requests.
- [ ] Text/result limits, all 13 API values, optional severity, special ratings, duplicate conflicts and empty results are covered.
- [ ] AI suggestions remain unsaved until explicit confirmation; edited suggestions are exactly the committed records.
- [ ] Batch conflict/save failure cannot partially persist; ordinary retry preserves text/review; no duplicate records on double tap or relaunch.
- [ ] Dismiss/background/lock/logout/revocation/reset reject late responses and clear sensitive transient state.
- [ ] Original-note choice is visible, local-only and covered by existing export-note consent.
- [ ] Existing symptom, migration, privacy and reset checks relevant to the change run; failures are classified against the known deferred baseline, not hidden.

## 12. Test strategy and records

New test files staged with their features:

- `cecyTests/AIServiceTests.swift`: exact task strings, encoded task/context, all success/error envelopes, null/unknown/missing fields, status handling including 2xx failure and future 429, non-JSON/oversized data, finite numbers, Unicode/UTF-8 bounds, redirect rejection, timeout/cancel, no automatic retry, injected URLProtocol transport and no real endpoint use.
- `cecyTests/AISymptomTests.swift`: all mappings, null severity, sleep/energy direction, digestive case roundtrip/export/symbol, review edits, empty/duplicate/conflicting suggestions, selected date, notes limits, batch rollback/retry and confirmed relaunch persistence.
- `cecyTests/AIConsentTests.swift`: old preference decode preserving lock/reminders/appearance, durable grant/revoke failures, current notice version, stale callbacks, simultaneous submissions and all access/reset/logout paths. Mocks can deliberately ignore cancellation to prove generation checks.
- `cecyTests/AIContextBuilderTests.swift`: golden minimal payloads and negative checks for IDs, names, birth date, notes, sexual activity, raw periods/symptoms and HealthKit provenance; input facts immutable and wire keys confirmed per task.
- `cecyTests/CycleAIFactsTests.swift`: symptom/window counts vs observations, completed-cycle boundaries, unknown ends, sparse/irregular histories, no missing-log absence inference, DST/leap/travel, edited/deleted source invalidation and unchanged existing insight outputs.
- `cecyTests/AIWellnessTests.swift`: required preference availability, legacy profile JSON, explicit empty vs unknown allergies, goals/wire mapping, current-day symptoms, omitted phase and severe symptoms with nil safetyMessage.
- `cecyUITests/PhaseEightUITests.swift`: isolated mock service, consent decline/grant/relaunch/revoke, describe→review→edit→save→relaunch, cancel/no-write, timeout/manual fallback, duplicate conflicts and sheet privacy/accessibility. Add later-feature focused flows only with their implementation.

Use synthetic fixtures, fixed clocks and isolated stores. No live endpoint calls from unit/UI tests or previews. A few explicitly authorized manual integration checks can use synthetic payloads against the existing service; record task/status/timing without storing raw health-bearing request/response logs. Verify iPhone/iPad, Dynamic Type, VoiceOver and actual privacy shield on signed devices before release.

Create `PHASE_8_VALIDATION.md` when implementation/testing begins, recording each real build/test result, known baseline failures and unperformed checks separately. Backend-reported tests do not establish iOS acceptance. This planning review changes documentation only; no tests/builds or deployed-service requests were performed.
