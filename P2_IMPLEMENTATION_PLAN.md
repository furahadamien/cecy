# P2 Implementation Plan — Differentiated Depth

Date: October 15, 2026
Branch: `feat/complete-p1-roadmap`

## Scope authority

This plan implements **P2 — Add differentiated depth** from `COMPETITIVE_PRODUCT_STUDY_2026.md`. The older `PHASE_2_DESIGN.md` is completed historical schema-V2 work; P2 priority labels in the October 3 readiness handoff are research classifications, not this roadmap phase.

## Shared architecture

- Add an additive SwiftData V9 schema containing one validated local P2 payload: life-stage episodes, postpartum bleeding, biomarkers, and insight feedback.
- Keep P2 data in `TrackerSnapshot` so repository transactions, reset, import/export, reports, and session publication share one committed source of truth.
- Treat life-stage modes as presentation/context over explicit dated records, never inferred diagnoses.
- Keep postpartum bleeding separate from menstrual periods and exclude it from cycle calculations.
- Treat biomarkers as records/charts only. They do not alter forecasts or confirm ovulation/pregnancy.
- Store insight feedback locally. No health content or feedback is sent as analytics.
- Provide a curated, versioned, locally bundled education catalog with reviewer/reference/review-date metadata and emergency boundaries.
- Add a String Catalog foundation and locale-aware presentation. Initial translations require native-language and medical-copy review before release.
- Place Health write-back, Watch, widgets, and production App Intent exposure behind explicit capability boundaries until target signing, granular permissions, device testing, and product approval exist.

## Delivery order

1. **P2.1 Perimenopause/cycle-change:** dated mode, tailored symptom set, coverage/change summaries, report context, education links.
2. **P2.2 Postpartum/breastfeeding:** pregnancy-end event, feeding context, distinct lochia/postpartum bleeding, return-of-cycle uncertainty, loss-aware wording.
3. **P2.3 Biomarkers:** BBT, LH, cervical mucus, resting heart rate, sleep duration, pregnancy-test records and local summaries.
4. **P2.4 Apple ecosystem:** granular capability model and safe in-app handoff; no silent Health writes, Widget/Watch exposure, or unconfirmed App Intent commits.
5. **P2.5 Education:** reviewed local catalog, provenance, jurisdiction and emergency boundaries, contextual routing.
6. **P2.6 Localization/inclusion:** String Catalog foundation, locale-aware dates/numbers, RTL/Dynamic Type/VoiceOver-safe layouts, inclusive source copy.
7. **P2.7 Insight quality:** helpful/not-helpful feedback, local reasons, evidence coverage, strength guidance, suppression of dismissed insight IDs.

## Acceptance criteria

- V1–V8 stores migrate to V9 without changing existing records; malformed P2 payloads fail closed.
- Every P2 mutation validates first, commits once, rolls back on failure, and publishes only after commit.
- Reset deletes all P2 data. JSON V9 export/import round-trips P2 data and remains compatible with V1–V8.
- Postpartum bleeding never creates a period or enters interval statistics.
- Biomarkers never change `CycleOverview`, `CycleForecast`, or persisted period facts.
- Life-stage summaries describe saved records and coverage, not diagnosis or measured hormones.
- Education entries expose reviewer, sources, date, scope, and urgent-care boundary.
- Insight feedback remains local and does not alter source records.
- Local tracking works with Health/AI permissions denied and offline.
- Focused P2 tests and the complete unit target pass; physical-device-only protection/Health/Watch/Widget checks remain explicit gates.

## Privacy and safety constraints

- No contraception assurance, safe-day claim, confirmed ovulation, pregnancy diagnosis, hormone inference, or individualized treatment advice.
- Unknown and unlogged remain unknown. No absence is inferred from missing records.
- Health authorization is granular and does not imply AI, export, sync, analytics, or sharing consent.
- New sensitive data uses complete file protection through the existing local store and is excluded from backup.
- Reports and exports include P2 categories only through explicit user-controlled workflows.

## External acceptance gates

- Qualified clinical review of perimenopause, postpartum, loss, heavy-bleeding, pain, and emergency language.
- Native-language review and target-market language selection.
- Signed physical-device HealthKit authorization/read/write testing.
- New WidgetKit/watchOS target provisioning, privacy review, lock-screen review, and device acceptance.
- App Intent phrase/discoverability review and confirmation behavior on supported devices.

These gates are not treated as completed by source code or Simulator tests.