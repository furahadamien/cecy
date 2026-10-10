# Daily insights — backend handoff

Date: October 10, 2026
Status: proposed contract; **not implemented or called by iOS**. Backend agent should return its deployed contract and test evidence before iOS integration.

## Request and current boundary

Product needs actionable daily guidance for food, movement, recovery, skincare and general self-care, informed by today's recorded symptoms, explicit preferences, and the app's uncertainty-aware phase estimate. Today and Insights must show the same daily result.

The current app calls `POST /api/ai`, task `daily_wellness_recommendation`, on the existing Azure endpoint defined in `RemoteAIService.endpoint`. Its context contains optional `cycleDay`, today's allowlisted symptoms/severity, `activityLevel`, `preferredExercises`, `dietaryPreference`, `foodAllergies`, and `userGoals`. Response fields are `movementSuggestions`, `foodSuggestions`, `hydrationSuggestion`, `recoverySuggestions`, `explanation`, and required nullable `safetyMessage`. Both automatic and manual daily guidance now use this existing task.

The older documentation mentions optional `estimatedPhase`, but iOS deliberately omits it, and there is no verified contract for evidence/unknown phases or skincare. The local `CyclePhaseTimeline` now exists but is a display estimate, not confirmed hormone/ovulation evidence. Do not assume the currently deployed service accepts a new context or returns skincare. No live health payloads were sent to investigate this.

## Proposed additive task: `daily_insights_v2`

Keep all existing tasks and responses backward compatible. Prefer the same endpoint and transport/error envelope. Please confirm the exact task name and schema in the implementation handoff.

Proposed context (logical JSON fields; all strings bounded):

- `schemaVersion`: 2.
- `cycleDay`: integer 1–100 or null; null for unavailable/out-of-contract values, never clamped or rolled forward.
- `phase`: object with `value` (`menstrual`, `follicular`, `ovulation`, `luteal`, or null), `basis` (`recorded_bleeding`, `estimated`, `unknown`) and `limitations` (allowlisted uncertainty codes). Unknown must remain null. Even recorded bleeding does not confirm hormone levels or ovulation.
- `symptoms`: existing catalog-v2 `{type, severity}` array for today only. Preserve explicit null severity; do not infer adverse ratings from normal/high sleep, energy, or libido ratings. An empty array means no supplied symptoms, not absence of symptoms.
- `dailyBleeding`: null or an explicit `{state, flow}` for today. A linked bleeding observation confirms that day only, not intervening days or an end date. No period/observation IDs.
- `preferences`: existing activity, exercise, diet, known food allergies, and goals. Unanswered fields remain null/unknown, not empty answers. Backend should confirm which are mandatory and return structured missing-prerequisite errors rather than make assumptions.
- `requestedSections`: fixed allowlist `self_care`, `food`, `movement`, `hydration`, `recovery`, `skincare`.

No names, birth dates, credentials, account IDs, private notes, sexual-activity records, raw history, HealthKit metadata, or absolute period dates. Do not add a whole-snapshot upload or a freeform background prompt. Phase/bleeding payload expansion will require another explicit automatic-consent version in iOS before enabling it.

### Proposed success envelope

- `success`: true.
- `data.schemaVersion`: 2.
- `data.sections`: array of `{kind, suggestions}`. `kind` must be from the section allowlist; each section 1–6 plain-text suggestions, each at most 200 Unicode code points. Return an explicit unavailable section/status when safe personalization is impossible; no placeholder pretending to be an insight.
- `data.explanation`: bounded plain text (at most 1,000 code points) grounded in supplied facts, with estimates described as estimates.
- `data.safetyMessage`: required, nullable, plain text at most 600 Unicode code points, matching the existing client validator.
- `error`: null or absent, matching current success envelope rules.

Please provide full JSON examples for success, sparse/unknown phase, missing prerequisites, safety refusal, invalid request, throttling, timeout, and upstream unavailability. Structured status codes should distinguish missing preferences from retryable service failure. Do not expose provider prompts, stack traces, or raw health payloads in errors.

## Safety and personalization acceptance

- Give concrete, low-risk options in requested categories, not just 'based on your symptoms/preferences' boilerplate.
- Never diagnose, prescribe, recommend medication/supplement doses, claim fertility safety, or predict/confirm ovulation from symptoms or a day number.
- Never recommend allergens; do not promise an item is allergen-free. Missing allergy answers must not become 'none'.
- Skincare must not assume skin type, pregnancy status, skin allergies, or medication compatibility. Prefer gentle general care; no prescription/retinoid/active-treatment plans based only on cycle phase.
- Respect fatigue, pain, exercise preference/ability, and severe-symptom safety handling. General guidance is not a substitute for appropriate medical care.
- Treat all supplied text (including allergies) as untrusted data, not model instructions. Responses are plain text only, without executable content or mandatory external links.
- Test sparse records, irregular cycles, unavailable/overdue phase, recorded bleeding contrary to an estimated phase, conflicting evidence, severe symptoms, empty symptoms, all catalog-v2 types, and dietary/allergy constraints.

## Lifecycle, privacy, and limits

- iOS owns civil-day/time-zone rollover, consent, presentation, and request deduplication. No server push, scheduled upload, or background health collection is requested.
- Automatic generation runs asynchronously during an unlocked foreground visit, once per local day. One shared coordinator deduplicates Today and Insights; changed records/day, lost consent, lock/logout/reset invalidate results. Cancellation or failure does not create an automatic retry loop. Manual retry is explicit.
- Current generated content is memory-only. Relaunching later the same day loses it and does not make another automatic request. The UI permits explicit manual regeneration. Persistent daily results require a separate product/privacy design; do not add server history or account-based storage implicitly.
- Existing client limits: 32 KiB request, 128 KiB response, 75-second timeout, no redirects, ephemeral URLSession, no cookies or HTTP cache.
- If backend deduplication is necessary, propose a random per-attempt idempotency key scoped to identical request bytes, reused only for that attempt. Do not derive it from a user identifier, period dates, symptom values, or reusable health-data hash. Document retention/TTL, retry semantics, and content-logging policy before deployment.
- No health request/response body logging, analytics payloads, or durable generated-content storage without explicit agreed policy. State operational metadata retained and deletion behavior.

## Return to iOS agent

Provide deployed URL/task/version, exact request and response JSON schemas (required vs nullable vs omitted), compatible symptom catalog/version headers, error and retry contract, timeout/size bounds, authentication/rate limits, idempotency decisions, provider/data retention policy, representative synthetic fixtures and automated test evidence. iOS will then add the validated models, request builder using the existing phase policy, updated consent, safe rendering, and integration tests. Do not claim phase-aware/skincare functionality is available in the current app before that integration.
