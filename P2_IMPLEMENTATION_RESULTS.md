# P2 Implementation Results — Differentiated Depth

Date: October 15, 2026
Branch: `feat/complete-p1-roadmap`
Plan: `P2_IMPLEMENTATION_PLAN.md` (scope from `COMPETITIVE_PRODUCT_STUDY_2026.md`, P2.1–P2.7)

## Summary

All seven P2 workstreams are implemented to the extent possible in this repository and Simulator. Work that needs clinical sign-off, native-language review, new signed targets, or physical devices is listed under **External gates** and has not been treated as complete.

## Shared foundation

- `TrackerSchemaV9` adds one validated local payload (`P2DataRecord`) with a lightweight V8 → V9 migration. Existing records are unchanged.
- `P2Data` lives in `TrackerSnapshot`, so P2 records go through the same transactional load/save, rollback, import, reset, and session publication paths as P1.
- Malformed P2 payloads fail closed on load, save, and import.
- Storage remains local, excluded from backup, and protected by the existing file-protection policy.

## Delivered by workstream

### P2.1 Perimenopause / cycle change

- Dated cycle-change life stage you can add, edit, and end.
- The daily check-in suggests stage-relevant symptoms (hot flashes, night sweats, vaginal dryness, sleep, mood, brain fog, urinary discomfort, libido) after pinned symptoms; hidden symptoms stay hidden.
- Summary shows daily-answer coverage, relevant symptom days, and recorded interval ranges before vs. during the stage, but only when at least two completed intervals exist on each side.
- Included in forecasts by default (the change is what is being observed); can be excluded.
- No diagnosis, hormone inference, or measured-phase claims.

### P2.2 Postpartum and breastfeeding

- Dated birth/pregnancy-end stage with optional feeding context; a separate breastfeeding/chestfeeding stage.
- Postpartum bleeding (lochia, spotting, bleeding, not sure) is a separate record type. It never creates a period and never enters cycle statistics.
- Postpartum and feeding stages exclude overlapping intervals from forecast averages by default. The exclusion is visible and reversible, and period records are never changed.
- Summary reports the first period start recorded after the stage began, or states that none is recorded and Cecy does not predict return.
- Wording explicitly includes pregnancy loss and invites recording only what helps.
- Editing that would leave postpartum bleeding outside a postpartum stage is blocked with an explanation.

### P2.3 Biomarkers

- Records for basal body temperature, LH tests, cervical mucus/discharge, resting heart rate, sleep duration, and pregnancy tests: add, edit, delete.
- Temperatures are stored in °C and shown/entered in °F when the profile uses imperial units; number entry respects the device locale.
- Provenance (entered in Cecy vs. Apple Health) and source labels are shown.
- 90-day chart with coverage and range; gaps are described as unrecorded days, not normal or abnormal values.
- Biomarkers never change the forecast or confirm ovulation, pregnancy, fertility, or safe days. Tests verify this.

### P2.4 Apple ecosystem

- New **Shortcuts/Siri action, “Open daily check-in”** (`CecyShortcuts.swift`). It only opens the check-in; nothing is saved until the user reviews and taps Save. App lock still applies. Cold launch is handled by a pending route the root view consumes.
- An in-app integrations screen lists each capability and why it is or isn’t enabled.
- Health biomarker reads, Health write-back, widgets, and Apple Watch remain disabled (see External gates).

### P2.5 Education

- Eight local articles: cycle estimates, irregular cycles and missing records, heavy bleeding and pain, contraception and bleeding, perimenopause, postpartum bleeding and cycle return, breastfeeding and cycle return, preparing for an appointment.
- Each shows author, reviewer, references, last-updated date, scope limits, and a when-to-seek-care section.
- Searchable library; articles are linked from each life stage and from postpartum bleeding.
- Every article shows a **“Draft awaiting qualified clinical review”** banner. A test keeps this flag in place until a named clinician signs off.

### P2.6 Localization and inclusive language

- `Localizable.xcstrings` String Catalog added; new P2 domain strings use `String(localized:)`, and SwiftUI literals are extracted automatically.
- English plural rules added for count strings; the build produces `en.lproj/Localizable.stringsdict`.
- Translator comments mark medical and “unknown means unknown” copy as requiring native-language clinical review.
- Inclusive wording: breastfeeding/chestfeeding, a pregnancy-end date that includes loss.
- Dates use the app’s existing local-day convention; numbers and units are locale-formatted.

### P2.7 Insight quality

- Helpful / not-helpful with optional structured reasons, stored only on the device.
- Feedback is keyed to an **evidence fingerprint**: a “not helpful” observation stays hidden until new records change its evidence, then reappears. Hidden observations can be shown again at any time.
- Material changes (cycle length, variability, bleeding duration) are listed before symptom timing; repeated evidence ranks above limited evidence.
- Each insight shows its evidence coverage and what would make it stronger.
- Feedback never changes health records and is never sent anywhere.

### Portability and reports

- JSON export/import format **V9** includes life stages, postpartum bleeding, biomarkers, and insight feedback, with exact timestamps. Notes are included only when the user chooses. V1–V8 files still import; unknown future versions are rejected.
- Imported P2 data merges using the same conflict strategies as P1 and is fully validated before preview (e.g., orphaned postpartum bleeding or mismatched units are rejected).
- Appointment report: new optional **Life stages** and **Biomarker records** sections. They are off by default and their toggles appear only when such records exist. They are included in the text, CSV, and PDF formats.

## Defect found and fixed: forecasts disappearing with exclusions

The new P2 tests found a defect present since P1. The prediction engines require a continuous sequence of intervals ending at the latest period start. When a cycle factor (P1) or life stage (P2) excluded an interval **in the middle or at the end** of history, validation failed and the **forecast disappeared completely**. A typical case is an ongoing postpartum stage.

Fix (`CycleCalculator.forecastChain`): the displayed intervals keep their real dates, while the engine receives the included interval lengths re-chained backwards from the latest start. Only included evidence is used, and behavior is identical when nothing is excluded. Covered by `postpartumStageIsAVisibleReversibleForecastExclusion` and `ongoingPostpartumStageKeepsForecastFromEarlierEvidence`.

## Validation

- New `cecyTests/P2RoadmapTests.swift`: 18 domain tests (one parameterized) and 3 repository tests. They cover forecast exclusion and reversal, postpartum and biomarker forecast isolation, validation failing closed, life-stage summaries, check-in tailoring, unit conversion and trends, education metadata, Apple capability gating, insight hiding and resurfacing, V9 round trip, import rejection, report sections, persistence, rollback, reset, transactional import, and on-disk V8 → V9 migration.
- Focused P2 + P1 + forecast suites: **27 passed, 0 failed.**
- Full unit target (`cecyTests`, serial): **451 tests in 84 suites passed, 0 failed, 1 expected skip.** The skip checks file-protection attributes, which Simulator does not expose.
- Clean app build succeeded; the String Catalog compiles into the bundle.

### Test-environment note

Parallel test runs left about 120 cloned-simulator processes running and pushed the machine past its per-user process limit (`fork failed`). The final run used `-parallel-testing-enabled NO` after the simulator services were reset. Use serial runs, or reset simulators between parallel runs, on this machine.

## External gates (not complete)

- Qualified clinical review of all education articles and of the perimenopause, postpartum, loss, heavy-bleeding, and emergency copy; replace the reviewer placeholder and set `isClinicallyReviewed`.
- Choose target languages from market research; native-language medical review before shipping any translation; RTL, Dynamic Type, and VoiceOver acceptance in each language.
- Apple Health biomarker read and write-back: per-type authorization design, provenance/deduplication/loop prevention, and signed physical-device testing.
- WidgetKit and watchOS targets: provisioning, discreet lock-screen review, and accessibility acceptance.
- Shortcut phrase discoverability and check-in behavior on supported devices.
- Physical-device verification of file protection for the V9 store.
- UI tests for the new P2 screens (add/edit flows, chart, feedback sheet) were not added in this pass.
- Existing AI actor-isolation warnings remain (pre-existing; not addressed in P2).
