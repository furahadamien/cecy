# Irregular-cycle support — implementation results

**October 7, 2026 · Daily logging, coverage insights, and appointment summaries implemented; release acceptance remains open.**

Progress follows [the implementation plan](IRREGULAR_CYCLE_IMPLEMENTATION_PLAN.md). The first-slice and Phase 3 sections below are historical; V7 persistence and Phase 4 UI supersede their earlier boundaries. Final validation and remaining gates follow below.

## First slice — delivered

- Setup offers **Choose length / Not sure**, plus **I don’t remember** for the last start. New drafts no longer silently save 28/5 or create a period from an unknown answer. The wheel suggests 28/5 only after an explicit Choose length action.
- Existing predictability choices are available during setup, with wrapping controls instead of horizontal scrolling. This is self-reported context, not new prediction evidence or a diagnosis.
- Review says **“You can track without an estimate.”** Longer setup explanations were removed. Today omits empty forecast cards.
- Explicit unknown answers persist through staged setup, final completion, reopening, and profile edits. Unanswered required choices remain distinct from deliberate unknowns.
- Apple authorization, profile identity matching, name/DOB requirements, registry commit ordering, and completion-last behavior remain enforced. A completed profile with no period history can log its first observation normally.
- A shared `ForecastAvailabilityPolicy` is applied to setup review, published session state, and calendar projections. Widely variable or unsupported recorded timing no longer produces replacement dated forecasts from a saved usual length.
- The existing projection bounds (10–120 days) now also gate the operational primary estimate and its reminder, without rejecting recorded periods or changing interval statistics. These are app display limits, not medical definitions.
- Eligible regular-history and one-start estimates retain the existing median, padding, confidence, and replay mathematics. General phase education remains available when no personalized timeline is available.

## First slice — compatibility boundaries

- SwiftData remains **V6**. No schema definitions, migration stages, store paths, or identifiers changed.
- `LocalProfile.unknownCycleFields` is optional Codable metadata inside the existing profile payload. Missing metadata preserves legacy interpretation; existing 28/5 values are not relabelled or cleared. A present numeric value remains the authoritative known answer; normal UI edits keep its unknown marker aligned.
- The last-start setup answer never deletes recorded history. Later recorded starts take precedence for calculations.
- Existing JSON export formats and AI request contracts are unchanged. New setup metadata is not added to exports or outbound AI context; nil numeric values stay absent rather than becoming zero or a guess. Export still is not a restore mechanism.
- AI consent/catalog v2, daily-attempt reservation, cancellation, network clients, protected storage, reminders’ opt-ins/detail choices, Health import, sexual-activity handling, logout, and reset infrastructure were not redesigned.
- Context-specific fertility suppression beyond the existing rules is **not implemented**. Existing context warnings remain; a broader clinical policy needs separate review.

## First slice — changed areas

Application: `UserProfile`, repository setup completion, the new `ForecastAvailabilityPolicy`, `LocalDay`’s unavailable-estimate message, `PossibleOvulation`, `TrackerSession`, onboarding length/predictability controls, and Today’s empty-state presentation.

Tests: explicit known-value fixtures in existing setup/registry suites; replacement of the intentionally removed dated-fallback expectations; new `IrregularCycleSetupTests.swift` and `IrregularCycleSetupUITests.swift`; known-choice and lazy-heading corrections in onboarding helpers; historical logging regression updated for withheld timing.

No project configuration, entitlement, dependency, backend, signing, or production data changes. No commits or pushes.

## First slice — executed validation

Environment: Xcode 27.0, iPhone 16e Simulator, iOS 26.2. Isolated synthetic records, clocks, Apple/Health/AI/registry doubles; no live service requests or real account/health operations.

| Run | Result |
|---|---|
| Baseline full unit target | **331 passed, 0 failed, 1 skipped** (332 declarations). |
| Initial implementation full unit target | **343 passed, 0 failed, 1 skipped** (344 declarations), including 12 new tests. |
| Initial six UI scenarios | **4 passed, 2 failed.** Both largest-text failures came from a helper requesting an offscreen lazy-form heading. Failure artifacts retained. |
| Final combined regression | **349 passed, 0 failed, 1 skipped** (350 declarations): all 343 runnable unit tests and all six selected UI tests passed together. Includes the final registry-order assertions. Exit 0. |
| Generic iOS Release build | **Succeeded**, signing disabled, exit 0. Build only—not an archive, device install, or distribution validation. |

Final passing UI scenarios:

1. Unknown answers at the largest Dynamic Type size, Apple completion, and profile access.
2. Unknown/no-history setup, relaunch, first period save, second relaunch, and calendar marker.
3. Existing known-cycle onboarding, new period, and relaunch.
4. Known cycle/period wheels at the largest text size.
5. Historical short interval retains both records without a dated fallback; future logging remains disabled.
6. Adding bleeding days preserves one period and survives relaunch/editing.

The helper now checks whether the heading exists before reading it; Continue/Get started and the existing privacy/account assertions remain. No product behavior or safety assertion was removed to resolve those failures.

The physical-device protection test remains explicitly skipped on Simulator. The final result reports no runtime warnings in this selected run; this does not close previously documented warnings in other workflows. Existing unrelated test/compiler warnings and the AppIntents metadata warning remain outside this change.

Artifacts: `/tmp/cecy-irregular-20261007`. Command files, logs, statuses, result bundles, and summaries retain both failed and successful runs. Preserve them outside temporary storage before a release decision. Top-level totals count declarations; parameterized invocation totals are larger.

## Phase 3 — daily model and migration

Implemented behind the existing UI; no new entry controls, calendar markers, or explanatory screens.

- One explicit answer per civil day: bleeding, spotting, no bleeding, or unsure. Missing records remain unrecorded. Optional flow belongs only to bleeding; episode flow stays independent.
- Additive **SwiftData V7** and V6→V7 migration. Historical model definitions, store paths, and existing IDs are unchanged. Old periods never generate daily observations.
- Optional period links must match confirmed spans. Unknown ends do not extend evidence. Spotting/no-bleeding inside a recorded span requires reviewed correction; unsure is not a negative answer.
- Repository writes validate both models. Coupled changes commit once or roll back together; stale reviews fail without overwriting newer records. Period deletion requires review when linked answers exist; its default proposal retains and unlinks them.
- Session operations use the existing mutation guard and publish only after commit. Daily answers do not become cycle-start evidence or expand AI payloads.
- Reset includes daily records. JSON exports containing daily answers use **format 7**; exports without them retain existing version selection and privacy opt-ins. Export is not restoration.

Changed areas: `DailyBleeding`, `TrackerSchemaV7`, migration registration, repository/snapshot/session APIs, export encoding, and focused daily/migration tests. No Phase 4 UI, backend, dependency, entitlement, or signing changes.

### Phase 3 validation

Environment: Xcode 27.0, iPhone 16e Simulator, iOS 26.2; isolated synthetic fixtures. Baseline HEAD remains `dc32512` with the implementation in the working tree.

| Run | Result |
|---|---|
| Phase 3 baseline full unit target | **343 passed, 0 failed, 1 skipped**. |
| Earlier combined regression | **370 passed, 0 failed, 1 skipped**. |
| Final continuation regression, including latest test edits | **370 passed, 0 failed, 1 skipped**: 364 runnable unit tests plus all six setup/history UI cases listed above. `TEST SUCCEEDED`; result bundle reports Passed with no runtime warnings. |
| Generic iOS Release build | **Succeeded**, signing disabled, exit 0. Application sources did not change afterward; subsequent test-only edits are covered by the continuation regression. |

Top-level totals count declarations. The final bundle reports 421 passed parameter-expanded invocations and one skipped check. The 21 additional test declarations include all six V1–V6 migration arguments.

Verified cases include:
- All six V1–V6 on-disk upgrade paths preserve supported records, profile payloads, completion state, and receipts; explicit daily save, reopen, reset, and reopen pass.
- Fresh-store states, future/duplicate rejection, coupled create/edit/delete, stale review, injected save/reset failure, durable rollback, corrupt-store preservation, export privacy, and unchanged AI context.
- Existing known/unknown onboarding, largest-text setup, historical logging, continuation, and relaunch.

Artifacts: `/tmp/cecy-irregular-phase3-20261007`, including `continuation-regression.xcresult`, its summary JSON, Release log/status, source fingerprints, and scoped diff. Temporary artifacts must be preserved outside `/tmp` for release sign-off. The AppIntents metadata warning remains; this does not close unrelated historical warnings.

The roadmap and this handoff were updated using guarded filesystem replacements after both editor-based Markdown methods failed. No application or test source was changed during this final continuation.

## Phases 4–5 — delivered

- Shared daily editor in Today and Calendar: bleeding, spotting, no bleeding, or not sure; optional daily flow and reviewed period links. No automatic cycle starts or invented daily history.
- Historical edits, explicit conflict review, cancellation, relaunch, and episode deletion retaining/unlinking daily answers. Coupled changes use atomic reconciliation.
- Shared markers, selected-day details, and daily history. At accessibility text sizes, Calendar puts selected-day details beside that day's actions, not after the entire month. Summary sharing and daily legend actions have 44-point minimums.
- Local 30/90-day recording coverage, with separate unlogged and unsure counts. Existing interval/duration statistics remain episode-based.
- Deterministic appointment summary with chosen dates/sections, exact preview, and native sharing. Symptoms, current context, and private notes default off. Identity and sexual activity are excluded; profile context is current, not a historical timeline.
- Sharing reuses protected export files and cleanup. JSON format 7, reset, AI allowlists/consent, existing reminder choices, and Apple/registry flows retain their established boundaries.

## Phase 6 — executed validation, not release sign-off

Verified saved result bundles and logs during the final continuation. No new test/build run was needed: the iPad rerun had already completed. Environment: Xcode 27.0; iPhone 16e and iPad Pro 13-inch (M5) simulators on iOS 26.2, isolated synthetic fixtures.

| Run | Result |
|---|---|
| Initial broad run | 393 passed, 11 failed, 1 skipped; includes canceled tests. Not a complete pass. |
| Serial full run before final corrections | 471 passed, 10 failed, 1 skipped. Failure evidence retained. |
| Final affected iPhone run | **399 passed, 0 failed, 1 skipped**: 373 runnable unit tests and 26 selected UI tests. All ten serial-full failures passed in this rerun. |
| Initial iPad check | Nine unit tests passed; Calendar UI check failed because navigation lookup assumed a TabBar. |
| Final iPad check | **10 passed, 0 failed**: nine focused unit tests plus Calendar grid identity/selection across all leading offsets, using a platform-neutral button lookup. |
| Final unsigned Release archive | **Succeeded**, exit 0. Inspection found no tested Debug fixture markers or bundled tests; supports iPhone/iPad and declares iOS 17 minimum. Not signed distribution validation. |

Totals count test declarations, not parameter-expanded invocations. The full UI target has **not passed in one run on the final source**. The selected pass must not be represented as a full-suite pass. Simulator file-protection skip remains a device gate.

Final fixes preserved behavioral assertions: updated legend counts and explicit onboarding answers, accurate primary forecast/detail expectations, actual switch-value checks, lazy-list/search/navigation handling, save completion before relaunch, accessible summary actions, and reachable large-text Calendar details. Period-deletion confirmation retains entire-period scope and discloses retained daily answers.

The 49-file final source fingerprint matches current application/unit-test sources. Only `cecyUITests.swift` differs, for the final iPad selector adjustment covered by the passing iPad rerun. No application changes followed the final archive. Existing AppIntents/compiler warnings and historical runtime warnings are not blanket-closed by these checks.

Evidence: `/tmp/cecy-irregular-final-20261007`, especially `final-affected.xcresult`, `ipad-grid-final.xcresult`, `serial-full.xcresult`, `release-final-archive.log`, `final-archive-inspection.json`, and `final-source-fingerprints.json`. Durable copy: `/Users/furahadamien/Dev/cecy-validation/irregular-final-20261007.tar.gz` (archive listing verified; includes failed/passing result bundles and the final unsigned archive, excludes rebuildable caches).

## Remaining work and limitations

- Freeze the candidate and obtain a clean full unit/UI run before release; keep earlier full failures separate from passing focused checks.
- Clinical guidance and broader context-specific fertility policy require qualified review and are not implemented. Approximate dates, context epochs, additional check-in/questionnaire flows, extra reminder schedules, and new AI fields remain deferred.
- Physical file protection is skipped on Simulator, not passed. Signed/device upgrade, manual VoiceOver/contrast/reduced-motion checks, dense-history performance measurement, native services, minimum-OS and broader iPad coverage, and release acceptance remain open. The iPad smoke is not comprehensive tablet acceptance.
- Existing public-policy, registry authorization/disclosure, Apple revocation, and provider retention/safety release concerns are unchanged.
- After a V7 upgrade, do not assume an older binary can open the store. Prefer a forward correction; hiding UI is not database rollback. Never erase a failed store to make migration succeed.
