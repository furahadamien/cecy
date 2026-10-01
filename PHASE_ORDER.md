# Cecy — Agreed remaining phase order

October 1, 2026 · User-directed AI gateway handoff update

## Authoritative execution order

**AI implementation resumed October 1 after the user authorized all five handoff features.** Local prerequisites are complete; all five iOS paths are implemented. The continuation run passed all 62 focused unit/storage/transport tests and all four AI UI scenarios together; Debug and a fresh unsigned iOS Release build also passed. See [PHASE_8_VALIDATION.md](PHASE_8_VALIDATION.md). No new backend or live gateway requests. Earlier wait-for-review instructions are superseded; prototype/device acceptance is not waived.

The September 30 deferral of regression resolution and baseline/Phase 6 acceptance remains in effect, superseding the immediate next step in the earlier **6 → 9A → 9B → 8 → 7** sequence. The October 1 handoff supplies the deployed `cecyaiendpoints` Azure gateway and five tasks. Reuse that service; do not create a backend or select a model in the iOS client. [PHASE_8_AI_IMPLEMENTATION_PLAN.md](PHASE_8_AI_IMPLEMENTATION_PLAN.md) remains the AI plan. Its missing local data prerequisites were implemented first. The subsequent, newly authorized AI work is recorded in PHASE_8_VALIDATION.md; no live gateway requests were made during implementation. Track work and deferrals in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md).

| Order | Phase | Scope |
| --- | --- | --- |
| Complete — local prerequisite implementation | Pre-8 | Digestive changes and optional wellness profile preferences; 45 focused unit/storage tests, three UI flows across reruns, Debug and unsigned Release builds passed; manual/baseline gates still open |
| Implemented — focused checks passed; contract/release gates open | 8 | Existing-gateway foundation/consent, confirmed normalization, explanations, wellness, summaries and bounded questions. Live contract/prototype/device gates remain open |
| Deferred — resume checkpoint not yet agreed | Baseline / 6 | Regression resolution and outstanding device/Phase 6 acceptance; still required before release |
| Deferred | 9A | Optional personal cloud synchronization |
| Deferred, after 9A | 9B | Optional partner sharing, a separate project from personal synchronization |
| Last | 7 | Subscriptions, after preceding features and stabilization/polish meet acceptance criteria |

## Product-quality gate before subscriptions

Prioritize a complete, dependable, polished app before monetization. Do not introduce paywalls, StoreKit infrastructure, or monetization-driven restrictions during Phases 6, 9, or 8.

Before starting Phase 7:

- [ ] Complete and validate the agreed scope of Phases 6, 9A, 9B, and 8.
- [ ] Resolve known blocking defects and outstanding baseline acceptance gaps.
- [ ] Pass critical-flow, migration, persistence, offline, failure/recovery, and lifecycle tests.
- [ ] Complete signed-device privacy, permissions, backup, deletion, and data-protection verification.
- [ ] Review accessibility, usability, visual consistency, performance, and reliability across supported devices and OS versions.
- [ ] Complete a dedicated stabilization and polish pass, then review readiness before starting subscription implementation.

These are measurable quality gates, not a promise that software can be defect-free. Basic prediction, privacy controls, deletion, and access to personal data remain available without a subscription. Expiring premium access must not remove records.

## Boundaries preserved across the new order

- HealthKit authorization does not authorize cloud synchronization, partner sharing, or AI processing. Each needs its own consent and disclosure.
- Phase 9A and Phase 9B retain independent designs and lifecycle tests. Partner access begins read-only and shares only explicitly selected information, not the private database.
- Sexual activity, private notes, HealthKit records, and other sensitive categories remain private by default. Personal-sync, partner-sharing, export, and AI inclusion rules must each be designed explicitly; one consent must not imply another.
- Local tracking must remain usable when optional integrations are disabled, denied, offline, or unavailable.
- Existing privacy, accessibility, reliability, and medical-language requirements still apply to every phase.

## Current starting state

Phase 5, onboarding/UX/activity refinements and Phase 6 read-only HealthKit import are implemented and merged. The user reports the existing AI gateway deployed/tested; iOS integration now implements all five tasks; focused tests are recorded in PHASE_8_VALIDATION.md, not a release sign-off. The October 1 handoff has been reconciled with SwiftData V6 and the proposed plan on `planning/phase-8-gpt`. Backend test claims do not establish iOS acceptance. Anonymous access without rate limiting/quotas remains a separate prototype hardening/release gate, not a request to implement new backend infrastructure.

Regression fixes and signed-device validation are explicitly deferred, not complete; see [PHASE_5_VALIDATION.md](PHASE_5_VALIDATION.md), [ONBOARDING_MILESTONE.md](ONBOARDING_MILESTONE.md), and [PHASE_6_VALIDATION.md](PHASE_6_VALIDATION.md). Historical full-suite results remain 113/114 unit and 19/30 UI tests passing; that full baseline has not been rerun here. Focused local-prerequisite validation is recorded separately in LOCAL_WELLNESS_PREREQUISITES.md. Reordering does not waive release gates or feature-specific testing.

The completed local prerequisite detour added digestive-change tracking and wellness preferences without networking. Subsequent Phase 8 work adds optional, consented AI processing; it adds no cloud synchronization, backend resources or subscriptions.
