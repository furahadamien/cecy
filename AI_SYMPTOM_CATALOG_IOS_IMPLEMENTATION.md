# Cecy — AI Symptom Catalog v2 iOS Integration

Date: October 6, 2026

Branch: `feature/cycle-phase-experience` (unchanged)

## Contract and evidence sources

Read the complete updated backend handoff at `/Users/furahadamien/Dev/CecyAI/AI_SYMPTOM_CATALOG_BACKEND_IMPLEMENTATION_HANDOFF.md`.

The backend agent reports production deployment and synthetic endpoint/model verification for revision `44af85ec5675389142bc77aa97b7bc47196f1871`. The local backend repository was at merge revision `fd7dc947293d3a5585750406e2190f0e0e78769d`; its catalog, request schemas, validation source, and fixture package had no differences from the deployed implementation revision.

This iOS work independently checked the source contract, fixtures, Unicode validation semantics, local transport behavior, and generated request bodies. It did not make live AI requests or independently repeat the backend's production/model evaluation. Backend deployment evidence is attributed to the supplied handoff, not claimed as a new iOS test result.

## Implemented

- All 39 symptom types map bidirectionally to the agreed wire identifiers. The existing 13 mappings and all local storage identifiers remain unchanged.
- Every operation sends `X-Cecy-Symptom-Catalog-Version: 2` to the existing endpoint, with the unchanged request envelope.
- Normalization permits up to 39 unique types. Unknown types, duplicates, omitted severity, and non-null severity on sleep/energy/sex-drive observations fail safely.
- Sleep, energy, and sex-drive observations never convert severity into a local rating. User review remains editable and saving remains explicit.
- Wellness sends these rating observations only when the local rating is explicitly low/poor, with null severity. High sex drive no longer triggers the local severe-symptom warning.
- Expanded types are available to explanations, wellness, summaries, daily record insights, and single/multi-symptom questions.
- Sex-drive question routing exempts only the selected observation phrase. Diagnosis, fertility, pregnancy, sexual-history, and unrelated-question restrictions remain in place.
- Added typed pre-dispatch validation for backend text, list, numeric, fact-object, and rating constraints. Invalid contexts are rejected locally without truncating facts or allergy lists.
- Normalization uses Unicode code-point limits, matching the inspected backend. The 100-character guided-question limit remains in place, with the backend's additional Unicode bound.
- Updated response bounds to the deployed contract, including eight summary highlights/supporting facts and required nullable safety messages.
- Preserved the 75-second transport timeout, response/request byte caps, cancellation, ephemeral transport, no redirects, no automatic downgrade, and no added retries.

## Payload correctness fixes required by the expanded catalog

The old automatic record-summary prompt was 101 characters, exceeding the client's 100-character question limit. It now asks the same bounded question more concisely.

The previous record-insights caveat combined every observation into one string. With 39 types this could exceed the backend's 500-code-point fact-value limit. Counts now use the backend's existing bounded fact-object structure:

- `recordedStarts`
- `confirmedBleedingDurations`
- `unknownBleedingEnds`
- `symptoms[]` with typed symptom codes, recorded-day counts, and window lengths
- `energyRatingDays` with separately labelled low/typical/high/unrated counts

Typical/high energy is not encoded as `low_energy`. Separate rating counts preserve those recorded facts without changing the legacy code's meaning.

Completed-cycle observation strings are packed into bounded strings without dropping symptom counts. Valid local cycles or bleeding durations outside the specialized summary endpoint's numeric ranges use the existing question/facts operation instead of clamping measurements. Wellness omits an out-of-contract optional cycle day rather than inventing one. Deterministic local calculations and stored records are unchanged.

## Consent and local-first behavior

The AI notice now explicitly identifies the expanded sensitive health categories and distinguishes them from automatically uploading stored private notes or sexual-activity records.

`AIConsentRecord.currentVersion` is now 2. A previously stored v1 consent does not authorize expanded requests. After renewal, daily preparation is off until the user separately enables it again; the existing once-per-day reservation remains intact. Failed consent writes cannot enable requests.

This is a consent renewal, not a health-store migration. Local records remain accessible and manual/offline tracking remains available. No SwiftData schema, user-registry, Apple identity, endpoint, provider, or backend-storage changes were made.

## Files/modules

Production changes:

- `cecy/Domain/Symptoms.swift`
- `cecy/Domain/AIModels.swift`
- `cecy/Domain/AIRequestValidation.swift` (new)
- `cecy/Domain/AIContextBuilder.swift`
- `cecy/Services/AIService.swift`
- `cecy/App/TrackerPrivacy.swift`
- `cecy/Features/AI/AISharedViews.swift`
- `cecy/Features/AI/AISymptomEntryView.swift`
- `cecy/Features/AI/AIFeatureView.swift`

Test/support changes:

- `cecy/Services/FixtureAIService.swift` (Debug-only synthetic catalog-v2 mode)
- `cecyTests/AICatalogV2Tests.swift` (new)
- `cecyTests/AIServiceTests.swift`
- `cecyTests/PhaseEightTests.swift`
- `cecyTests/CyclePhaseTests.swift`
- `cecyTests/DeviceFeedbackRoundFourTests.swift`
- `cecyTests/Fixtures/AICatalog/*.json` (new, test target only)
- `cecyUITests/PhaseEightUITests.swift`

The existing pending Calendar grouping, atomic day deletion, related tests, and outbound backend handoff were preserved. No branch switch, commit, or push was performed.

## Validation performed

| Check | Result | Evidence |
|---|---|---|
| Full unit suite | PASS | 328 tests reported in 61 suites; physical-device protection test explicitly skipped on Simulator. |
| Expanded normalization UI | PASS | New observations selected for review; sex drive initially Not rated; explicitly chosen High rating persisted after relaunch. |
| Consent/relaunch/revocation UI | PASS | Existing decline, consent, confirmed saving, reopening, and revocation scenario. |
| Failure/manual fallback UI | PASS | Request failure preserved the description and manual saving remained available. |
| Cancellation/background UI | PASS | Unsaved results were discarded and no automatic records appeared. |
| Fixture provenance | PASS | Extracted mappings, ten success envelopes, seven errors, and eleven expected evaluation-output sets matched the backend package. |
| Client/backend request contract | PASS | 161 iOS-generated synthetic v2 request bodies across all five operations passed the backend's actual `validateAIRequest` validator offline. |
| Catalog, rating and bounds | PASS | Full mappings, 39-result normalization, unknown/duplicate/missing-null handling, rating semantics, Unicode bounds, oversized fields, and safe question routing. |
| Privacy/lifecycle | PASS | Consent renewal/save failures, separate daily opt-in, no-consent calls, once-per-day behavior, cancellation, stale replies, explicit save, and allowlisted aggregate tests. |
| Simulator build | PASS | App and both test targets compiled. |
| Unsigned Release build | PASS | Generic iOS Release build succeeded with signing disabled. |
| Fixture exclusion | PASS | Catalog/evaluation JSON fixtures were absent from the Release application bundle. |
| Live endpoint/model/device acceptance | NOT TESTED HERE | Backend deployment tests are reported by the backend agent. No new live AI requests or physical-device acceptance were performed. |

Fixture files are deliberately labelled as extracted synthetic contract data. The evaluation-output test proves the client's ability to handle expected outputs, not the model's ability to infer those outputs from prose.

### Commands and artifacts

Final unit run:

`xcodebuild test -project cecy.xcodeproj -scheme cecy -destination 'platform=iOS Simulator,id=72FB373F-2A45-4446-BDEF-D14A8C82E04D' -derivedDataPath /tmp/cecy-calendar-symptoms-build -resultBundlePath /tmp/cecy-ai-v2-final-unit.xcresult -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:cecyTests`

Targeted UI run selected these methods from `cecyUITests/PhaseEightUITests`:

- `testExpandedCatalogReviewRequiresExplicitRatingAndSave`
- `testNetworkFailurePreservesDescriptionAndManualTracking`
- `testConsentDeclineConfirmSaveRelaunchAndRevoke`
- `testCancellationAndBackgroundDiscardUnsavedRequest`

Release build:

`xcodebuild build -project cecy.xcodeproj -scheme cecy -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/cecy-calendar-symptoms-build CODE_SIGNING_ALLOWED=NO`

Artifacts:

- `/tmp/cecy-ai-v2-unit.log` — first compile attempt; nested test-macro issue, corrected.
- `/tmp/cecy-ai-v2-validation.log` and `.xcresult` — all four UI cases passed; intermediate unit failures retained, not represented as a successful combined run.
- `/tmp/cecy-ai-v2-final-unit.log` and `.xcresult` — corrected full unit suite passed.
- `/tmp/cecy-ai-v2-release.log` — final unsigned Release build succeeded.
- `/tmp/cecy-ai-v2-contract.log` — 161 generated requests accepted by the backend validators.

Intermediate unit failures identified the 101-character prompt and stale assumptions about unsupported symptoms/free-text caveats. The final run retains equivalent fact, privacy, rating, and persistence assertions using the updated contract. The UI run preceded the final aggregate/prompt corrections; the final unit run and Release build include those corrections and the final explanatory copy.

## Remaining risks and next actions

- The handoff reports anonymous API access, no application quota/rate limit, and no raw-body edge size guard. These are inherited backend release risks, not fixed by the iOS catalog change.
- Provider retention and Azure telemetry configuration remain unverified. Do not claim zero retention or complete release acceptance.
- Backend safety evaluation is limited; real provider timeout/throttling/cancellation behavior is not independently verified here.
- Run approved end-to-end iOS/live-endpoint tests using synthetic data and physical-device accessibility/privacy checks before release. Do not use real health records for integration checks.
- Simulator emitted an invalid-frame warning during existing symptom navigation. The targeted tests passed, but the warning was not resolved or suppressed by this work.
- The non-blocking AppIntents metadata-extraction warning remains. The physical-device file-protection test cannot pass meaningfully on Simulator and was skipped explicitly.
- The complete UI suite was not rerun; only the four targeted AI scenarios were executed in this integration step.

Implementation and offline contract integration are complete. This is not a public-release sign-off.
