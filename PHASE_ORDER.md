# Cecy — Agreed remaining phase order

September 30, 2026 · User-directed roadmap update

## Authoritative execution order

**Phase 6 → Phase 9A → Phase 9B → Phase 8 → Phase 7.**

This sequencing supersedes the original numerical delivery order in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md). Keep phase numbers and their task definitions stable so existing references remain valid. Implement and validate one phase at a time, not all remaining phases in one change.

| Order | Phase | Scope |
| --- | --- | --- |
| 1 — next | 6 | Optional HealthKit integration; preparation and proposed scope in [PHASE_6_DESIGN.md](PHASE_6_DESIGN.md) |
| 2 | 9A | Optional personal cloud synchronization |
| 3 | 9B | Optional partner sharing, treated as a separate project from personal synchronization |
| 4 | 8 | Bounded, opt-in AI explanations grounded in deterministic local findings |
| 5 — last | 7 | Subscriptions, after the preceding features and a dedicated stabilization/polish pass meet acceptance criteria |

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

Phase 5 and the pre–Phase 6 onboarding/UX/activity refinements are implemented and merged. Phase 6 preparation is on `phase-6`; HealthKit implementation has not started. The older implementation plan's “Phase 5 not started” and “Phase 6 deferred” status text is stale.

Outstanding iOS test execution and signed-device validation remain open; see [PHASE_5_VALIDATION.md](PHASE_5_VALIDATION.md), [ONBOARDING_MILESTONE.md](ONBOARDING_MILESTONE.md), and [PHASE_6_DESIGN.md](PHASE_6_DESIGN.md). Reordering phases does not mark those checks complete.

This change records sequencing only. It adds no capabilities, permissions, network services, AI requests, or subscription code.
