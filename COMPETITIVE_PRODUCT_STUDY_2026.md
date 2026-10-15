# Cecy Competitive Product Study

**Assessment date:** October 15, 2026  
**Repository baseline:** `main` at `723e7f7`, reviewed on branch `docs/competitive-product-study-2026-10-15`  
**Scope:** Read-only product, source, test, and market study. No application code, tests, configuration, backend, or assets were changed.  
**Market:** Consumer menstrual and cycle tracking on iPhone, with US App Store examples and English-language official materials. Features, prices, availability, and policies can vary by region and can change.

---

## 1. Executive recommendation

Cecy should not try to win by copying every screen in Flo, Clue, Ovia, Stardust, Natural Cycles, or Apple Health. Those products have substantially larger content libraries, datasets, teams, distribution, device ecosystems, or regulated claims. A feature-volume race would make Cecy slower, less trustworthy, and harder to maintain.

Cecy has a credible, differentiated foundation:

> **A calm, free, privacy-first cycle companion that keeps sensitive records on the iPhone, makes daily tracking fast, shows exactly what is recorded versus estimated, and turns a person’s own history into understandable, shareable evidence without ads or coercive upsells.**

The source already supports much more than a basic period calendar: historical correction, per-day bleeding, roughly 40 symptom types, sexual activity, local pattern analysis, forecast uncertainty, future-cycle projections, appointment summaries, optional AI, reminders, Health import, export, deletion, and app locking. The best path is to make this core exceptionally dependable and effortless, then add depth in a deliberate order.

### Highest-impact strategy

1. **Make trust demonstrable, not just claimed.** Close the release, accessibility, privacy-policy, native-service, and AI gateway evidence gaps. Explain local storage, lack of restore, and optional remote AI plainly.
2. **Reduce onboarding and daily logging effort.** Fourteen onboarding steps plus mandatory Apple sign-in is heavy for a local-first tracker. Keep every capability, but progressively disclose optional profile/wellness questions and make Apple linking optional unless a verified product or compliance requirement makes it essential.
3. **Turn existing breadth into a personalized daily tracker.** Add favorite/reordered tracking categories, a single daily check-in, recent choices, medication/contraception tracking, and clearer “done for today” feedback.
4. **Own transparent irregular-cycle support.** Add dated cycle factors and explain how pregnancy, postpartum, breastfeeding, contraception, missed logs, and perimenopause affect each estimate. Never silently discard records.
5. **Make records useful outside the app.** Upgrade the existing appointment summary into accessible PDF/CSV sharing, trend summaries, and data re-import. This is a practical advantage over engagement-oriented content.
6. **Add life-stage depth one journey at a time.** Begin with perimenopause and cycle-change support, then postpartum, because Cecy already tracks relevant symptoms and context. Treat trying-to-conceive and pregnancy as separate, evidence-heavy product programs—not labels on the current calendar estimate.
7. **Use AI as an optional interface to evidence, not the product moat.** The defensible value is Cecy’s local, structured history and cautious reasoning. AI should reduce logging and explanation effort while never replacing deterministic facts.

### Product verdict

Cecy is **feature-rich but not yet proven market-ready**. Its source-level core is competitive for private period and symptom tracking, but its release evidence, onboarding friction, data resilience, localization, wearable reach, and life-stage depth trail category leaders. The app can stand out without removing anything by becoming the best “private record + honest uncertainty + useful doctor handoff” tracker rather than the broadest content or fertility platform.

---

## 2. Method and evidence limits

### Repository evidence reviewed

The study traced:

- App entry, lock/account gates, navigation, lifecycle, and state coordination in `cecy/App/TrackerRootView.swift`, `cecy/App/TrackerSession.swift`, and `cecy/cecyApp.swift`.
- Fourteen-step onboarding and setup behavior in `cecy/Features/Onboarding/OnboardingFlowView.swift` and profile/setup domain models.
- Today, logging, calendar, insights, AI, settings, privacy, reminders, Health import, export, deletion, and support views.
- Forecast, symptom, bleeding, context, statistics, appointment-summary, AI-context, and privacy domain logic.
- SwiftData schemas through V7 and the repository boundary.
- Unit/UI test inventory and the latest repository planning/validation documents.
- Current asset, entitlement, permission, localization, Widget, and Watch target presence.

### Market evidence

Official competitor App Store listings, official policies, and Apple support material were retrieved on October 15, 2026. App Store reviews included on those pages are used only as **anecdotal signals**, never prevalence estimates or proof that all users have the same experience.

No competitor apps were installed or usability-tested in this study. No Cecy build, simulator run, physical-device test, live Apple sign-in, live HealthKit authorization, notification delivery, email send, or live AI request was performed. Source presence is not runtime acceptance.

### Important documentation freshness note

`RELEASE_READINESS_VALIDATION.md` is dated October 3, 2026 and tested an older candidate. It remains valuable historical evidence, but it does not validate HEAD `723e7f7`. Some findings have changed—for example, the current AppIcon asset contains `cecy_icon_v2.png`, and release prototype labels are now guarded by `#if DEBUG`. Other open findings remain visible in current source, including the lack of an in-app privacy-policy link. A fresh full regression is required before release decisions.

---

## 3. Cecy end-to-end experience today

## 3.1 First launch, privacy, and account gate

`TrackerRootView` starts privacy preferences, handles app lock, checks Apple credential state, loads the local SwiftData repository, and fails closed if records cannot be opened. It shields content outside the active scene and invalidates sensitive/remote work on lock, sign-out, or background transitions.

A user must pass these gates:

1. Privacy preferences initialize.
2. Optional app lock unlocks.
3. Apple account state permits access.
4. Local records load.
5. Incomplete users enter onboarding; completed users see the four-tab app.

**Strengths**

- Local-store failures do not silently reset health data.
- Background shielding, app lock, cancellation, and stale-response handling are designed deliberately.
- The app does not require the AI service for local tracking after setup.

**Friction/risk**

- New-user setup ends with mandatory Sign in with Apple even though records stay only on that device and Apple sign-in cannot restore them. This adds network/account friction without delivering the recovery users usually associate with an account.
- The product needs a crisp answer to “Why must I sign in if my data is local?” If no strong answer exists, permit “Continue locally” while retaining optional Apple linking.
- First setup cannot be honestly positioned as fully offline while Apple authorization is mandatory.

## 3.2 Onboarding

`OnboardingFlowView.Step` contains 14 screens:

1. Welcome/value proposition
2. Name and date of birth
3. Optional height and weight
4. Optional gender
5. Optional partner genders
6. Most recent period start or unknown
7. Typical period length or unknown
8. Typical cycle length and predictability
9. Common symptom preferences
10. Cycle context
11. Goals
12. Reminders
13. Review/edit
14. Sign in with Apple and finish

The setup supports unknown answers, optional fields, review/edit, interruption recovery, reminder selection, starter forecasts from one period plus typical cycle length, and explicit uncertainty/safety language.

**What works well**

- “Not sure” is a valid state rather than fabricated data.
- Optional sensitive identity questions explain local use and AI exclusion.
- The review screen shows the estimate and basis before completion.
- Setup writes are staged and completed atomically.

**What to refine**

- Fourteen steps are disproportionate before first value. Name, birth date, measurements, gender, partners, symptoms, goals, reminders, and Apple account do not all need to block the first Today screen.
- Height and weight are collected but explicitly not used for prediction; asking during onboarding creates privacy cost without immediate value.
- Common-symptom selection is only a preference and does not create tracking entries; users may expect otherwise.
- Wellness prerequisites are configured later, creating a second personalization flow.

**Recommended shape without removing fields**

- **Essential setup (3–5 screens):** purpose/privacy, last period or unknown, typical lengths or unknown, initial estimate/review, enter app.
- **Optional personalization checklist after activation:** reminders, symptom favorites, life-stage context, wellness, measurements, identity, Apple linking.
- State why each field helps before asking it. Skip remains available and answers remain editable.

## 3.3 Today and daily use

Today provides:

- A horizontally browsable date strip with record and forecast markers.
- Cycle/phase presentation and a next-period countdown/window.
- Recorded versus estimated current-period status.
- Four quick actions: period, symptoms, sexual activity, and other bleeding.
- Local daily record details and paginated history.
- Optional generated daily insights.
- Upcoming period, bleeding, fertile-window, and possible-ovulation projections.
- A deterministic observation/pattern when available.

**Strengths**

- Users can log a selected past/today date from the primary screen.
- Recorded facts and estimates use different labels and visual treatments.
- Forecast explanation exposes source intervals, median/window policy, confidence limitations, and missing-record effects.
- The app does not convert overdue estimates into records.
- Daily bleeding distinguishes bleeding, spotting, no bleeding, and uncertainty without treating unlogged days as “none.”

**Friction/opportunity**

- Four separate actions fragment what users perceive as one daily check-in.
- The rich page can become vertically long: hero, phase, AI, forecast, daily log, confirmations, and insight.
- There is no user-controlled favorite/reordered tracker set, recent-entry shortcut, “same as yesterday,” or quick completion state.
- Profile “common symptoms” do not tailor the quick-log surface.
- AI is visually prominent despite requiring remote processing and unresolved live safety/retention evidence.

## 3.4 Period and bleeding tracking

Cecy supports:

- Period starts, optional confirmed ends, overall flow, and private notes.
- New-period versus continuation choices when a date could extend an existing record.
- Historical add/edit/delete and prediction recalculation.
- Per-day bleeding/spotting/no-bleeding/not-sure answers with optional daily flow.
- Linking daily bleeding to a recorded period.
- Reconciliation when a daily answer conflicts with period dates.
- Explicit future-date recording prevention.

This is a strong data-integrity model. Many trackers blur a period interval with inferred daily bleeding; Cecy keeps these concepts separate.

**Needed refinement**

- Give users one obvious “Period started,” “Still bleeding,” and “Period ended” path from Today.
- Show a lightweight active-period check-in until the end is confirmed.
- Preserve the advanced reconciliation model but hide its complexity until a conflict occurs.
- Consider menstrual-product usage/absorbency as optional data only after user research; it can help communicate heavy bleeding but must avoid false volume precision.

## 3.5 Symptom and wellness tracking

`SymptomKind` currently covers roughly 40 items in six categories: pain/discomfort, mood/focus, energy/sleep, digestion/appetite, skin/hair, and other body changes. Entries support three-level severity/rating and notes. One entry per symptom type per day prevents accidental duplicates.

This breadth is substantially stronger than older Cecy documents imply and supports period, perimenopause, and general cycle-change use cases.

**Gaps relative to leaders**

- No custom symptoms/tags.
- No favorite/reorder/hide configuration for day-to-day logging.
- No medication, supplement, contraception adherence, or treatment logging.
- No structured basal body temperature, LH test, cervical mucus, resting heart rate, pregnancy test, or ovulation-test tracking.
- No longitudinal cycle-factor timeline; profile context is current state, not dated history.
- No explicit PMDD-oriented daily mood/function assessment or screening boundary.

## 3.6 Sexual activity

The app supports local sexual-activity records, editing/deletion, calendar markers, export opt-in, and notes. These records are excluded from prediction and AI context, and unlogged days remain unknown.

**Refinement principles**

- Keep this separate and private by default.
- Let users hide the quick action/markers without deleting records.
- If contraception or protection details are added, use neutral, inclusive language and never calculate pregnancy risk from the current calendar forecast.

## 3.7 Calendar and historical correction

Calendar supports month navigation, direct date selection, a compact grid or accessibility list, record/estimate markers, date-adjacent logging at large text, upcoming forecasts, selected-day details, prior-period entry, and sexual-activity history.

**Strengths**

- Future dates are viewable but observation controls are disabled with an explanation.
- Recorded period, symptoms, sexual activity, daily bleeding, estimated period, and estimated ovulation are represented separately.
- Later projections disclose that they assume unrecorded periods occur.

**Risks to test**

- Marker density and legend comprehension.
- Large-text/VoiceOver traversal and selected-day detail visibility.
- The October 3 full suite had calendar-related failures, though several were stale test assumptions rather than confirmed product defects.

## 3.8 Forecasts, ovulation, and irregular cycles

The current engine uses a deterministic, inspectable policy rather than a black-box claim:

- Starter estimate from recorded start plus entered typical cycle length.
- History estimates from up to six measured start-to-start intervals.
- Median center and a window derived from observed range with padding.
- Forecast withholding when variation is too wide.
- Provisional Low/Moderate confidence, not probabilities.
- Up to three future period/bleeding/possible-ovulation/fertile-window projections.
- Context-specific warnings for hormonal contraception, postpartum, breastfeeding, perimenopause, and other states.

**Competitive advantage**

Cecy exposes uncertainty and inputs more clearly than most marketing descriptions reviewed. This can become a signature capability.

**Limits**

- There is no real-world calibration or clinical predictive-validity evidence.
- Ovulation is calendar-derived; no biomarker confirms it.
- A current profile context cannot represent historical changes, so pregnancy, contraception, postpartum, or missed logging may create misleading intervals.
- “Cycle phase” language must remain clearly estimated; actual hormonal state is not measured.

## 3.9 Insights and clinician handoff

Insights includes:

- Recording coverage for 30/90 days.
- Local “for today” facts.
- Symptom timing observations and patterns.
- Cycle statistics and charts.
- Completed intervals and source dates.
- Prediction replay/history checks.
- Period management.
- Optional AI record insights, summaries, explanations, and bounded questions.
- A locally generated appointment summary with selectable date range and sections.

The appointment summary is an excellent foundation: it excludes identity and sexual activity, treats missing logs honestly, supports optional notes/context, previews before sharing, and is generated on-device.

**Competitive opportunity**

Make “leave an appointment better prepared” a flagship workflow:

- Human-readable PDF plus accessible plain text.
- Compact trend charts and material-change highlights with supporting dates.
- User-selected questions/concerns for the visit.
- CSV/FHIR-friendly export exploration without claiming EHR integration.
- Never diagnose; explicitly distinguish user records from observations and generated explanations.

## 3.10 Optional AI

Five bounded paths exist:

1. Natural-language symptom normalization with review before save.
2. Explanation of a deterministic local observation.
3. Daily wellness insights.
4. Cycle/record summaries.
5. Bounded questions using selected aggregate facts, plus several local prepared answers.

The client minimizes typed context, uses explicit consent, refuses redirects, avoids cookies/cache/credential storage, validates response shapes, cancels stale requests, and does not allow AI to write records directly.

**Product judgment**

This is a useful convenience, not yet a defensible moat. Flo and Clue advertise extensive personalized/AI experiences, and Clue’s September 28, 2026 policy describes retained AI interaction records. Cecy can differentiate with less data and no persistent chat history, but only if the deployed Azure/OpenAI retention, logging, rate limits, abuse controls, semantic safety, and deletion story are independently verified and published.

**Recommended AI rule**

- Local facts first.
- Remote explanation only after a user understands what will be sent.
- Every answer cites the local evidence it used.
- Never infer diagnosis, pregnancy, safe/unsafe sex days, or confirmed ovulation.
- Keep manual tracking and local summaries complete when AI is off or unavailable.

## 3.11 Settings, privacy, and data control

The app includes:

- Profile and wellness editing.
- Apple account linking/logout state.
- Face ID/Touch ID/device-passcode app lock.
- Appearance settings.
- Local reminders with discreet/detail choices.
- Read-only, review-before-save Apple Health menstrual-flow import.
- JSON export with explicit opt-ins for notes, sexual activity/partner answers, and profile.
- Storage/backup disclosures.
- Typed delete-all confirmation and coordinated reminder/account/local cleanup.
- Contact support with no automatic health attachments.

**Current trust gaps**

- No accessible privacy-policy link was found in app source.
- JSON cannot be imported back, and no automatic restore/sync exists; device loss or replacement can mean permanent loss.
- The app requests Sign in with Apple but does not deliver data recovery, creating expectation mismatch.
- App Store privacy disclosures, gateway/provider behavior, account deletion/token revocation applicability, and public support/privacy pages still need final reconciliation.
- “Local-first” must never become “nothing leaves your phone”: optional AI, Apple sign-in, Health, email handoff, and user-directed exports cross boundaries.

---

## 4. Competitive landscape as of October 15, 2026

## 4.1 Flo

**Officially advertised strengths**

- Period, ovulation, pregnancy, and perimenopause support.
- More than 70 symptoms/moods, irregular-cycle support, downloadable doctor reports, fertility signs, LH tests, basal temperature, partner mode, education, community, and AI/wellness experiences.
- Anonymous Mode and ISO 27001/27701 privacy/security programs.
- iPhone and Apple Watch; 20+ listed languages.

**Tradeoffs/opportunity for Cecy**

- Free with in-app purchases; advanced insights/content are part of Premium.
- App Store privacy labels list broad linked data and tracking categories outside Anonymous Mode.
- Selected App Store reviews complain about repeated premium prompts; these are anecdotes, not prevalence data.
- Cecy can be calmer, fully useful without upsell interruption, and materially simpler in data handling—but only with a complete public privacy story and resilient local data.

## 4.2 Clue

**Officially advertised strengths**

- More than 200 symptoms/experiences, custom reminders, charts, 400+ articles, period/TTC/pregnancy/perimenopause modes, birth-control support, Apple Health and several wearable integrations.
- Clinically validated conception algorithm and regulated medical-device listing for Clue Conceive, not contraception.
- iPhone, 26+ listed languages, and explicit accessibility declarations.
- Strong science and EU/GDPR positioning.

**Tradeoffs/opportunity for Cecy**

- Free with Clue Plus subscription.
- Current policy describes account, health, usage, device, AI, advertising, communication, and service-provider processing; health data is server-hosted in the EU.
- Cecy cannot match Clue’s scientific claims without equivalent validation. It can provide more transparent local calculations and less mandatory data processing.
- Cecy currently trails badly on localization, content, life-stage modes, biomarker/wearable support, and declared runtime accessibility.

## 4.3 Apple Health Cycle Tracking

**Officially documented strengths**

- Built into iPhone/iPad and Apple Watch.
- Period, symptom, spotting, basal-temperature, pregnancy, lactation, contraception, and menopause-stage tracking.
- Period/fertility notifications, cycle-deviation detection, 12-month PDF export.
- Wrist-temperature retrospective ovulation estimates on supported Apple Watch models, and heart-rate data can improve predictions.
- Health data can receive end-to-end encryption with qualifying settings.

**Tradeoffs/opportunity for Cecy**

- Apple is the no-cost baseline and ecosystem incumbent.
- Cecy must provide a clearer, warmer daily experience, deeper personal pattern explanation, better historical correction, and useful appointment preparation—not merely duplicate a calendar.
- Cecy’s current read-only menstrual-flow import is narrow compared with Apple’s broader biomarker ecosystem.

## 4.4 Stardust

**Officially advertised strengths**

- Strong visual identity and daily engagement around cycle/hormone interpretation.
- Period/TTC/pregnancy/postpartum modes, daily insights, Apple Watch/Oura temperature support, partner/friend synchronization, and cycle recaps.
- Science mixed with astrology, lunar, and “ancient wisdom” content—a distinctive emotional brand.

**Tradeoffs/opportunity for Cecy**

- Free with in-app purchases.
- App Store privacy labels disclose tracking categories and unlinked health data; marketing says health information is not sold/shared.
- Cecy should not imitate astrology or unsupported hormone certainty. It can stand out through evidence transparency, neutral inclusivity, and calm utility.
- Stardust demonstrates that people value an emotionally resonant daily identity; Cecy needs more warmth and personalization without sacrificing accuracy.

## 4.5 Natural Cycles

**Officially advertised strengths**

- FDA-cleared non-hormonal birth-control app with stated effectiveness figures.
- Daily biometric/temperature algorithm and support for NC Band, Oura, WHOOP, Garmin, and Apple Watch.
- Birth control, pregnancy planning, pregnancy, postpartum, perimenopause, and partner experiences.

**Tradeoffs/opportunity for Cecy**

- Subscription unlocks core features; listed US prices are materially higher than general trackers.
- This is a regulated fertility/contraception product, not a valid near-term parity target.
- Cecy must continue stating that its calendar estimates are not contraception or confirmed ovulation. Adding BBT/LH logs can improve personal records but does not authorize contraceptive claims.

## 4.6 Ovia Health by Labcorp

**Officially advertised strengths**

- Broad journey coverage: cycle, TTC, pregnancy, postpartum, perimenopause, and menopause.
- Extensive free content, customizable logging, birth-control tracking, fertility score, pregnancy tools, family sharing, Apple Health/Fitbit integration, and employer/health-plan programs.

**Tradeoffs/opportunity for Cecy**

- The breadth can be complex, and App Store labels list extensive data linked to identity.
- Cecy can offer a much smaller data footprint and less institutional/commercial complexity.
- Ovia shows what “one stop shop” actually entails: life-stage continuity, not just more symptom buttons.

## 4.7 Euki

**Officially advertised strengths**

- Free, nonprofit, open-source, account-free, local-only, and no collection according to its App Store privacy label.
- PIN protection, scheduled data deletion, customizable tracking, medication/appointment reminders, cycle summary, sexual/reproductive-health education, and care navigation.

**Tradeoffs/opportunity for Cecy**

- Euki is the closest privacy-positioning competitor and prevents Cecy from claiming that local-only is unique.
- Cecy’s stronger opportunities are transparent forecasts, deeper local patterning, Apple-native polish, AI minimization, and clinician handoff.
- Euki’s education and care navigation show that privacy-first users still need trustworthy action after tracking.

## 4.8 Competitive capability matrix

Legend: **Strong** = substantive source-supported Cecy implementation or prominent competitor offering; **Partial** = present but narrow/unverified; **Absent** = not found in current Cecy source. Competitor cells summarize official positioning, not hands-on acceptance.

| Capability | Cecy | Flo | Clue | Apple | Stardust | Natural Cycles | Ovia | Euki |
|---|---|---|---|---|---|---|---|---|
| Period/history CRUD | Strong | Strong | Strong | Strong | Strong | Strong | Strong | Strong |
| Rich symptom logging | Strong (~40 types) | Strong (70+) | Strong (200+) | Moderate | Strong | Moderate | Strong | Moderate |
| Explicit estimate uncertainty/evidence | **Strong differentiator** | Partial in reviewed copy | Science-led | Limited algorithm detail | Weak/mixed framing | Regulated output | Partial | Partial |
| Local-first core records | **Strong** | Cloud/anonymous mode option | Cloud account | Apple Health/iCloud | Cloud service | Cloud service | Cloud account | **Strong** |
| No ads/upsell interruption | **Strong** | Premium | Premium | Strong | Premium | Subscription | Free/employer | Strong |
| App lock/privacy shield | Strong | Strong | Device guidance | Device-level | Not benchmarked | Privacy program | PIN | PIN/decoy concepts |
| Data export | JSON + text summary; no import | Standard export/report | Portability | PDF | Not benchmarked | Not benchmarked | Not benchmarked | Local controls |
| Clinician report | Partial/strong foundation | Downloadable report | Analysis/export | 12-month PDF | Cycle recap | Charts/data | Rich data | Cycle summary |
| Health/wearables | Read-only period import | Apple Watch | Many wearables | Deep ecosystem | Watch/Oura | Multiple devices | Health/Fitbit | None highlighted |
| Biomarkers (BBT/LH/mucus) | **Absent** | Strong | Strong | BBT/ovulation test | BBT | Core strength | Fertility inputs | Limited |
| Birth-control/medication tracking | **Absent** | Reminders | Strong | Cycle factors | Not clear | Mode-specific | Strong | Strong |
| Pregnancy mode | **Absent** | Strong | Strong | Strong | Strong | Strong | Strong | No |
| Postpartum mode | Context only | Pregnancy ecosystem | Partial mode continuity | Lactation factor | Strong | Strong | Strong | No |
| Perimenopause/menopause | Context + symptoms, no mode | Strong | Strong | Strong | Symptoms | Strong | Strong | No |
| Partner sharing | **Absent** | Strong | Clue Connect | Health sharing | Strong | Partner view | Strong | No |
| Educational library | **Absent** | Strong | Strong | Apple support/content | Strong branded content | Guidance | 2,000+ articles | Strong |
| AI/personalized questions | Five bounded paths | Strong | Newly explicit AI | No comparable chat | AI insights | Algorithmic guidance | Personalized tools | No |
| Apple Watch app | **Absent** | Yes | Wearable ecosystem | Yes | Data integration | Yes | No listing | No |
| Localization | English-only source | 20+ | 26+ | Broad OS localization | 3 languages | 4 languages | English/Spanish | English/Spanish |
| Account-free use | No; Apple sign-in required | Anonymous Mode | No | Apple device identity | Not benchmarked | No | No | Yes |
| Regulated fertility/contraception | No; appropriately disclaimed | No | Conceive aid | No contraception | No | **Yes** | No | No |

---

## 5. What should make Cecy stand out

## 5.1 Positioning pillars

### Pillar 1 — Private by architecture

- Core health records, calculations, patterns, reports, and preferences work locally.
- No advertising SDK or reproductive-health event analytics.
- Remote AI is optional, task-specific, minimized, and reversible.
- Export and deletion are explicit and understandable.

**Proof required:** public policy, processor/retention details, release privacy labels, device protection testing, and transparent recovery limitations.

### Pillar 2 — Honest uncertainty

- Recorded facts never become estimates; estimates never become records.
- Every forecast can answer “what data produced this?”
- Irregularity can suppress an estimate instead of manufacturing precision.
- Cycle context and missing records visibly qualify outputs.

This is more defensible than “most accurate” marketing.

### Pillar 3 — Your evidence, useful in real life

- Fast daily recording.
- Longitudinal patterns backed by dates and counts.
- Appointment-ready summaries users control.
- Easy correction and portability.

The goal is not maximum engagement time; it is confidence before travel, events, healthcare visits, and ordinary planning.

### Pillar 4 — Calm and complete, never coercive

- A fully useful free core.
- No blocked insight teaser, surprise paywall, or streak shame.
- Personalization reduces clutter rather than adding feeds.
- Inclusive wording and support for uncertain/incomplete data.

## 5.2 Proposed one-sentence promise

> **Cecy helps you privately record your cycle, understand what your own history can—and cannot—tell you, and bring clearer evidence to everyday decisions and healthcare visits.**

Avoid claiming “the most private,” “most accurate,” “AI-powered healthcare,” confirmed ovulation, contraceptive safety, diagnosis, or comprehensive women’s healthcare until independently substantiated.

---

## 6. Prioritized product roadmap

Priorities describe product value, not authorization to implement. Existing features remain enabled; recommendations refine them or add complementary capabilities.

## P0 — Earn launch trust and make the current app dependable

### P0.1 Fresh release acceptance at current HEAD

**Why:** The October 3 run had 15 UI failures and predates subsequent schema/UI changes. A competitive product cannot ship with unknown core workflow or accessibility status.

**Do**

- Reconcile each old failure against current intended behavior.
- Run current full unit/UI suite, release archive, migration fixtures, and targeted dense-history tests.
- Complete physical-device checks: minimum/current OS, iPhone/iPad, lock/file protection, app switcher, VoiceOver, Dynamic Type, contrast, Reduce Motion, keyboard, offline, timezone, reminders, Health, Mail, and Apple authorization.
- Capture and resolve current runtime warnings and actual product defects; update stale tests rather than weakening valid assertions.

**Success:** Zero unresolved core data-loss/safety/privacy failures; every essential task has current evidence.

### P0.2 Complete the public trust surface

**Why:** No in-app privacy-policy link was found. Privacy is Cecy’s intended wedge and an App Store requirement, so incomplete disclosure is both strategic and release-critical.

**Do**

- Publish and link an approved HTTPS privacy policy and support page.
- Add a concise in-app “Privacy at a glance” data-flow map.
- Reconcile App Store privacy labels with SwiftData, Sign in with Apple, registry calls, HealthKit, AI gateway/provider, support, and exports.
- Document gateway logging, provider retention, deletion, region, access, rate limits, abuse protection, and incident handling.
- Resolve Sign in with Apple account-deletion/token-revocation obligations.

**Success:** A user can answer where every category is stored, when it leaves, why, for how long, and how to stop/delete it.

### P0.3 Decide and explain the account model

**Why:** Mandatory Apple sign-in contradicts the intuitive promise of a local-only app because it does not restore records.

**Preferred direction:** Keep Apple linking but add **Continue locally** during onboarding. Ask to link only when it delivers a concrete benefit. If mandatory sign-in is retained, explain its exact purpose before authorization and validate offline/cancel/revocation behavior.

**Success:** Users never mistake identity linking for backup, and local tracking does not fail because account value is unclear.

### P0.4 Validate medical and AI safety boundaries

**Why:** Generated wellness and cycle answers can cause more harm than a missing convenience feature.

**Do**

- Qualified review of local fertility, ovulation, perimenopause, bleeding, and escalation wording.
- Synthetic live evaluations for severe symptoms, pregnancy possibility, contraception, diagnosis, allergy conflicts, eating/exercise risk, fabricated records, and unsupported certainty.
- Add evidence citations/provenance to generated output where practical.
- Gate or narrow only the unsafe output type if it fails; do not impair local tracking.

**Success:** No AI response contradicts records, promises safety, diagnoses, or suppresses appropriate care guidance.

## P1 — Make the everyday experience best in class

### P1.1 Progressive onboarding and faster time to first value

**Add/refine**

- Essential setup first; optional profile sections after entry.
- Preview Today before asking for reminders, measurements, identity preferences, or online features.
- Explain the benefit of each optional answer.
- Offer Health import as a fast history path after local entry, not a prerequisite.
- Save and resume every meaningful step.

**Target:** Median setup to usable Today under two minutes for a user who knows the last period date; no optional sensitive field blocks activation.

### P1.2 One personalized daily check-in

Combine the current actions without removing them:

- A single “Log today” entry opens favorite categories.
- Pin/reorder/hide symptoms and sensitive categories.
- Show common symptoms selected during onboarding first.
- Recent choices and “same as yesterday” with explicit review.
- Clear saved state and easy correction.
- Keep direct period/symptom/sex/bleeding shortcuts for users who prefer them.

**Target:** Common daily entry in three taps or fewer after opening the check-in; no accidental duplicate or silent save.

### P1.3 Structured contraception, medication, and treatment tracking

Start with records, not advice:

- Contraception method as a dated factor, with start/end/change history.
- Optional pill/ring/patch/shot/device reminders and taken/late/missed/skipped states.
- General medication/supplement name, dose text, and taken/skipped state with privacy-safe reminders.
- No efficacy or pregnancy-risk calculation without a separately validated medical program.

This closes a practical daily gap across Clue, Ovia, Euki, and Flo while strengthening interpretation of cycle changes.

### P1.4 Dated cycle-factor timeline for irregular cycles

Replace the current-state-only limitation while keeping profile context:

- Pregnancy, pregnancy loss, postpartum, breastfeeding, perimenopause, hormonal/non-hormonal contraception, stopping contraception, illness/stress/travel, and “possible missed record” as dated factors.
- Show exactly which intervals are affected.
- Keep raw records; allow transparent inclusion/exclusion from forecast calculations with user-visible reasons.
- Never describe missing logs as biological irregularity.

**Differentiator:** “Cecy explains why it cannot estimate” is more trustworthy than continuously moving a date.

### P1.5 Appointment report 2.0

Build on `AppointmentSummary`:

- Accessible PDF and CSV in addition to text/JSON.
- Period and symptom trend charts with date range and coverage.
- User-selected top concerns and questions.
- Optional medication/contraception/factor timeline after those records exist.
- Redaction preview and clear sharing warning.
- No remote generation required.

**Target:** A useful, readable report can be prepared in under one minute and understood without installing Cecy.

### P1.6 Data portability and recovery

- Import Cecy’s versioned JSON export with preview, deduplication, conflict resolution, and rollback.
- Add encrypted user-controlled backup/restore or device-to-device transfer only after a threat-model and key-recovery design.
- Keep local-only mode.
- Make Apple linking’s role independent from health-data sync unless an explicit opt-in sync product is later built.

This reduces the largest cost of local-first architecture: permanent loss on device replacement.

### P1.7 Notification usefulness without exposure

Retain discreet notifications and add:

- Period started/ended follow-up prompts.
- User-selected symptom or medication check-ins.
- Late/missed log prompts that never imply “no bleeding.”
- Snooze and per-reminder privacy text.
- Deep-link to the exact check-in.

Avoid daily pressure for users who only need cycle events.

## P2 — Add differentiated depth

### P2.1 Perimenopause and cycle-change mode first

Cecy already has hot flashes, night sweats, vaginal dryness, sleep, mood, urinary discomfort, libido, perimenopause context, irregular-cycle handling, and appointment summaries. Package these into a coherent experience:

- Tailored check-in and trends.
- Bleeding-change and symptom coverage summaries.
- Evidence-reviewed education and care-escalation guidance.
- No hormonal-state inference from calendar day.

This is a more attainable and underserved extension than regulated fertility claims.

### P2.2 Postpartum and breastfeeding mode

- Dated birth/pregnancy-end event.
- Lochia/postpartum bleeding explicitly separate from a menstrual period.
- Feeding context, return-of-cycle uncertainty, sleep/mood/recovery tracking, and sensitive loss-aware language.
- Clear urgent-care escalation reviewed by qualified experts.
- Do not let postpartum gaps distort cycle averages.

### P2.3 Biomarker record layer

Add optional structured records:

- Basal body temperature.
- LH/ovulation tests.
- Cervical mucus/discharge observations.
- Resting heart rate and sleep imports where justified.
- Pregnancy tests.

Initially present these as records and charts. Any prediction improvement requires a documented algorithm, validation, and appropriate regulatory review. Do not call calendar estimates “confirmed” after adding a single signal.

### P2.4 Deeper Apple ecosystem integration

- Write-back to Apple Health only with granular opt-in, provenance, deduplication, and loop prevention.
- Read relevant temperature/sleep/heart-rate data only when it supports an approved user job.
- Apple Watch quick logging.
- Privacy-safe widgets that default to discreet state.
- App Intents/Shortcuts for user-confirmed logging.

### P2.5 Evidence-reviewed education

A small, excellent library is better than hundreds of generic articles:

- Irregular cycles and missing records.
- What period/ovulation estimates mean.
- Heavy bleeding and pain: when to seek care.
- Contraception effects on bleeding.
- Postpartum, breastfeeding, and perimenopause basics.
- Preparing for an appointment.

Show author/reviewer, references, review date, jurisdiction limitations, and emergency-care boundaries. Link guidance contextually from a record or pattern without diagnosing.

### P2.6 Localization and inclusive language

- Adopt String Catalogs and locale-aware copy from the start of the initiative.
- Prioritize languages using target-market research, not competitor count alone.
- Validate date formats, first weekday, calendars, right-to-left layouts, pluralization, Dynamic Type, and VoiceOver.
- Preserve inclusive “people who menstruate” functionality while marketing can address women without making the product unusable for trans and nonbinary users.

### P2.7 User-controlled insight quality

- Let users mark insights helpful/not helpful and explain why locally.
- Show evidence coverage and “what would make this stronger.”
- Compare symptoms by cycle-relative timing only when logging coverage is adequate.
- Surface meaningful change, not repetitive daily prose.

## P3 — Strategic programs requiring separate validation

### P3.1 Trying-to-conceive mode

Requires biomarker support, conception-specific UX, clearer fertile-sign education, outcome definitions, algorithm validation, medical/regulatory assessment, and loss-sensitive transitions. The current calendar fertile window is not sufficient.

### P3.2 Pregnancy and pregnancy-loss support

A true pregnancy mode requires gestational dating, symptom/safety content, appointments, loss handling, postpartum transition, privacy review, and continuous expert content maintenance. Do not ship a shallow countdown merely for parity.

### P3.3 Granular partner/support-person sharing

Only after validated demand and secure architecture:

- User chooses exact categories and duration.
- Default excludes notes, sexual activity, medications, identity, and raw history.
- Read-only, visible sharing state, easy revocation, and honest copied-data limits.
- Sharing failure never blocks private tracking.

### P3.4 Optional encrypted sync

Cross-device continuity can be valuable, but it must preserve local use, resolve conflicts, support deletion propagation, and explain recovery/encryption accurately. Do not turn it into mandatory cloud storage.

### P3.5 Research or clinical partnerships

Only with explicit consent, ethical review, data minimization, and a clear user benefit. Never weaken the no-advertising/no-health-analytics promise by default.

---

## 7. What not to build or claim yet

- **Do not claim contraception or “safe days.”** Natural Cycles’ position rests on regulated evidence and biometrics.
- **Do not claim confirmed ovulation or hormone levels** from calendar dates.
- **Do not build an unbounded medical chatbot.** Keep AI attached to selected facts and specific jobs.
- **Do not add a social feed/community before moderation, safeguarding, and privacy capacity exist.**
- **Do not add every symptom to onboarding.** Breadth belongs in customizable tracking, not activation.
- **Do not use streaks, fear, or paywall teasers to force daily engagement.** Menstrual tracking is cyclical, and missing data is not failure.
- **Do not call local storage automatically safer in every respect.** It lowers server exposure but increases device-loss/recovery risk.
- **Do not silently delete or exclude “outlier” cycles.** Use visible dated factors and user correction.
- **Do not expand remote analytics with exact dates, symptoms, sex, questions, or AI outputs.** Measure product quality with minimal, content-free, consented signals.

---

## 8. Recommended sequence

### Milestone A — Trustworthy public beta

1. Current full regression and device/accessibility matrix.
2. Public privacy/support surfaces and App Store disclosure reconciliation.
3. Gateway/privacy/safety evidence.
4. Account-model decision.
5. Onboarding compression and current daily-flow polish.

### Milestone B — Best private daily tracker

1. Personalized unified check-in.
2. Period-start/end continuation polish.
3. Dated cycle factors.
4. Contraception/medication logs and reminders.
5. Appointment report PDF/CSV.
6. JSON import and recovery design.

### Milestone C — Life-stage differentiation

1. Perimenopause/cycle-change mode.
2. Postpartum/breastfeeding mode.
3. Small evidence-reviewed learning library.
4. Localization foundation and first target languages.
5. Apple Watch/widget/Shortcut convenience.

### Milestone D — Evidence-heavy expansion

1. Biomarker layer and richer Health integrations.
2. TTC research/validation program.
3. Pregnancy/loss journey.
4. Granular sharing and optional sync if user evidence supports them.

Do not begin Milestone D simply to complete a competitor matrix. Each program needs a target segment, safety owner, maintenance plan, acceptance criteria, and evidence that users will choose or stay with Cecy because of it.

---

## 9. Success metrics that preserve privacy

Prefer on-device counters, voluntary studies, App Store aggregates, and content-free service operations. Never upload exact dates, symptoms, sexual activity, profile answers, free text, or AI responses for generic product analytics.

| Outcome | Suggested measure | Privacy-preserving approach |
|---|---|---|
| Activation | Setup completion and time to first saved record | On-device; voluntary aggregate cohort without answers/dates |
| Daily ease | Median taps/time to complete chosen check-in | Moderated synthetic usability study; optional coarse telemetry |
| Record confidence | Edit/delete success, failed saves, duplicate prevention | Local QA counters or content-free error codes |
| Forecast trust | User can distinguish record vs estimate and explain uncertainty | Structured comprehension study, not click count |
| Long-term value | Return across 2, 3, and 6 cycles | On-device cohort state or explicitly consented research panel |
| Insight value | Helpful/not helpful and evidence opened | Local rating; optional aggregate result without insight type/content |
| Appointment value | Summary prepared/shared and clinician usefulness feedback | Local event plus voluntary post-visit survey |
| Privacy trust | Users correctly identify what stays local and what AI sends | Comprehension test and support themes |
| Reliability | Crash-free sessions, migration success, save latency | Apple diagnostics/content-free technical metrics with consent |
| AI quality/cost | Successful task, latency, refusal/error, user-rated usefulness | Gateway aggregates by operation only; no prompt/output retention by default |
| Accessibility | Essential task completion with VoiceOver/large text | Regular expert/device acceptance and participant studies |

Suggested product targets should be baselined before numeric commitments. Avoid vanity metrics such as daily streak length or AI request volume.

---

## 10. Research plan before major expansion

Conduct two rounds with synthetic or participant-owned data; never ask participants to expose more health information than necessary.

### Round 1 — Core positioning and usability (8–12 participants)

Include:

- Regular and irregular cycles.
- Privacy-sensitive users.
- At least two VoiceOver or large-text users.
- People currently using Apple Health, Flo, Clue, Stardust, Ovia, or Euki.

Tasks:

1. Set up with known, unknown, and irregular history.
2. Log the start, continuation, spotting, and end of a period.
3. Log/edit/delete multiple symptoms and a sensitive record.
4. Explain a calendar estimate versus a record.
5. Correct a missed/historical period.
6. Prepare and redact an appointment summary.
7. Find what AI would send and turn it off.
8. Explain what happens on device loss.

Capture comprehension, errors, time, abandonment reason, and why they would choose/stay/leave—not preference alone.

### Round 2 — Concept validation

Test low-fidelity concepts for:

- Continue locally versus Apple linking.
- Unified personalized check-in.
- Dated cycle-factor timeline.
- Medication/contraception adherence.
- Appointment PDF.
- Perimenopause and postpartum modes.
- Import/restore and optional sync tradeoffs.

Do not build TTC, pregnancy, partner sharing, or sync until concept tests identify a specific job and acceptable privacy model.

---

## 11. Concrete strengths to preserve

Future work should not remove or weaken these existing qualities:

1. Recorded facts, estimated dates, and assumed future cycles remain distinct.
2. Unknown and unlogged states remain unknown—not negative answers.
3. Historical corrections recalculate derived information without inventing records.
4. Local functionality remains available when AI is disabled or fails.
5. AI-normalized symptoms require user review and confirmation.
6. Sexual activity, private notes, identity, and Health identifiers stay out of AI context by default.
7. Export categories are opt-in and previewed/explained.
8. Deletion and storage disclosures avoid impossible secure-erasure promises.
9. Accessibility has source-level attention: 44-point targets, labels, focus, announcements, Dynamic Type adaptations, and non-color distinctions.
10. The interface remains calm and avoids an “all pink” stereotype.
11. No advertising SDK or health-event analytics is part of the architecture.
12. Predictions are deterministic, inspectable, and replaceable rather than generated by an LLM.

---

## 12. Final product call

Cecy should define “one stop shop” as **continuity and usefulness**, not an indiscriminate list of features:

- One trusted place to record daily cycle-related experiences.
- One clear explanation of what history supports.
- One private path from uncertainty to a prepared healthcare conversation.
- Gradual support through cycle changes and life stages.

The immediate competitive win is achievable without pregnancy, social feeds, or regulated fertility claims: make Cecy the fastest and clearest private tracker for recording, correcting, understanding, and sharing one’s own evidence. Once that experience is proven, perimenopause, postpartum, biomarkers, Watch convenience, education, localization, TTC, and pregnancy can extend the same trusted model.

---

## 13. Sources

Accessed October 15, 2026 unless otherwise noted.

### Cecy repository

- `cecy/App/TrackerRootView.swift`
- `cecy/App/TrackerSession.swift`
- `cecy/Features/Onboarding/OnboardingFlowView.swift`
- `cecy/Features/Today/TodayView.swift`
- `cecy/Features/Today/DailyLogCard.swift`
- `cecy/Features/Calendar/TrackerCalendarView.swift`
- `cecy/Features/Logging/DailyBleedingEntryView.swift`
- `cecy/Features/Insights/CycleHistoryView.swift`
- `cecy/Features/Insights/AppointmentSummaryView.swift`
- `cecy/Features/AI/AIFeatureView.swift`
- `cecy/Features/Settings/TrackerSettingsView.swift`
- `cecy/Features/Settings/PrivacySettingsView.swift`
- `cecy/Domain/UserProfile.swift`
- `cecy/Domain/Symptoms.swift`
- `cecy/Domain/AppointmentSummary.swift`
- `cecy/Domain/PossibleOvulation.swift`
- `cecy/Data/TrackerSchemaV2.swift` through `TrackerSchemaV7.swift`
- `IMPLEMENTATION_PLAN.md`
- `PRODUCT_READINESS_AND_ENGINEERING_HANDOFF.md`
- `RELEASE_READINESS_VALIDATION.md`
- Current unit and UI test inventory under `cecyTests/` and `cecyUITests/`

### Official competitor and platform sources

- Apple, **Track your period with Cycle Tracking**, published September 14, 2026: https://support.apple.com/en-us/120356
- Flo App Store listing: https://apps.apple.com/us/app/flo-period-pregnancy-tracker/id1038369065
- Flo Privacy Portal: https://flo.health/privacy-portal
- Clue App Store listing: https://apps.apple.com/us/app/clue-period-cycle-tracker/id657189652
- Clue Privacy Policy, updated September 28, 2026: https://helloclue.com/privacy
- Natural Cycles App Store listing: https://apps.apple.com/us/app/natural-cycles-birth-control/id765535549
- Stardust App Store listing: https://apps.apple.com/us/app/stardust-period-tracker/id1495829322
- Ovia Health by Labcorp App Store listing: https://apps.apple.com/us/app/ovia-cycle-period-tracker/id570244389
- Euki App Store listing: https://apps.apple.com/us/app/euki/id1469213846

### Interpretation cautions

- App Store descriptions and privacy labels are developer-provided marketing/disclosures, not independent audits.
- Ratings and selected reviews are snapshots and are not representative research samples.
- Competitor feature presence does not establish quality, clinical validity, safety, or availability in every market/tier.
- Cecy source inspection does not replace current runtime, device, clinical, privacy, or App Store acceptance.
