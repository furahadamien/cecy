# Cecy — Expanded AI Symptom Catalog: Backend Agent Handoff

Date: October 6, 2026  
Audience: Agent maintaining Cecy's existing Azure Function AI service  
Requested return document: `AI_SYMPTOM_CATALOG_BACKEND_IMPLEMENTATION_HANDOFF.md`

## 1. Objective and authority

Extend the existing AI API to support all **39 symptom/observation types** available in Cecy's manual logging, while preserving compatibility with existing iOS clients that understand only **13 API types**.

This document describes verified iOS behavior and the requested backend contract. **The backend implementation, deployed schemas, prompts, and configuration have not been inspected here.** Items marked proposed are not claims about the deployed service.

Before editing, inspect the backend's actual routing, request validation, model prompts, structured-output schemas, response validation, tests, and operational controls. Identify conflicts with this document rather than assuming them away. Do not describe something as deployed or tested without evidence.

Implement and test in a backend branch. Production deployment requires the owner's approval. Return the implementation handoff in section 12 so the iOS agent can integrate against the actual final contract, not guesses.

### Non-goals and constraints

- Reuse the existing Azure Function and `/api/ai` route; do not introduce another backend.
- Do not add cloud symptom storage, sync, partner sharing, subscriptions, or user-registry changes.
- Deterministic cycle calculations, dates, phase boundaries, and statistical aggregates remain local to iOS.
- AI explains supplied evidence and proposes editable symptom classifications; it does not write local health records.
- Preserve existing manual/offline tracking, consent, cancellation, and failure behavior.
- Do not request entire histories, identities, HealthKit metadata, or automatic uploads of stored private notes.
- Do not broaden this task into a new chatbot, diagnostic service, or a new rating schema.
- Use synthetic data for tests. Do not send real user records to production to validate this change.

## 2. Verified iOS baseline

| Area | Current implementation |
|---|---|
| Manual catalog | 39 `SymptomKind` values across six categories |
| AI catalog | 13 `AISymptomType` values |
| Unsupported manual types | Excluded from several AI contexts, or rejected for symptom-specific questions/explanations |
| Unknown response type | Fails Swift enum decoding; the normalization result is rejected |
| Normalization response | `symptoms` array; each item has `type` and required, nullable `severity` |
| Normalization limit | At most 20 unique types per result |
| Save behavior | User reviews and explicitly saves; no automatic record creation |
| Existing negotiation | No catalog-version header is currently sent |
| Existing request envelope | `task` and `context` |

The current public endpoint is:

`https://cecyaiendpoints-gqdahecce6g7dufv.westus3-01.azurewebsites.net/api/ai`

Treat this as the client's configured URL, not evidence of the backend's current capabilities. No live requests were made to prepare this handoff.

### iOS source references

- `cecy/Domain/Symptoms.swift`: complete catalog, categories, rating labels, timing qualification.
- `cecy/Domain/AIModels.swift`: task names, enum mappings, request/response DTOs, limits, rating suggestions.
- `cecy/Domain/AIContextBuilder.swift`: operation-specific payloads, aggregate construction, filtering, question routing.
- `cecy/Services/AIService.swift`: envelope, HTTP transport, decoding, timeouts, error handling.
- `cecy/Features/AI/AISymptomEntryView.swift`: consented normalization, editable review, explicit saving.

Backend-only changes will NOT complete this feature. Section 10 describes the required later iOS work.

## 3. Canonical catalog

There are **13 existing API mappings plus 26 additions = 39 types**. Keep the existing mappings exactly as written. iOS storage identifiers are not API wire values and must not be globally renamed.

The new API values below are the requested contract. Confirm their final spelling in the return handoff. Categories are presentation metadata; do not add a mandatory category field to requests or responses.

### Pain and discomfort — 8 types

| Display name | iOS storage identifier | API value | Status |
|---|---|---|---|
| Cramps | `cramps` | `cramps` | Existing |
| Headache | `headache` | `headache` | Existing |
| Back pain | `backPain` | `back_pain` | Existing |
| Breast tenderness | `breastTenderness` | `breast_tenderness` | Existing |
| Pelvic pain | `pelvicPain` | `pelvic_pain` | Add |
| Joint pain | `jointPain` | `joint_pain` | Add |
| Muscle aches | `muscleAches` | `muscle_aches` | Add |
| Breast swelling | `breastSwelling` | `breast_swelling` | Add |

### Mood and focus — 7 types

| Display name | iOS storage identifier | API value | Status |
|---|---|---|---|
| Mood changes | `moodChanges` | `mood_change` | Existing |
| Anxiety | `anxiety` | `anxiety` | Add |
| Irritability | `irritability` | `irritability` | Add |
| Low mood | `lowMood` | `low_mood` | Add |
| Mood swings | `moodSwings` | `mood_swings` | Add |
| Difficulty concentrating | `difficultyConcentrating` | `difficulty_concentrating` | Add |
| Brain fog | `brainFog` | `brain_fog` | Add |

### Energy and sleep — 5 types

| Display name | iOS storage identifier | API value | Status |
|---|---|---|---|
| Fatigue | `fatigue` | `fatigue` | Existing |
| Sleep quality | `sleepQuality` | `sleep_change` | Existing |
| Energy level | `energyLevel` | `low_energy` | Existing |
| Difficulty sleeping | `insomnia` | `insomnia` | Add |
| Dizziness | `dizziness` | `dizziness` | Add |

`insomnia` is the code for the user's reported difficulty sleeping, not an AI diagnosis of an insomnia disorder.

### Digestion and appetite — 8 types

| Display name | iOS storage identifier | API value | Status |
|---|---|---|---|
| Bloating | `bloating` | `bloating` | Existing |
| Nausea | `nausea` | `nausea` | Existing |
| Cravings | `cravings` | `cravings` | Existing |
| Digestive changes | `digestiveChanges` | `digestive_change` | Existing |
| Constipation | `constipation` | `constipation` | Add |
| Diarrhea | `diarrhea` | `diarrhea` | Add |
| Appetite changes | `appetiteChanges` | `appetite_changes` | Add |
| Vomiting | `vomiting` | `vomiting` | Add |

### Skin and hair — 4 types

| Display name | iOS storage identifier | API value | Status |
|---|---|---|---|
| Acne | `acne` | `acne` | Existing |
| Oily skin | `oilySkin` | `oily_skin` | Add |
| Dry skin | `drySkin` | `dry_skin` | Add |
| Hair changes | `hairChanges` | `hair_changes` | Add |

### Other body changes — 7 types

| Display name | iOS storage identifier | API value | Status |
|---|---|---|---|
| Hot flashes | `hotFlashes` | `hot_flashes` | Add |
| Night sweats | `nightSweats` | `night_sweats` | Add |
| Discharge changes | `dischargeChanges` | `discharge_changes` | Add |
| Vaginal dryness | `vaginalDryness` | `vaginal_dryness` | Add |
| Vaginal itching | `vaginalItching` | `vaginal_itching` | Add |
| Urinary discomfort | `urinaryDiscomfort` | `urinary_discomfort` | Add |
| Sex drive | `libido` | `libido` | Add |

## 4. Compatibility and version negotiation

**Never return a new enum value to a legacy client.** The current app rejects such a response, even if all other fields are valid.

### Proposed minimal negotiation

Use the existing route and body envelope, with an optional request header:

- Header: `X-Cecy-Symptom-Catalog-Version`
- Absent header: legacy catalog, version 1.
- Value `1`: legacy catalog, version 1.
- Value `2`: expanded catalog, version 2.
- Unsupported/malformed version: a documented validation error, not an undocumented downgrade.

If the backend already has an appropriate versioning mechanism, propose how to reuse it and document the exact choice before the iOS update. Do not silently invent different names, nesting, or defaults.

| Rule | Version 1 | Version 2 |
|---|---|---|
| Allowed symptom codes | Existing 13 only | All 39 |
| Maximum normalized symptoms | Preserve current client-compatible maximum of 20 | Proposed maximum of 39 |
| Duplicate normalized types | Disallowed | Disallowed |
| Item shape | `type`, `severity` | Same shape |
| Unknown code handling | Validation failure | Validation failure |

- Use version-specific model-output schemas AND server-side response validation. Prompt instructions alone are not sufficient.
- New symptoms described by legacy clients must not leak v2 codes. Do not falsely relabel an unsupported symptom just to fit the legacy list.
- The catalog size is not a request to return every type: return only observations justified by the supplied text.
- Do not silently truncate over-limit output or persist partial results. Return the documented invalid-response error.
- Keep existing v1 request limits and response behavior compatible; report any stricter existing limits found in the backend.
- Catalog version is a compatibility setting, not authentication or authorization.

## 5. Operation-by-operation changes

The request remains an object containing `task` and the operation's `context`.

| Task | Current symptom-bearing fields | Required work |
|---|---|---|
| `normalize_symptoms` | Input: `context.text`. Output: `data.symptoms[].type` and `.severity` | Extend v2 vocabulary, examples, structured-output enum, and final response validation. |
| `explain_insight` | `context.facts.symptom` | Accept all v2 codes when present. Explain supplied metrics and timing evidence without recomputing it. |
| `daily_wellness_recommendation` | `context.symptoms[].type` and `.severity` | Accept the expanded catalog. Preserve allergy, preference, and medical-safety constraints. |
| `cycle_summary` | `context.commonSymptoms[]`; descriptive strings in `context.observations[]` | Accept v2 types. Keep supplied counts and measurements unchanged. |
| `answer_cycle_question` | `context.facts.symptom`; `context.facts.symptoms[].symptom`; aggregate descriptions in `facts.caveat` | Support both the single-symptom and multi-symptom forms, plus existing cycle-only/sparse-record forms. |

Automatic daily record insights already use `answer_cycle_question`; do not introduce a new daily-insights endpoint.

### Preserve existing result structures

The current client consumes a success envelope with `success: true` and `data`. It rejects a non-null error alongside a successful result. Preserve the backend's compatible error-null/omission convention and document it precisely.

| Task | Existing fields inside `data` |
|---|---|
| `normalize_symptoms` | `symptoms` |
| `explain_insight` | `title`, `explanation`, `supportingObservation`, `safetyMessage` |
| `daily_wellness_recommendation` | `movementSuggestions`, `foodSuggestions`, `hydrationSuggestion`, `recoverySuggestions`, `explanation`, `safetyMessage` |
| `cycle_summary` | `summary`, `highlights`, `safetyMessage` |
| `answer_cycle_question` | `answer`, `supportingFacts`, `safetyMessage` |

For all four non-normalization responses, `safetyMessage` is **required but nullable**. An omitted field fails current client validation. Normalization has no required `safetyMessage` field in its current result contract.

Do not make currently optional facts mandatory. Unknown measurements may be absent; they must not be filled with zero or a population average. A nullable safety field does not itself prove that a response is safe.

### Preserve error compatibility

The client reads failure details from `error.code` and `error.message`, alongside `success: false`. Currently recognized codes are:

- `INVALID_REQUEST`
- `UNSUPPORTED_TASK`
- `AI_UNAVAILABLE`
- `AI_RESPONSE_INVALID`
- `INTERNAL_ERROR`

HTTP 429 and 503 are also interpreted as unavailable. Return controlled, non-sensitive messages rather than provider stack traces. Document exact status/code combinations, including unsupported catalog versions, timeouts, and model-output failures. Do not add required client error codes without flagging the iOS dependency.

## 6. Rating and classification semantics

The item field `severity` must be present and contain `mild`, `moderate`, `severe`, or explicit JSON `null`. Do not omit it or use an empty string.

| Local observation | Local values 1 / 2 / 3 | AI handling for this expansion |
|---|---|---|
| Most symptoms | Mild / Moderate / Severe | Suggest severity only when supported by the text; otherwise null. |
| Sleep quality | Poor / Fair / Good | Not a severity scale. Keep normalization severity null; user selects a rating. |
| Energy level | Low / Typical / High | Not a severity scale. Keep normalization severity null; user selects a rating. |
| Sex drive | Low / Typical / High | Not a severity scale. Use `libido` with null severity; user selects a rating. |

The current iOS client already ignores suggested severity for sleep and energy. Its v2 update must extend that protection to libido.

- Do not treat high energy, good sleep, or high sex drive as severe symptoms.
- `low_energy` is a legacy adverse-observation code, not a generic encoding of all energy ratings. Do not silently change its meaning.
- Existing wellness contexts include sleep/energy observations only for an explicitly adverse local rating, with null severity. Preserve that boundary.
- For the minimal v2 wellness extension, use libido only as an explicitly low-rated observation with null severity, and explain that meaning in the task contract. Generic normalization of libido still requires user rating review. Do not infer the rating solely from the type code across tasks.
- Frequency counts of recorded ratings are not proof that those observations were adverse. Preserve contextual caveats.
- Local timing logic qualifies sleep, energy, and libido only when the local value is 1. The backend consumes those supplied aggregates; it must not independently derive timing.
- Extracting separate low/typical/high or poor/fair/good ratings automatically would require another explicit schema design. It is outside this minimal catalog expansion.

### Normalization behavior to specify and test

- Recognize negation: “No headache, but I feel dizzy” must not produce headache.
- Do not invent symptoms from silence, cycle day, or general descriptions of a phase.
- Avoid automatically emitting both a specific type and its umbrella type for the same statement. For example, constipation alone should not automatically add digestive changes.
- Distinguish breast tenderness from swelling, low mood from mood swings, fatigue from low energy, and sleep difficulty from a general sleep rating.
- Return multiple related types only when the description independently supports them. Document genuinely ambiguous mappings and use conservative results.
- An empty normalization array is a valid no-match result; the app already offers manual entry.
- Treat the user's text as data, not as instructions to override system rules or output schemas.

## 7. Safety, privacy, and operational boundaries

These values and descriptions are health-related information, not anonymous/non-sensitive data merely because names are absent.

- Do not log raw normalization text, questions, symptom arrays, private notes, or full request/response bodies. Audit telemetry/APM and exception paths as well as explicit application logging.
- Preserve existing authentication, rate limiting, abuse/cost controls, and secret handling. Report missing controls rather than pretending this catalog change fixes them.
- Do not embed credentials in fixtures, documentation, mobile configuration, or the return handoff.
- Do not introduce additional downstream services or redirect client health payloads.
- Keep model/provider retention and logging assumptions explicit. Configuration claims require evidence; do not promise zero retention without verifying it.
- Do not diagnose conditions or attribute every symptom to the menstrual cycle. Symptoms such as urinary discomfort, vaginal itching, dizziness, or vomiting may have unrelated causes.
- Do not assert pregnancy, confirmed ovulation, contraception safety, or confirmed fertile days.
- Preserve concise, appropriate safety handling for concerning symptoms and avoid unsafe reassurance or allergen-conflicting recommendations.
- Normalization currently returns classifications, not a clinical triage response. If safe handling would require a response-shape or UI change, flag it for agreement; do not silently claim an added field is displayed by current clients.

### Current client transport and output limits

| Constraint | Current client behavior |
|---|---|
| Normalization description | Nonblank, maximum 2,000 Swift characters |
| Question | Nonblank, maximum 100 Swift characters |
| Encoded request | Maximum 32,768 bytes |
| Response | Maximum 131,072 bytes |
| Request/resource timeout | 75 seconds |
| Redirects | Rejected |
| General response text | Nonblank, maximum 4,000 Swift characters per validated string |
| Explanation title | Maximum 300 Swift characters |
| Wellness movement/food/recovery lists | Maximum 6 items each |
| Summary highlights / question supporting facts | Maximum 20 items each |

Only the proposed v2 normalization item count changes from 20 to 39. Do not conflate it with limits on other lists. Audit symptom-bearing request-array limits for v2 so they do not retain a 13-type ceiling.

Swift character counts, backend string lengths, and UTF-8 byte counts can differ for Unicode. Include emoji/combining-character tests and document the actual validation semantics; do not assume these units are interchangeable.

Use an upstream timeout budget that leaves time to return a controlled response before the 75-second client deadline. Keep retries bounded; document timeout, retry, throttling, and cancellation behavior. Do not claim client cancellation guarantees immediate cancellation of provider work unless verified.

## 8. Backend implementation sequence

1. Inventory actual backend contract, prompts, validators, fixtures, and operating controls; report mismatches.
2. Establish regression fixtures for all five legacy operations before changing schemas.
3. Introduce catalog negotiation with a legacy default and a canonical versioned catalog shared by validation and model schemas.
4. Add v2 codes to all applicable request schemas and version-specific normalization response schemas.
5. Update prompt definitions and examples, including ambiguous types and non-severity ratings.
6. Validate structured model output server-side; preserve envelopes, error codes, and bounds.
7. Add the acceptance tests below, run backend build/lint/unit/contract checks, and review the diff.
8. Supply synthetic fixtures and the return handoff. Distinguish implemented, tested, staged, and deployed states.
9. Deploy only with approval. Preserve legacy behavior while the iOS v2 integration is prepared and verified.

No health-data migration is expected. If the backend design introduces persistence or requires a database migration, stop and explain why before proceeding.

## 9. Acceptance criteria and evidence

Classify every item PASS / FAIL / PARTIAL / NOT TESTABLE, with evidence and next action.

- **CAT-01 — Exact catalog:** 39 v2 codes, 13 unchanged legacy codes; no missing or duplicate mappings.
- **CAT-02 — Compatibility:** Missing/explicit v1 negotiation preserves legacy behavior. v1 never returns new codes. Explicit v2 accepts the expanded catalog. Invalid versions fail as documented.
- **CAT-03 — Five operations:** Every applicable symptom-bearing field accepts every v2 code. Cycle-only, sparse-data, single-symptom, and multi-symptom requests still work.
- **CAT-04 — Normalization:** Unique types, explicit nullable severity, valid empty result, v1/v2 count boundaries, and rejection of unknown/malformed model output.
- **CAT-05 — Meaning:** Synthetic cases cover all 26 additions, negation, missing severity, overlapping concepts, non-severity ratings, and adversarial text.
- **CAT-06 — Safety:** Severe/concerning symptoms, unsupported diagnosis/fertility questions, allergy conflicts, and supplied-fact fidelity are evaluated. Separate deterministic schema checks from model-behavior evaluations.
- **CAT-07 — Failure behavior:** Invalid input, upstream outage, timeout, rate limiting, malformed output, and oversized payloads return documented controlled failures.
- **CAT-08 — Privacy/security:** Logging paths reviewed; no real health records or secrets in fixtures/artifacts; no new health-data persistence or downstream destination.
- **CAT-09 — Client fixtures:** Machine-readable synthetic request/response fixtures for each task and catalog version, including nullability and error cases, are delivered.
- **CAT-10 — Delivery:** Build/test results, deployment state, operational configuration, compatibility rollout, and rollback plan are documented.

Model tests must include representative wording, not just enum membership checks. Report which tests used mocked model output versus a real model in an approved test environment. Do not claim clinical accuracy from a small synthetic evaluation.

## 10. Later iOS work — not completed by the backend change

The iOS agent will use the final contract and fixtures to:

1. Expand `AISymptomType` and its bidirectional mappings to all agreed codes.
2. Send the agreed catalog version, without changing the endpoint unless explicitly agreed.
3. Update the v2 normalization count limit if the 39-item contract is adopted.
4. Extend `suggestedRating` and review guidance so libido cannot map severity to a low/typical/high rating.
5. Review all context builders: wellness, record insights, summaries, explanations, and single/multi-symptom questions. Adding enum values alone is insufficient for correct rating semantics.
6. Update local explanatory caveats and metric wording to include libido where appropriate. Preserve frequency-versus-adverse-rating distinctions.
7. Handle the question router's current `"sex"` blocked substring narrowly for supported sex-drive questions. Do not disable unrelated diagnosis/fertility/privacy restrictions.
8. Preserve consented, bounded payloads and explicit editable review before saving. Review whether existing consent wording adequately covers the expanded categories; do not assume symptom codes are non-sensitive.
9. Add mapping, payload, nullability, rating, version, count-limit, error, and UI regression tests using the returned fixtures.
10. Verify manual/offline behavior, no duplicate automatic requests, cancellation, and stale-response rejection.

No iOS symptom-storage rename or health-store migration is expected. Keep all existing `SymptomKind` raw values unchanged.

## 11. Rollout and rollback

- Deploy backward-compatible backend support before enabling v2 requests in iOS.
- Until the updated app explicitly opts in, production responses must remain legacy-compatible.
- Validate staging/approved integration fixtures before enabling the updated client.
- After v2 clients are distributed, do not roll back to a server that falsely advertises v2 or silently returns an incompatible catalog. Retain v2 compatibility or return a controlled unavailable/unsupported response so the app can fall back to manual entry.
- Record exact supported client/catalog combinations and any operational feature flags. Do not invent an iOS remote kill switch that does not exist.
- Do not describe a merge or successful build as proof of production deployment or end-to-end iOS compatibility.

## 12. Mandatory backend return handoff

Create **`AI_SYMPTOM_CATALOG_BACKEND_IMPLEMENTATION_HANDOFF.md`** and return it with the final schema and synthetic fixtures. It must contain enough information to implement iOS support without reverse-engineering prompts or guessing response shapes.

### A. Implementation identity and scope

- Repository, branch, commit SHA, PR/reference, completion date, and owner.
- Files/modules changed and what each change does.
- What was implemented, deliberately unchanged, deferred, or blocked.
- Source location or patch for the relevant final implementation, including schemas, version routing, catalog, validation, and prompts. Reference accessible repository paths/commits; do not include secrets or binary artifacts.

### B. Authoritative final contract

- Full endpoint URL(s), HTTP method, content type, and required headers for each environment.
- Exact catalog negotiation name, location, allowed values, default, and unsupported-version behavior.
- Exact 39-code catalog and iOS-to-wire mapping, highlighting deviations from this proposal.
- Final OpenAPI/JSON Schemas or equivalent machine-readable contract for every task and version.
- Required versus optional versus nullable fields, including whether extra fields are accepted.
- All array, text, byte-size, enum, and numerical constraints; Unicode length semantics.
- Whether normalization accepts 39 results in v2 and still enforces 20 for legacy clients.
- Definitive sleep, energy, libido, severity, and task-specific observation semantics.
- Whether categories exist only as metadata or affect any payload.

### C. Synthetic fixture package

Provide a fixtures folder, or accessible equivalent, with:

- A complete valid request and successful response for each of the five tasks under v1 and v2. Include the version header separately from the JSON body.
- Normalization examples covering all 26 added codes, the retained 13, null severity, empty results, duplicates, and count boundaries.
- Examples for low sex drive, high/unspecified sex drive, poor/good sleep, and low/high energy that demonstrate the agreed semantics without severity coercion.
- Single-symptom and multi-symptom question examples, cycle-only facts, omitted unknown facts, and sparse-record handling.
- Failure examples with exact HTTP status, headers, and JSON envelope for invalid input/version, unsupported task, unknown type, model-output failure, rate limiting, and timeout.
- Expected parser outcomes and expected normalized types/ratings. Distinguish recorded fixtures from illustrative examples.
- Only synthetic text and data; no access tokens, credentials, real notes, or real user records.

### D. Runtime, privacy, and security

- Provider/model identifier or deployment name, schema/prompt revision, and relevant generation settings.
- Server/provider timeout budgets, retry/backoff policy, rate-limit responses, and cancellation limitations.
- Existing authentication/authorization and abuse/cost controls, plus unresolved gaps.
- Logging and telemetry allowlists/redaction, including exception/APM behavior.
- Verified provider retention/configuration, server retention, and any uncertainty. If no application persistence was added, state that explicitly without making unsupported claims about provider retention.
- Required environment-variable and secret **names and purpose only**; identify the secure configuration mechanism. Never include secret values, signed URLs, private keys, or tokens.

### E. Validation evidence

- Commands executed, environment/runtime versions, dates, and tested commit.
- Build/lint/unit/contract/evaluation results and artifact locations.
- PASS / FAIL / PARTIAL / NOT TESTABLE for CAT-01 through CAT-10.
- Separate mocked tests, live-model staging tests, endpoint integration tests, and tests not executed.
- Known failures, flaky tests, coverage gaps, unresolved safety cases, and limitations.
- Evidence that old requests still work and cannot receive v2-only enums.

### F. Deployment and rollback state

- Explicit state: implemented only, deployed to staging, or deployed to production.
- For each deployment: URL/environment, revision, time, catalog support, and verification performed.
- Deployment commands/process and any owner approvals still required.
- Rollout order, flags/configuration, and rollback behavior after v2 clients exist.
- How iOS engineers can test safely without using production health data or embedding secrets.

### G. Actionable iOS integration checklist

- Exact header/body changes and confirmed response examples.
- Enum mappings and every changed validation limit/nullability rule.
- Required changes to rating suggestions, context builders, and question routing.
- Any consent/privacy considerations or errors the client must surface.
- Compatibility behavior when the backend is unavailable or a requested catalog is unsupported.
- Tests the iOS agent must add, with links to the matching fixtures.
- All deviations from this handoff and any product/technical decisions requiring approval.

End the return handoff with an explicit answer to:

> Is the backend ready for iOS v2 integration, and is it deployed anywhere? Which exact revision and contract should the iOS agent use, what remains blocked, and what must be verified before release?

Do not mark end-to-end integration or release acceptance complete until the updated iOS client has been built and tested against the final agreed contract.