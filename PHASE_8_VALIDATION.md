# Phase 8 — AI implementation and validation

October 1, 2026 · Branch `planning/phase-8-gpt`

## Authorization and current status

After the local prerequisites were reported complete, the user authorized all five handoff features. The earlier normalization-only stop-for-review instruction is superseded by that authorization. All five iOS paths are implemented; the continuation run passed all 62 focused unit/storage/transport tests and all four new UI scenarios together. Debug and a fresh unsigned iOS Release build passed. Live contract and release acceptance remain open. This is prototype integration, not release acceptance.

The existing Azure gateway is reused. No backend resources, credentials, model prompts, cloud database, chat store, AI-generated predictions, phase estimation or subscriptions were added. No live gateway requests have been made during this implementation. User-reported backend deployment tests are not client validation.

## Implemented paths

- **Describe symptoms:** Log symptoms → Describe how you feel. Explicit consent and submission, 1–2,000 characters, all 13 wire codes, editable type/rating review, optional original private note, one atomic confirmed batch save. Unknown/duplicate output fails closed. Empty suggestions offer editing/manual selection. Sleep/energy never convert AI severity into Good/High ratings. No write occurs merely on receiving a response.
- **Explain an observation:** Insights → Observations and patterns → Explain this observation. Locally generated insight and evidence remain authoritative; only metric/count/window aggregates are sent.
- **For today:** Today → Optional wellness suggestions. Requires explicitly answered local activity/exercise/diet/allergy/goals; only today’s qualifying symptoms are sent. Normal sleep/energy are not represented as adverse symptoms. Estimated phase is omitted. Local severe-symptom caution and allergy-verification copy do not depend on a server safetyMessage.
- **Cycle summary:** Insights → a completed interval with a confirmed bleeding end. Uses consecutive starts, actual inclusive duration, up to six historical intervals ending at the selected cycle, and bounded recorded-symptom observations. No profile-duration substitution or future-cycle leakage.
- **Ask about your records:** Insights → Ask about your records. User selects cycle intervals, symptom logged-day counts over 90 days, or timing in explicit windows near up to six eligible starts. Suggested prompts and bounded English wording are supported. Unsupported/ambiguous wording remains local and requests clarification; no broad history fallback. Timing evidence is shared with the deterministic insight engine, including honest zero recorded matches.

## Architecture, consent and privacy

- `AIModels`, `AIContextBuilder`, `AIService`/`RemoteAIService`, and `AIRequestCoordinator` separate wire contracts, local facts, transport and feature state from views. Existing local SwiftData V6/repository and atomic saves are unchanged.
- Optional versioned consent lives in existing protected preferences; missing/old consent means off. Grant must save before sending. Failed revocation blocks this session and explicitly asks the user to retry durable saving. Reset clears consent. Export/HealthKit/account permissions do not grant AI consent.
- Every request is explicit; enabling consent alone sends nothing. A single coordinator prevents concurrent duplicate submissions. Cancellation/generation checks clear requests/results on navigation, source publication/refresh, background/inactive, lock, logout, revocation and reset. Views discard sensitive transient drafts on invalidation.
- URLSession uses ephemeral configuration, no cookies/cache/credential store, JSON POST to the one HTTPS endpoint, no redirects, no client retries, 75-second request/resource bounds plus an independent coordinator watchdog, 32 KiB encoded request and 128 KiB streamed response limits. No raw request/response logging or raw server-error display.
- Generated strings render as plain text. No AI prose, summaries or conversations are persisted or exported. Only explicitly confirmed symptom records/optional notes enter existing local storage.

## Validation record

### October 1 continuation — consolidated focused run

- Rechecked the working branch and all five feature paths; no app-code changes were needed during this continuation.
- All **62 tests in eight unit/storage/transport suites** passed together with **4/4 PhaseEightUITests scenarios** in one invocation. Unit execution: 2.783 seconds. UI scenarios: read-only features 91.412 seconds; cancellation/background 41.691 seconds; consent/save/relaunch/revocation 71.769 seconds; network failure/manual fallback 48.188 seconds.
- Result bundle: `/tmp/cecy-ai-continuation/focused.xcresult`; build/test log: `/tmp/cecy-ai-continuation/focused.log`. Selected suites: AIModelTests, AIContextTests, AIConsentAndLifecycleTests, AIServiceTests, WellnessDomainTests, WellnessPersistenceTests, PhaseThreeDomainTests and PhaseThreePersistenceTests, plus PhaseEightUITests. Parallel testing was disabled; all AI data and responses were synthetic.
- Xcode reported **TEST SUCCEEDED**; the finalized result summary reports **66 passed, 0 failed, 0 skipped** (one parameterized test accounts for 67 device-level executions). Optional simulator diagnostic collection stalled after test completion; only that collector was stopped with SIGTERM. Xcode finalized normally and the result bundle is readable. Test logs/results are retained; the optional diagnostic archive may be incomplete.
- A fresh **unsigned iOS Release build passed**, using `generic/platform=iOS`, `CODE_SIGNING_ALLOWED=NO` and isolated derived data. Log: `/tmp/cecy-ai-continuation/release.log`. Its only warning was the nonblocking AppIntents metadata warning.
- This supersedes the earlier **across-reruns-only** limitation for these focused AI scenarios. It is not a full-app regression baseline, signed-device acceptance or a live gateway test.
- The test run still emitted the dynamic Form invalid-frame warning. Existing unrelated test warnings concern trailing-closure labels and a captured mutable value; no such warning was fixed or waived here. Device/layout acceptance remains open.
- The AI plan now maps the original proposals to actual files and records implemented prototype decisions, including initially unrated sleep/energy suggestions. Service-owner, privacy/medical and distribution reviews remain separate open gates.

### Earlier implementation evidence

Environment: Xcode 27.0 (27A266a), iPhone 17 Pro simulator / iOS 26.2. All automated data is synthetic and all AI responses use in-process fixtures or intercepted URLSession transport.

- Initial Debug build-for-testing passed (`/tmp/cecy-ai-build.log`). New actor-isolation warnings were subsequently corrected.
- **Final unsigned iOS Release build passed** (`generic/platform=iOS`, `CODE_SIGNING_ALLOWED=NO`), log `/tmp/cecy-ai-release.log`. No new app compiler warnings remain; Xcode emitted the nonblocking AppIntents metadata warning. This is not signed-device acceptance.
- First focused test invocation stopped at a Swift test attribute-order syntax error; fixed without changing assertions. Evidence: `/tmp/cecy-ai-unit.xcresult`.
- **62 tests in eight suites passed** against the final source in `/tmp/cecy-ai-confirmation-retry.xcresult` (2.527 seconds test execution). This includes **32 new AI tests** plus 30 symptom/wellness regressions. Earlier passing runs: 59 tests in `/tmp/cecy-ai-unit-2.xcresult`, then 61 in `/tmp/cecy-ai-validation-final.xcresult`. Tests cover all five request/response paths, error/size/timeout handling, taxonomy/rating mapping, durable consent/failures, pre-dispatch access revocation, watchdog timeout, non-cooperative late callbacks, minimal facts, unknown preferences, summary eligibility and atomic confirmed saves.
- **All four new UI scenarios have passing evidence across reruns**, not a single green four-test run. Four-read-only-feature and cancellation/background flows passed in `/tmp/cecy-ai-validation-final.xcresult`. Confirmation/save/relaunch/revocation/relaunch and failure/manual-fallback/save/relaunch passed **2/2** in `/tmp/cecy-ai-confirmation-retry.xcresult` (207.951 and 65.272 seconds). That final combined run also passed all 62 selected unit tests and reported TEST SUCCEEDED.
- The initial UI run was 1/4 passing (`/tmp/cecy-ai-ui.xcresult`), then 2/4. Automation fixes wait for consent dismissal, scroll the foreground Form, ignore covered tab bars, keep Today controls fully above the tab bar, and wait for the review header before scrolling to the lazily materialized Save row. Save and persistence assertions remain in place; no failing expectations were disabled.
- Simulator emitted an invalid-frame warning during dynamic Form updates. Functional evidence does not establish minimum-OS/device/layout acceptance; that gate remains open.
- Editor tooling exposed stale cloud-appearance content. Unrelated restored content was removed using verified on-disk source; cloud appearance is not part of this feature.

## Implementation adaptations

The planned separate feature-state/use-case files are consolidated into a shared request coordinator and `TrackerSession.performAI`; SwiftUI keeps only local editing drafts. Context/fact computation stays in the pure builder. One global in-flight request is intentionally stricter than per-feature concurrency. New domain/consent/context/lifecycle tests are grouped in `PhaseEightTests.swift`, with transport in `AIServiceTests.swift`. No new persistence schema, generated-output cache or conversation entity.

## Open gates and explicit limitations

- [x] Consolidated focused unit/UI evidence and a fresh unsigned Release build recorded above. All 62 focused tests and four AI UI scenarios passed together; this is not a clean full-app baseline.
- [ ] Synthetic end-to-end verification against the deployed endpoint remains unperformed. No backend schema/source was supplied. Non-example insight labels (`cycle_length_change`, `symptom_timing`, `period_length_change`), precise fact-key handling, exercise/diet/goal enums, and unspecified response bounds require service-owner/contract confirmation. Client failure remains recoverable; no claims of live compatibility for unverified shapes.
- [ ] Review provider retention, infrastructure logging, privacy-policy links/disclosures, and anonymous-endpoint abuse controls before distribution. Client gating is not authentication/rate limiting. No backend hardening implemented here.
- [ ] Minimum-OS, iPad, Dynamic Type, VoiceOver, layout, offline/slow live networking and signed-device privacy-shield/lock acceptance remain open.
- [ ] Historical full-suite regression and signed-device gates remain deferred, not waived. Earlier baseline: 113/114 unit and 19/30 UI tests passed; focused new passes cannot establish a clean full baseline.

Local question routing is intentionally limited, not a general multilingual intent engine. AI wording may be wrong despite structural validation; local facts remain visible. No medical diagnosis or fertility functionality is provided.
