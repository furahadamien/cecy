# Cecy Product Readiness and Engineering Handoff

**Assessment date:** October 3, 2026  
**Release:** First public release — free, standalone iOS app  
**Status:** Evidence-limited handoff; not a launch sign-off  
**Provenance:** Saved from the product review and revised findings in the preceding chat. No new repository-wide or market review was performed while preparing this file.  
**Product code changes made during this task:** None

## Evidence and execution rules

- **E1 — Inspected source:** The supplied contents of `cecy/Features/Calendar/TrackerCalendarView.swift`.
- **E2 — Repository listing:** Supplied workspace file/directory names, plus a root-directory check when saving this document. Filenames alone do not establish implementation.
- **E3 — Owner requirements:** First-release scope, local-first storage, and the existing stateless Azure Function AI gateway.
- **E4 — Product inference:** Explicitly labeled hypotheses and recommendations, not observed customer behavior.

The earlier review did **not** inspect other source or document contents, Core Data models, prediction algorithms, AI services, or gateway code. No builds, tests, simulator/device checks, accessibility sessions, competitor research, community research, or customer studies were completed. File access became available for saving this document; that does not retrospectively validate the earlier review.

### Instructions to the receiving engineering agent

1. Preserve the approved free, standalone release scope.
2. Inspect current source and dependencies before changes; the supplied calendar snapshot may have changed.
3. Complete verification tasks before changing behavior that may already be correct. Unknown does not mean missing.
4. Do not redesign prediction, authentication, onboarding, or backend architecture based on an evidence gap.
5. Record each defect with reproduction, current/required behavior, impact, privacy implications, acceptance criteria, and regression tests.
6. Promote only confirmed material in-scope defects to P0; verification tasks are not automatically blockers.
7. Use synthetic health data. Do not put real records, prompts, or support attachments into test artifacts.
8. Close disproved concerns with evidence rather than unnecessary code changes.

## 1. Executive Summary

### Current state

Cecy is intended to be a free native iOS cycle and wellness tracker with on-device Core Data storage and optional AI through an existing stateless Azure Function gateway. Those architectural statements are owner-provided, not independently verified in the earlier review.

The inspected calendar implements date navigation, dated logging entry points, recorded-versus-estimated presentation, projected-cycle components, accessibility labels, and a large-text list layout. Completeness and correctness of the broader application remain unverified.

| Stage | Assessment |
|---|---|
| Internal testing | Appropriate next activity with synthetic data after a successful build; buildability has not been established. |
| External beta | Readiness undetermined. Verify record integrity, core task completion, privacy, and exposed AI safety first. |
| App Store launch | Not signed off. Insufficient evidence is not itself a product defect, but cannot establish readiness. |

### Strongest source-supported strengths

- Recorded and estimated events have distinct labels and treatments.
- Ovulation accessibility text identifies an unconfirmed calendar estimate.
- Later forecasts can disclose assumptions about unrecorded periods.
- Historical navigation and date-specific logging entry points exist.
- Calendar logging is disabled for future dates with an explanation.
- Accessibility adaptations are represented deliberately in the view.

### Largest remaining risks

Unverified risks include record integrity across edits/migrations/date changes; overstated prediction certainty; mismatched AI consent/payload/retention; failure of essential tasks offline or with accessibility settings; and inaccurate App Store disclosures.

**Confirmed P0 findings: zero.** This is not evidence that no blockers exist.

## 2. Current Product Scope

### Implemented in inspected source

- Monthly grid and accessible/narrow-screen list layouts.
- Previous/next month, Today, and Go to date controls.
- Selected-day details and period/symptom/sexual-activity record components.
- Logging entry points bound to the selected date; future logging disabled.
- Forecast markers, projected-cycle detail components, and conditional explanation sheet.
- Confirmation presentation/announcement and invocation of a prediction-progress modifier.

### Partially verified, not necessarily partially implemented

Logging, editing, persistence, forecast calculations/recalculation, prediction explanations, symptom presentation, progress behavior, and context warnings have references but uninspected underlying implementations. Do not classify them as incomplete without tracing them.

### Planned or unknown

Documentation names suggest onboarding, adaptive forecasting, wellness prerequisites, AI, support, and multiple feedback rounds. Their contents and completion are unknown. Sign in with Apple, notifications, profile management, export/deletion, and the named AI operations require inspection. No specific feature can honestly be labeled implemented or merely planned from those filenames alone.

### Explicit first-release constraints

- **Free, iOS-only, local-first.** Owner-declared Core Data storage and existing stateless Azure Function AI gateway.
- **No subscriptions, CloudKit, partner sharing, or cross-device sync requirement.**
- No Android, web, custom backend account, premium tier, paywall, or trial requirement.
- Existing authentication, if any, must be understood rather than replaced or expanded by assumption.

## 3. Target Customer

**Hypothesis, not validated segmentation:** Privacy-conscious iPhone users seeking straightforward period/symptom history and cautious estimates for everyday planning.

**Jobs-to-be-done:** Record with minimal effort; correct history confidently; distinguish what happened from what is predicted; review patterns without treating estimates as diagnoses; know when data leaves the device; continue basic tracking offline.

**Pain hypotheses:** Logging/correction friction, unclear certainty, distrust of sensitive-data processing, confusing irregular/incomplete histories, and unnecessary complexity around a simple task. No recurring customer-feedback pattern was established.

**Why this segment:** It aligns with a useful standalone product without household collaboration, cross-device identity, or clinically validated fertility detection. Do not position Cecy as contraception, confirmed ovulation detection, or treatment management without an appropriate evidence and regulatory basis. Irregular-cycle users need honest limitations, not exclusion or unsupported accuracy promises.

## 4. Product Positioning

**Problem:** Users need a dependable record and understandable estimates without inferred events becoming recorded facts.

**Potential wedge:** Low-friction recording + explicit uncertainty + transparent local-first privacy. Superiority and uniqueness are unvalidated.

> Cecy is a free iPhone cycle and wellness tracker that keeps your records clear, your estimates understandable, and your data handling transparent.

**Promises to verify:** Essential logging works offline; corrections preserve history and update dependent views; forecasts remain estimates; AI does not silently create or overwrite facts; outbound data processing is understandable; the free core works without subscriptions or synchronization.

Avoid “your data never leaves your phone” when AI or support can transmit it. Free alone is not a defensible differentiator. Keep AI secondary until its benefit is demonstrated.

| Alternative | Comparison needed | Evidence status |
|---|---|---|
| Flo | Free logging, insights, AI, privacy controls, commercial interruptions | Not researched; no superiority claim. |
| Clue | Scientific framing, uncertainty, irregular cycles, free functionality | Not researched. |
| Apple Health Cycle Tracking | Native logging/history, estimates, data controls | Essential baseline comparison, not researched. |
| Stardust | Tone, engagement, interpretation, privacy, prediction presentation | Not researched. |
| Period Calendar | Identify exact publisher/app; compare logging, ads, privacy, free scope | Product identity and behavior unverified. |
| Euki, Drip, other privacy-oriented apps | Recording simplicity, privacy promises, platform/recovery tradeoffs | Research candidates only. |

**Why choose Cecy — hypothesis:** A calm, transparent way to record privately. **Why stay — hypothesis:** Dependable records, easy corrections, useful history over multiple cycles, and estimates that acknowledge uncertainty rather than overpromise.

## 5. Market and Competitive Findings

No external sources were retrieved. There are no verified current competitor strengths/weaknesses, prices, privacy comparisons, recurring complaints, community patterns, or switching/abandonment findings in this review.

| Topic | Evidence to gather | Decision supported |
|---|---|---|
| Irregular cycles | Official limitations and independent user experiences | Whether Cecy addresses a meaningful unmet need. |
| Prediction accuracy | Accuracy definitions, uncertainty UI, contextualized complaints | Credible positioning, not unsupported accuracy claims. |
| Privacy | Policies, processors, controls, disclosures | Precision and differentiation of Cecy's promise. |
| Logging friction | Task walkthroughs and corroborated feedback | Which workflow improvements matter. |
| Subscription fatigue | Current free restrictions and independent reports | Acquisition messaging, not monetization implementation. |
| AI expectations | Documented capabilities and real task examples | Whether AI reduces effort or adds trustworthy value. |
| Wellness expectations | Personalization, provenance, repetition, safety feedback | Whether recommendations deserve launch prominence. |
| Switching/abandonment | Interviews and corroborated community reports | Retention hypotheses and portability demand. |

For each finding record URL, access date, platform/region, source type, and limitations. Separate official documentation, direct observation, recurring independent qualitative feedback, isolated complaints, and inference. Public reviews are not population-prevalence estimates. No research task should delay fixing an already-reproduced safety or data-loss defect.

## 6. Customer Workflow Review

Unknown means uninspected, not absent. No missing state below is asserted as a confirmed defect.

| Workflow | Current behavior/evidence | Friction, missing states, risks to verify | Recommended action |
|---|---|---|---|
| First launch | Unknown | Failure, unclear value, network dependency | Clean-install and offline launch checks. |
| Onboarding | Document/test names only | Optionality, incomplete history, interruption | Trace steps and persisted resume boundaries. |
| Sign in with Apple | Unknown | Requirement, cancellation, association with records | Determine presence/purpose; do not add login. |
| Historical periods | Calendar selects past dates and routes logging | Overlaps, validation, wrong date, persistence | Test through save/relaunch/forecast update. |
| Initial prediction | Forecast consumers exist | Cold-start requirements/unavailable state | Trace eligibility and informative no-estimate state. |
| Today/Home | Unknown | Discoverability, empty/loading states | Verify first value and return-use journey. |
| New period | `onLog(selection)` entry point | Form, cancellation, save failure, false confirmation | Verify success/cancel/failure end to end. |
| Editing period history | Record-summary component | Edit/delete semantics and recalculation | Trace controls and dependent refresh. |
| Symptoms | Dated log and record components | Severity, correction, duplicates, failed save | Verify manual recording end to end. |
| Sexual activity | Dated entry/records/markers | Sensitive disclosure, correction, persistence | Verify local record handling and support/AI exclusions. |
| Natural-language symptoms | Named capability only | Ambiguity, confirmation, unsupported terms | Inspect extraction and write-back boundaries. |
| Calendar | Supplied source inspected | List actions after month; interpretation untested | Targeted accessibility/comprehension checks. |
| Insights | Unknown | Evidence basis, sparse data, freshness | Trace insight to deterministic inputs. |
| AI explanations | Explanation component reference; AI use not established | Could be deterministic; failures unknown | Inspect before categorizing as AI. |
| Wellness | Unknown | Prerequisites, allergy/severity safeguards | Verify actual claimed personalization and safety. |
| Cycle summaries | Named capability only | Invented events or unsupported conclusions | Compare outputs with synthetic facts. |
| Cycle questions | Named capability only | False certainty and missing context | Test boundaries and safe recovery. |
| Profile information | Unknown | Persistence and recommendation updates | Identify fields and actual consumers. |
| Notifications | Unknown | Denial, stale dates, lock-screen content | If present, test denial/rescheduling/privacy. |
| Contact support | Document/test names only | Attachments, diagnostics, cancellation | Inspect payload and user initiation. |
| Network/AI failure | Service uninspected | Lost input, infinite loading, duplicate retry | Inject offline/timeout/429/5xx/cancel/retry. |

Do not implement an absent optional workflow merely because it appears in this table.

## 7. Prediction and Cycle Intelligence Review

**Source observations:** Records and forecasts are separate in the calendar; ovulation is described as unconfirmed; later projections can disclose assumed periods; supplied context warnings are appended. The explanation control is gated by `overview.estimate.contains(selection)`, while other projected-cycle components may already explain later estimates.

| Dimension | Verification requirement |
|---|---|
| Period starts/ranges | Trace algorithm, input validation, range construction, supported dates, update triggers. |
| Confidence | Establish meaning and calibration if present; do not invent confidence percentages. |
| Ovulation/fertile windows | Remain inferred; never persist/display them as confirmed observations. |
| Irregular cycles | Test variable history and context flags against actual model rules. |
| Outliers | Identify exclusion/weighting rules and explainability. |
| Cold start | Verify zero, one, and insufficient usable intervals. |
| Learning over time | Additions/corrections update results without fabricating missed periods. |
| Recent vs long-term | Inspect actual weighting/window. Explanation `suffix(6)` is not proof of training-window length. |
| Uncertainty | Review current/later projections, visible guidance, VoiceOver, warning discoverability. |
| Recorded vs inferred | Forecast generation must not create persisted observations. |

**Confirmed misleading behavior: none established.** Computational correctness is not clinical or predictive accuracy. Do not modify the model based solely on a view or promise superior irregular-cycle prediction without evidence.

## 8. AI Product Review

> Deterministic systems establish facts. AI explains, summarizes, interprets natural language, and personalizes.

All five implementations/contracts are unverified. Their names do not establish that they ship.

| Capability | Potential customer value | UX/failure requirements | Privacy/safety | Launch decision |
|---|---|---|---|---|
| `normalize_symptoms` | Less entry effort | Preserve input on failure; editable proposed entries; cancel; confirmation before save | Minimize text/context; no invented date, severity, symptom | Existing verified implementation may ship; manual logging is sufficient for core value. |
| `explain_insight` | Understand a computed insight | Keep deterministic fact visible; failure does not remove it | No altered values or unsupported causation | Existing safe implementation may ship; no new infrastructure requirement. |
| `daily_wellness_recommendation` | Relevant practical suggestions | Respect prerequisites; declined/unavailable AI does not block tracking | No diagnosis, unsafe reassurance, incompatible personalized advice | Only after safety verification; no scope expansion. |
| `cycle_summary` | Easier history review | Separate facts, estimates, unknowns; usable failure state | No invented events or diagnosis | Existing validated capability may ship; not essential to recording. |
| `answer_cycle_question` | Explain records/general concepts | Handle missing context, unsupported requests, cancellation, errors | No contraceptive assurance or confirmed ovulation inference | Highest open-ended exposure; retain only with verified boundaries. |

Shared checks: consent and actual payloads; schema validation; downstream logging/retention; timeouts/cancellation/retry; rate/abuse/token controls; aggregate cost visibility without health content. Local tasks must remain independent of AI availability. Start with mocks and synthetic inputs. Obtain authorization for live cost-incurring tests. Do not solve operating costs by automatically introducing accounts or subscriptions.

## 9. Wellness Recommendation Review

Implementation is unverified. These are checks for existing exposed functionality, not automatic feature additions.

| Area | Required check |
|---|---|
| Food | General wellness guidance, not treatment claims. |
| Exercise | Respect known preferences; no pressure to exercise through concerning symptoms. |
| Hydration | Avoid unjustified personalized quantities or universal medical claims. |
| Recovery | Rest is valid; predicted phase does not determine physical capability. |
| Severity | Concerning symptoms do not receive routine reassurance in place of appropriate care guidance. |
| Phase | Label estimated phase; do not imply measured hormonal state. |
| Allergies | If personalization is claimed, enforce known exclusions reliably; disclaimer alone is insufficient. |
| Activity preferences | Verify inputs affect recommendations where promised. |
| Dietary preferences | Verify supported preferences/changes without inventing restrictions. |
| Safety messaging | Proportionate, understandable; qualified review for medical escalation content. |

No confirmed pre-release defect is established. If unsafe behavior is demonstrated, correct it or withhold that optional surface while retaining core tracking. Do not add sensitive profile collection automatically; narrowing claims/content can be safer and simpler.

## 10. Privacy and Trust Review

| Data/behavior | Current evidence | Required verification |
|---|---|---|
| Periods, symptoms, activity | Owner-declared on-device storage | Model, protection, backup, network flow. |
| AI prompts/context | Owner-declared gateway | Fields, consent timing, purpose, processor retention. |
| AI outputs | Storage unknown | Cache/persistence/deletion behavior. |
| Sign in with Apple | Unknown | Purpose, scopes, linkage, cancellation, stored identity. |
| Support | Unknown | Route, diagnostics, attachments, preview/consent. |
| Analytics/crash reports | Unknown | SDKs, identifiers, captured fields, retention. |
| Delete/export | Unknown | Actual controls, scope, failures, explanations. |

Trust requirements:

- Distinguish local records from optional remote processing.
- Explain device loss, uninstall, and OS backup accurately. No CloudKit does not prove no backup.
- A stateless gateway does not prove zero retention in logs or downstream providers.
- Do not silently attach databases, health records, or prompt history to support.
- Existing export must make destination/sensitivity explicit; existing deletion must describe actual scope and external limitations.
- If account creation exists, verify applicable current Apple deletion requirements; do not add an account system.
- No sensitive content or stable cross-service identity merely for measurement.

These are verification requirements, not findings that current disclosures are deficient.

## 11. Reliability and Performance Review

| Area | Check |
|---|---|
| Launch | Clean/returning launch on deployment-floor and current supported OS. |
| Core Data | Save failures, relationships, corrections/deletion, relaunch, applicable migrations. |
| Long history | Synthetic ten-year history and dense symptoms; correctness and responsiveness. |
| Calendar | Profile grid/list. Repeated snapshot filtering is a lead, not a demonstrated bottleneck. |
| Recalculation | Consistent refresh after changes; old results cannot overwrite newer state. |
| AI latency/loading | Visible activity, functional cancellation, terminal states clear loading. |
| Timeout | Inspect configured deadline; injected expiry reaches recoverable state within one second of callback. |
| Offline | Local logging/history work; AI unavailable state does not block them. |
| Interrupted onboarding | Safe resume/restart without duplicates. |
| Failed authentication | If present, no false authenticated state or record loss. |
| Failed AI/retry | Preserve input; no duplicated observations. |
| Restoration | Background/termination do not corrupt saved state; unsaved behavior explicit. |
| Migration | Test actual supported paths; never silently replace a failed store with an empty one. |

**Proposed internal target, not measured or automatically P0:** On a documented representative supported device with ten years of synthetic history, p95 calendar navigation response at most 250 ms over 30 warmed interactions. If unsuitable, record an evidence-based replacement target and obtain approval. Avoid speculative optimization.

## 12. Accessibility Review

Source accommodations include accessible-size list layout, explicit 44-point treatments on several controls, full-date labels, selected traits, headers, confirmation announcement, and non-color estimate distinctions. These do not establish runtime accessibility.

- **Dynamic Type:** Smallest through largest sizes; essential actions and decision text remain accessible.
- **VoiceOver:** Select date, log, correct, cancel, interpret forecasts, recover from errors.
- **Contrast:** Measure actual light/dark combinations; use WCAG AA 4.5:1 normal text, 3:1 large text and essential non-text controls as a baseline, documenting applicability/exceptions.
- **Tap targets:** Verify rendered essential hit regions are at least 44 by 44 points, not merely declared modifiers.
- **Reduced Motion:** Inspect relevant animation behavior with the setting enabled.
- **Keyboard:** Fields and actions remain reachable with software/hardware keyboards.
- **Date controls:** Locale, month/leap boundaries, accessible picker confirmation.
- **Errors:** Visible, persistent enough to act on, accessible state; not transient announcement only.
- **Color dependence:** Recorded/estimated distinctions survive grayscale and VoiceOver.
- **Labels:** Action, date, state, destination are understandable.

Accessible-list logging placement remains a conditional concern, not a confirmed failure.

## 13. App Store Launch Readiness

All items are unverified. Check current Apple guidance before submission; this is not compliance certification.

| Item | Completion evidence |
|---|---|
| App icon | Valid release icon assets, no placeholders. |
| Display name | Installed/listed names match approved branding. |
| Screenshots | Shipped UI, synthetic data, required sizes, no deferred claims. |
| Description | Accurate free scope, local-first processing, estimate/AI limitations. |
| Keywords | Relevant, nonmisleading, current App Store Connect limits. |
| Privacy policy | Public HTTPS page describing actual categories, purposes, processors, retention, controls, contact. |
| Support URL | Working publicly, usable without an app account. |
| Support email | Monitored address; test request/response route. |
| App Privacy | Reconciled with app, SDK, gateway, support, downstream processing. |
| Health disclosures | No unsupported clinical, diagnostic, fertility-confirmation, contraceptive claims. |
| AI disclosures | Explain actual remote processing and applicable consent requirements. |
| Age rating | Reflect actual content, open-ended AI, supported audience. |
| Sign in with Apple | Determine applicability from implemented authentication; do not add login unnecessarily. |
| Account deletion | If account creation exists, verify current applicable requirements. |
| Privacy manifests | Applicable required-reason API and third-party SDK declarations. |
| Permissions | Accurate purpose strings and denial recovery. |
| Release configuration | Correct endpoint/environment, entitlements/signing/target; no debug bypasses. |
| Review access | Accurate local-use/AI instructions; credentials only if genuinely needed. |
| Metadata | Version/categories/rating/URLs/screenshots/reviewer notes complete. |

## 14. Product Analytics Plan

Prefer local counters, voluntary research, and aggregate operations. Usage metadata itself can be sensitive. No generic analytics with health values, exact cycle dates, sexual activity, prompts, or AI outputs. No accounts, sync, or cross-service identifiers required. Inspect existing instrumentation first. New behavioral analytics is P2.

| Metric | Why | Event definition | Safe measurement approach |
|---|---|---|---|
| Onboarding completion | Activation friction | First usable core screen after setup | Local flag; optional aggregate without answers. |
| Historical entry | Setup value | First historical period successfully saved | Local Boolean; no dates/intervals uploaded. |
| First prediction | Time to estimate | First valid deterministic forecast | Local flag; no predicted dates/confidence upload. |
| First symptom | Core engagement | First confirmed symptom save | Local flag; no identity/severity. |
| First AI use | AI adoption | First successful user-initiated response | Aggregate operation outcome only. |
| Insight engagement | Discovery/value | Rendered insight detail opened | Optional coarse count without content. |
| Wellness engagement | Relevance | Recommendation expanded/explicitly rated | Optional aggregate without recommendation/context. |
| Cycle completion | Repeat recording | Domain identifies completed interval | Keep local by default; voluntary summary only. |
| Retention | Sustained value | Later 30/60/90-day active windows plus multi-cycle research | Local summary or consented panel; no exact timeline. |
| Support usage | Friction/trust | Support initiated, not assumed delivered | Local count; voluntary categories. |
| Abandonment | Task friction | Entered flow left without completion | Coarse count, no draft; cancellation distinguished. |
| AI utility | Benefit vs activity | Helpfulness or reviewed extraction acceptance | Aggregate outcome, no extracted facts. |
| AI cost/reliability | Free-service sustainability | Requests/tokens/latency/errors by operation | Content-free gateway aggregates. |
| Trust/recommendation | Confidence/advocacy | Optional survey after meaningful use | Separate from records, voluntary, not coercive. |

Each metric needs a decision owner, minimal field allowlist, collection location, retention, and applicable consent. Daily streaks are not the primary success measure for a cycle-oriented app.

## 15. First-Release Scope

Required product experience: free native iOS core; local period/symptom records/history; correct record correction/deletion; usable setup and sparse-history states; clear recorded-vs-estimated calendar; eligible deterministic forecasts; honest ovulation/fertile-window limitations; offline essential tasks; accurate privacy/support; accessible essential workflows.

Existing optional AI/wellness may ship only with verified privacy, safety, and recovery. AI is not required to log or view history. Do not add optional capabilities simply to match this document.

Not automatically required: new login/accounts, import/export formats, more sophisticated prediction, additional reminders/content libraries, social mechanics, or clinical accuracy claims.

**Explicitly not launch blockers:** CloudKit, sync, partner sharing, subscriptions/paywalls/trials/premium, Android/web, custom backend accounts, advanced HealthKit.

## 16. Prioritized Product Backlog

- **P0:** Confirmed material safety/privacy harm, data loss, broken essential workflow, materially misleading guidance, or concrete App Review obstacle within first-release scope.
- **P1:** Important launch-quality work or targeted verification of an in-scope risk. Verification is not a confirmed defect or automatic release veto.
- **P2:** Safely deferrable refinement/research.
- **P3:** Longer-term opportunity requiring evidence and dependencies.

**P0 backlog is empty.** Sections 16 and 18 together form each task's canonical specification; Section 18 contains acceptance and testing requirements. Complexity estimates cover verification/decision work; estimate discovered fixes separately.

| ID | Title | Problem/customer impact | Required behavior and reason | Priority | Complexity | Dependencies |
|---|---|---|---|---|---|---|
| CE-01 | Establish implementation evidence | Unsupported assumptions misdirect work | Map source/docs/tests/data before changes | P1 | Medium | Repository access |
| CE-02 | Verify records/predictions | Wrong/lost facts undermine core value | Test persistence and deterministic invariants | P1 | Large | CE-01 |
| CE-03 | Verify AI/wellness/privacy | Disclosure or unsafe output harms trust | Trace flows; test consent/contracts/recovery | P1 | Large | CE-01; gateway evidence |
| CE-04 | Verify core completion | Users may not reach first value | Test implemented workflow states | P1 | Medium | CE-01; CE-02 persistence |
| CE-05 | Resolve calendar uncertainty | Logging or forecasts may be hard to use | Test specific source concerns; conditional smallest fix | P1 | Medium | CE-01, CE-02 |
| CE-06 | Verify runtime/accessibility | Failure or exclusion blocks customers | Device/offline/lifecycle/performance/accessibility checks | P1 | Large | CE-01; final CE-02–05 regression |
| CE-07 | Reconcile release/disclosures | Incorrect claims or submission failure | Evidence App Store checklist | P1 | Medium | CE-01, CE-03; final CE-06 |
| CE-08 | Validate customer/wedge | Positioning may attract wrong needs | Dated research and exploratory task feedback | P2 | Medium | Research access |
| CE-09 | Decision-linked measurement | Overcollection hurts privacy | Existing metrics first; minimal approved additions | P2 | Medium | CE-01, CE-03 |
| CE-10 | Test calendar comprehension | Density may not equal confusion | Structured tasks before redesign | P2 | Small | CE-05; participants |
| CE-11 | Reassess opportunities | Expansion dilutes core | Evidence-based decisions, not implementation | P3 | Small | Post-launch evidence |

## 17. Launch Definition of Done

1. Reproducible release build succeeds for supported deployment targets.
2. Essential setup, logging, correction, history, and calendar journeys pass.
3. Saved data survives relaunch and applicable supported upgrades correctly.
4. Forecasts are reproducible from inputs and remain separate from records.
5. No unsupported confirmed-ovulation or contraceptive assurance appears.
6. AI cannot silently persist extracted observations or alter deterministic facts.
7. Actual remote processing/retention and consent match disclosures.
8. Core tracking remains usable offline and during AI failure.
9. Essential journeys work with large text and VoiceOver.
10. Support/privacy URLs work and metadata matches the release build.
11. Confirmed P0 defects are closed and regression-tested.
12. Remaining P1 findings have fixes or explicit documented release decisions with user-impact rationale.

Product-market fit, arbitrary analytics volume, deferred features, and proving absence of every conceivable risk are not launch gates.

## 18. Engineering Handoff

### Common task requirements

Record commit/configuration/device/OS and evidence location. Use synthetic data and existing tests where useful. Separate inspection from execution. A concern disproved by evidence requires no product change. Any newly discovered fix needs its own explicit behavior, scope, estimate, privacy impact, acceptance criteria, and tests; this handoff does not authorize a broad rewrite.

### CE-01 — Establish actual implementation evidence

- **Priority / complexity:** P1 / Medium.
- **Customer problem:** Unsupported assumptions can displace actual launch risks.
- **Current behavior:** Only calendar source and listing reviewed.
- **Required behavior:** Commit-specific implemented/partial/planned/deferred map.
- **Scope:** Entry/navigation, definitions/call sites, phase/handoff/validation docs, tests, models/configuration, available gateway materials.
- **Out of scope:** Product changes or speculative architecture work.
- **Likely modules:** `App`, `Data`, `Domain`, `Features`, `Services`, `Shared`, `Persistence.swift`, model/project/test directories, root docs.
- **Dependencies:** Repository/build access.
- **Edge cases:** Stale docs, debug-only features, excluded tests, externally hosted gateway.
- **Acceptance:** Every Section 6 workflow mapped to sources/status; five AI operations traced or not found; data-flow claims verified/unresolved; schemes/targets and document conflicts identified; external evidence gaps explicit.
- **Unit tests:** Inventory suites and coverage; no claimed passes without execution.
- **UI tests:** Map tests to workflows.
- **Manual verification:** Synthetic launch/build or exact failure evidence.

### CE-02 — Verify local records and prediction correctness

- **Priority / complexity:** P1 / Large.
- **Customer problem:** Wrong dates, lost history, stale estimates destroy trust.
- **Current behavior:** `snapshot`, `cycleForecast`, `overview` consumed; internals uninspected.
- **Required behavior:** Correct persistent mutations and current deterministic forecasts separate from observations.
- **Scope:** Period/symptom/activity persistence, date arithmetic, edits/deletes, prerequisites/ranges/outliers/context, supported migrations.
- **Out of scope:** New model, clinical-accuracy claims, sync/recovery architecture.
- **Likely modules:** `TrackerSession`, `LocalDay`, record models/forms, Core Data, forecast services.
- **Dependencies:** CE-01.
- **Edge cases:** Leap/month/year/DST/timezone boundaries; zero/one/irregular intervals; overlaps; repeats; failed saves/migrations.
- **Acceptance:** Create/edit/delete round trips survive relaunch; rejected input never partially saves or shows false success; forecasts never persist observations; same inputs/configuration give same results; mutations refresh dependent screens without stale overwrite; actual supported upgrades preserve fixtures; migration failure does not silently reset data.
- **Unit tests:** Date/model fixtures, injected save failure, stale-result races, migration fixtures, no inferred-to-record writes.
- **UI tests:** Historical entry/correction/deletion/relaunch/future restriction.
- **Manual verification:** Timezone change and supported upgrade with synthetic data. Document model rules without implying clinical validation.

### CE-03 — Verify AI, wellness, and privacy boundaries

- **Priority / complexity:** P1 / Large.
- **Customer problem:** Sensitive disclosure, invented facts, unsafe suggestions.
- **Current behavior:** Gateway owner-declared; contracts and processing uninspected.
- **Required behavior:** Processing matches consent; AI respects deterministic facts; optional failures are safe.
- **Scope:** Five operations, consent/payload/logging/retention, wellness prerequisites, support diagnostics, existing authentication/delete/export implications.
- **Out of scope:** New accounts/subscriptions/medical features/AI capabilities/backend replacement.
- **Likely modules:** AI client/gateway, symptom normalization, insights/wellness, privacy/settings/support.
- **Dependencies:** CE-01; authoritative gateway/provider configuration evidence.
- **Edge cases:** Declined consent, ambiguity/missing context, malformed response, 429/5xx/timeout/cancel/stale result, allergy conflict, severe symptoms, unsupported medical request.
- **Acceptance:** Field-level outbound map; consent/disclosures verified before relevant processing; no unintended sensitive diagnostics; extraction requires editable user confirmation before saving; explanations preserve facts/unknowns; invalid/stale/canceled responses cannot mutate records; input survives failure and manual tasks remain usable; claimed allergy/preferences safeguards enforced; safety cases cover severe symptoms, diagnosis, confirmed ovulation and contraception requests; configured deadlines/rate/abuse/token/cost controls documented without monetization; unknown retention not called zero retention.
- **Unit tests:** Mock contracts/schemas, consent gating, write-back boundary, redaction, stale rejection, fallback.
- **UI tests:** Decline consent; review/edit/cancel normalized logs; offline/retry; support preview where applicable.
- **Manual verification:** Authorized synthetic network inspection; representative AI evaluations; qualified review for medical escalation content. No live cost-incurring testing without authorization.

### CE-04 — Verify core workflow completion

- **Priority / complexity:** P1 / Medium.
- **Customer problem:** Failure to reach first value or finish ordinary tasks.
- **Current behavior:** Only calendar entry points verified.
- **Required behavior:** Implemented Section 6 workflows have applicable success/cancel/unavailable/failure states.
- **Scope:** First launch/onboarding/Today/logging/history/settings/support and existing optional authentication/notifications/AI.
- **Out of scope:** Adding absent optional features.
- **Likely modules:** Onboarding, Home, forms/history, profile/settings, support, authentication/notifications if present.
- **Dependencies:** CE-01; CE-02 for persistence assertions.
- **Edge cases:** No/uncertain history, interrupted setup, canceled authentication, denied notifications, empty insights, support cancellation.
- **Acceptance:** New user saves/retrieves first record; insufficient history never fabricates a prediction; canceled unsaved operations produce no records; resumed setup never duplicates records; permission/auth failures recover accurately; support does not involuntarily attach health data; every workflow has pass/defect/not-applicable evidence.
- **Unit tests:** Setup transitions, validation, permission/auth failure, support payload.
- **UI tests:** Clean install to first record; interruption; historical correction; empty states; profile/settings; support cancel.
- **Manual verification:** Primary journey offline and customer-facing copy review.

### CE-05 — Resolve calendar accessibility and explanation uncertainty

- **Priority / complexity:** P1 / Medium.
- **Customer problem:** Selected-date logging or forecast assumptions may be hard to access.
- **Current behavior:** List logging after all days; selection scrolls to its row; explanation gated to current overview estimate; composed detail content unknown.
- **Required behavior:** Reachable contextual logging and understandable applicable forecast limitations.
- **Scope:** Reproduce these two concerns; smallest change only if established.
- **Out of scope:** Broad redesign, model change, duplicated explanations without need.
- **Likely modules:** `TrackerCalendarView`, compact actions, `ProjectedCycleDetails`, `PredictionExplanation`, upcoming forecasts.
- **Dependencies:** CE-01, CE-02.
- **Edge cases:** Early/last month date, largest text, VoiceOver, no/current/later forecast, marker overlap, future day.
- **Acceptance:** At accessibility sizes, early-month selected-date logging is reachable without traversing the remaining month; navigation/sheet dismissal preserve correct action date; current/later forecasts identify estimates and expose applicable assumptions; reuse adequate existing explanations; disproved concerns close without code changes.
- **Unit tests:** Relevant date routing/forecast-description conditions.
- **UI tests:** Early-month large-text logging; current/later explanation; future controls disabled.
- **Manual verification:** Narrow supported screen, largest text, VoiceOver traversal.

### CE-06 — Verify runtime reliability and accessibility

- **Priority / complexity:** P1 / Large.
- **Customer problem:** Lost work, stuck loading, or exclusion from core tasks.
- **Current behavior:** Progress/accessibility hooks exist; runtime not tested.
- **Required behavior:** Execute Sections 11–12 with reproducible device evidence.
- **Scope:** Lifecycle/offline/interruption/errors/loading/performance/essential accessibility.
- **Out of scope:** Speculative cache/store/animation rewrites.
- **Likely modules:** App lifecycle, persistence/session, networking, progress, shared controls/forms.
- **Dependencies:** CE-01; final regression after CE-02–05.
- **Edge cases:** Background saves/requests, repeated taps, poor network, termination, dense history, large text, keyboard, Reduced Motion.
- **Acceptance:** Supported clean/returning launches pass; all async paths exit loading on success/error/cancel/timeout; retry never duplicates observations; airplane-mode local tasks pass; performance target measured with device/data or justified approved adjustment; essential controls reachable with VoiceOver/large text/keyboard; contrast/targets measured; unresolved crashes/data loss/accessibility failures explicitly reported.
- **Unit tests:** Timeout/cancel/state/stale-response/duplicate-prevention cases.
- **UI tests:** Offline tasks, loading recovery, lifecycle where supported, large-text journeys.
- **Manual verification:** Physical-device VoiceOver, Reduced Motion, contrast, Instruments, supported OS/device matrix.

### CE-07 — Reconcile release assets and disclosures

- **Priority / complexity:** P1 / Medium.
- **Customer problem:** Misleading claims, missing support, submission problems.
- **Current behavior:** Assets/policies/metadata/release config uninspected.
- **Required behavior:** Complete Section 13 against actual release and current Apple requirements.
- **Scope:** Assets, URLs/disclosures/manifests, release configuration, reviewer instructions.
- **Out of scope:** Unnecessary login or monetization.
- **Likely modules:** Assets, `Info.plist`, entitlements/project, public support/privacy pages, App Store Connect.
- **Dependencies:** CE-01, CE-03; final CE-06 result.
- **Edge cases:** Debug/release endpoints, inaccessible links, configuration-dependent accounts, sensitive screenshots/notifications.
- **Acceptance:** Every checklist row evidenced or justified not applicable; URLs work publicly; screenshots match shipped UI with synthetic data; disclosures match processing; health/AI claims within verified capability; release archive validates; reviewer access accurate; current authentication/deletion applicability documented.
- **Unit tests:** Configuration/link tests where architecture permits; otherwise explicit not applicable.
- **UI tests:** In-app policy/support navigation and release settings.
- **Manual verification:** Archive validation, URLs outside developer session, App Store Connect audit.

### CE-08 — Validate target segment and competitor wedge

- **Priority / complexity:** P2 / Medium.
- **Customer problem:** Wrong positioning attracts needs Cecy does not serve.
- **Current behavior:** Segment/differentiation hypotheses only.
- **Required behavior:** Dated, sourced research without qualitative-prevalence claims.
- **Scope:** Named competitors/alternatives, switching/abandonment, logging/prediction comparisons.
- **Out of scope:** Pricing design or launch-blocking feature parity.
- **Likely areas:** Product research, positioning, listing proposals.
- **Dependencies:** Browsing and participant access.
- **Edge cases:** Regional/free-tier changes, ambiguous names, duplicate posts, recruitment bias.
- **Acceptance:** Identify each competitor and official dated sources or access limits; feedback provenance and isolated/recurring labels retained; approximately five target users in an explicitly exploratory initial study; reasons choose/stay/leave and smallest responses documented without statistical validation claims.
- **Unit/UI tests:** Not applicable; research only.
- **Manual verification:** Reproduce competitor tasks where access permits and document limitations.

### CE-09 — Add only decision-linked measurement

- **Priority / complexity:** P2 / Medium.
- **Customer problem:** Excessive collection harms trust; unsupported decisions waste effort.
- **Current behavior:** Instrumentation unknown.
- **Required behavior:** Existing evidence first; only explicitly approved minimal metrics added.
- **Scope:** Section 14 schemas and limited local/aggregate instrumentation if approved.
- **Out of scope:** Health-content analytics, tracking SDK by default, accounts, cross-service IDs.
- **Likely modules:** Existing diagnostics/analytics, local settings, gateway operational counters.
- **Dependencies:** CE-01, CE-03.
- **Edge cases:** Duplicate events, consent withdrawal, offline buffering, small cohorts, intentional cancel vs abandonment.
- **Acceptance:** Every metric has owner/decision/definition/allowlist/retention/location; prohibited health content excluded; consent/deletion implications documented; successful outcomes counted correctly; no addition when existing data answers the decision.
- **Unit tests:** Allowlist/redaction, deduplication, consent.
- **UI tests:** Consent controls if introduced; analytics failure never blocks health tasks.
- **Manual verification:** Synthetic outbound payload inspection.

### CE-10 — Test calendar comprehension before redesign

- **Priority / complexity:** P2 / Small.
- **Customer problem:** Users may misread density or marker meaning.
- **Current behavior:** Seven legend entries/multiple encodings; confusion unproven.
- **Required behavior:** Test interpretation and change only demonstrated confusion.
- **Scope:** Legend, terminology, selected-day explanations.
- **Out of scope:** Removing necessary distinctions or modifying forecast mathematics.
- **Likely modules:** Calendar, markers, legend, forecast details.
- **Dependencies:** CE-05; exploratory participant access.
- **Edge cases:** Recorded-plus-estimated day, ovulation/period overlap, grayscale, VoiceOver, later projection.
- **Acceptance:** Predefined classification tasks for recorded bleeding/expected bleeding/possible starts/estimated ovulation; task errors and assistance recorded rather than preference alone; confirmed-ovulation confusion investigated across composed UI; changes preserve non-color cues; retest changed examples with untaught participants where practical; small samples remain qualitative.
- **Unit tests:** Marker/description regressions if changed.
- **UI tests:** Labels/legend/accessibility descriptions if changed.
- **Manual verification:** Structured comprehension sessions.

### CE-11 — Reassess deferred opportunities

- **Priority / complexity:** P3 / Small.
- **Customer problem:** Unvalidated expansion increases complexity and weakens privacy/simplicity.
- **Current behavior:** Deferred capabilities deliberately excluded.
- **Required behavior:** Revisit decisions only with post-launch evidence.
- **Scope:** Section 20 opportunities and monetization hypotheses.
- **Out of scope:** Implementation of any deferred feature.
- **Likely areas:** Product strategy and architecture evaluation, not app code.
- **Dependencies:** Retention, support, research, operating costs after launch.
- **Edge cases:** Vocal minority, acquisition without retention, high AI cost without value, privacy tradeoffs.
- **Acceptance:** Each opportunity records evidence/alternatives/dependencies/privacy/proceed-or-defer; monetization explicitly post-launch; none becomes an implicit dependency for core fixes.
- **Unit/UI tests:** Not applicable; decision task.
- **Manual verification:** Compare proposals with real user evidence and free-core commitments.

## 19. Recommended Engineering Sequence

1. CE-01 establishes evidence.
2. CE-02 addresses critical correctness and data integrity.
3. CE-03 privacy/safety may proceed alongside CE-02 after CE-01.
4. CE-04 verifies core UX, using CE-02 persistence assertions.
5. CE-05 resolves specific calendar/accessibility concerns.
6. CE-06 performs runtime/accessibility checks and final regression.
7. Existing AI polish is limited to reproduced CE-03 findings, followed by recovery regression.
8. CE-07 metadata inventory can start early; final disclosure/archive sign-off follows CE-03/06.
9. CE-08–10 are nonblocking research/refinements.
10. CE-11 follows post-launch evidence.

A confirmed P0 interrupts this sequence according to dependencies. Do not perform speculative P2 redesign while a known P0 privacy or integrity defect remains open.

## 20. Deferred Product Opportunities

| Opportunity | Revisit signal | Dependencies/cautions |
|---|---|---|
| CloudKit/cross-device sync | Repeated material device-transition pain among retained users | Conflicts, migration, deletion, privacy. |
| Partner sharing | Validated collaboration need | Granular consent/revocation/access control/backend or sync path. |
| Subscriptions/premium tiers | Sustained value plus demand and willingness to pay for an additional benefit | **Post-launch strategy**; protect free core. High AI cost alone is not willingness to pay. |
| Android | Sustained qualified non-iOS demand | Capacity/support economics. |
| Web | Validated web-specific task | Identity/security/backend/sensitive exposure. |
| Advanced HealthKit | Specific integration improves core job | Permissions/provenance/conflicts/applicable requirements. |
| More sophisticated AI | Existing AI useful and cost-effective | Evaluation, safety, privacy, observability. |
| Portability improvements | Repeated switching/recovery/clinician-sharing need | Safe formats, explicit destinations, sensitive handling. |

None is a first-release dependency. Free-service cost controls do not inherently require accounts or subscriptions.

## 21. Post-Launch Validation Plan

User counts are checkpoints, not statistical validation. Multi-cycle retention requires elapsed time, not merely installations.

| Checkpoint | Questions | Metrics/feedback | Reconsideration |
|---|---|---|---|
| About 100 users | Can targets reach value, interpret estimates, understand privacy? | Voluntary interviews, task completion, save/recovery defects, support categories, local/consented activation | Fix reproduced friction; refine messaging; do not call enthusiasm PMF. |
| About 1,000 users | Do users return across cycles? Which optional features help? Why leave/switch? | Mature retention cohorts, repeat saves, AI helpfulness/correction outcomes, cost per successful task, accessibility feedback | Reprioritize validated pain; research portability or AI limits only with evidence. |
| About 10,000 users | Repeatable retention across acquisition cohorts? Advocacy? Sustainable free service? | Multi-cycle retention, optional referral intent, incidents, AI cost/latency/errors, continued-use reasons | Target growth/deferred work; future monetization experiments only with value and willingness-to-pay evidence. |

Market-fit signals: voluntary repeat recording/history use; users explain preference; corrections and uncertainty preserve trust; recommendations arise from utility rather than novelty/free pricing alone; AI adds helpful outcomes, not just activity; retention persists over multiple cycles.

## Final Quality Review and Handoff Assessment

| Check | Result |
|---|---|
| P0 contains only confirmed blockers | No P0 tasks asserted. |
| Deferred features excluded from release dependencies | Yes. |
| Every engineering task has current/required behavior, scope, dependencies, edge cases, acceptance, tests | Yes; research-only tasks explicitly mark automated tests not applicable. |
| Privacy and deterministic-facts/AI-explanation boundary | Explicit throughout. |
| Ovulation certainty | No unsupported confirmation or contraceptive claims. |
| Major requested workflows | Covered; unverified behavior explicitly labeled. |
| App Store, reliability, accessibility | Concrete verification criteria; not claimed passes. |
| Evidence-based product changes | Conditional on reproduction; no invented defects or market results. |
| Repository-wide/market review complete | **No.** Those tasks remain necessary. |
| Ready for implementation without repeating research | **Ready for targeted verification, not a fully evidenced product-change backlog.** |

**Task counts:** P0 = 0; P1 = 7; P2 = 3; P3 = 1. P1 entries are primarily verification, not seven confirmed product defects.

**Largest launch risk:** Unverified correctness and privacy across local records, predictions, and AI processing.

**Recommended first engineering task:** CE-01 — establish commit-specific implementation evidence.

This file preserves the limits of the chat review. Once CE-01–07 establish actual behavior, amend the handoff with reproducible defects and remove resolved hypotheses. Do not disguise unfinished research as completed review or expand scope to fill an empty P0 backlog.