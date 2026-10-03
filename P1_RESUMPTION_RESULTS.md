# P1 resumption — October 3, 2026

**The two unresolved UI journeys in [P1_LAUNCH_RESULTS.md](P1_LAUNCH_RESULTS.md) now pass. P1 remains partially accepted, not release-ready.** This report supersedes that checkpoint's unresolved-test/resumption status only. Its earlier execution evidence and external release gates remain valid. [P1_LAUNCH_VALIDATION.md](P1_LAUNCH_VALIDATION.md) retains the implementation/workflow and AI data-flow maps; the original handoff remains the acceptance reference.

## Scope

- Continued on `engineering/p1-launch-readiness`, based on `8e7c654e13b318a7ac92e0c7989467fa424506c0` plus the existing working-tree changes.
- Preserved earlier P1 app/test changes and the pre-existing `.github/agents/Principal Sofware Engineer.agent.md` edit.
- This resumption changes only three existing UI-test files and adds this report. No new app-code, storage/schema, prediction, networking, account or consent behavior changes. No P2/P3, backend, sync, sharing or subscriptions. App icon remains deferred.
- No commits, pushes, live AI requests, real Apple authorization, email sends or deployment.

## Fixes and evidence

| File | Finding and smallest correction | Acceptance retained |
|---|---|---|
| `cecyUITests/PhaseTwoUITests.swift` | Full-screen upward swipes could start on the open keyboard instead of the form. The bounded helper now drags within the navigation/keyboard/tab viewport and supports both directions. Added exact `DELETE` value and enabled-button assertions. | Initial reset cancellation retains history; explicit confirmation completes deletion; onboarding survives termination/relaunch. Edit/delete/cancel persistence also passes with the changed helper. |
| `cecyUITests/OnboardingUITestSupport.swift` | The polling wait could first inspect after the 1.2-second progress presentation had ended. Check existence immediately before falling back to the wait. Add visible hierarchy to failure diagnostics. | The progress assertion is still required, not replaced by a success-or-progress assertion. Successful completion and Apple-cancellation assertions remain. Production timing is unchanged. |
| `cecyUITests/cecyUITests.swift` | Once onboarding progressed, the old test tapped Save without the now-required New period/Add bleeding days choice. Source disables Save until this choice; the first resumed run consequently still showed `Day 28`. Select `newPeriodEntry`, assert disabled/enabled states, then wait for sheet dismissal. | Saves a new period rather than extending the earlier record; requires `Day 1` both before and after relaunch and the recorded-start calendar marker. The alternate continuation route is independently tested. |

No product bug fix was justified by these failures. The tests now exercise existing approved behavior rather than bypassing its guards. This is bounded regression evidence, not proof that automation cannot be timing-sensitive on other environments.

## Executed results

Environment: Xcode 27.0 (27A266a), iPhone 16e Simulator, iOS 26.2 (23C54), arm64. Debug builds, signing disabled, serial test execution and bounded total/per-test deadlines. All records and service/authentication fixtures are synthetic and isolated from production data.

Artifacts are under **`/tmp/cecy-p1.gQXvct`**. Both runs retain `.command.json`, `.log`, `.status`, `.summary.json` and `.xcresult`. Preserve these outside temporary storage before a release decision.

| Run | Result |
|---|---|
| `resumed-workflow-regression` | Build succeeded; test exit 65. 266 units and 5 of 6 selected UI tests passed; one physical-device protection test skipped. Overall 273 tests: 271 passed, 1 failed, 1 skipped. The sole failure was the newly reached obsolete save step: `XCTAssertEqual failed: ("Day 28") is not equal to ("Day 1")`. Failure evidence is retained, not relabelled as passing. |
| `resumed-final-regression` | **Build and tests succeeded, exit 0.** Overall 270 tests: **269 passed, 0 failed, 1 skipped** — all 266 runnable unit tests plus all 3 selected UI tests. |

Final passing UI scenarios:

1. `cecyUITests.testCompleteOnboardingLogAndRelaunch` — clean onboarding, progress, first relaunch, explicit new-period save, second relaunch and calendar marker (81.339 seconds).
2. `PhaseTwoUITests.testResetCancelThenConfirmReturnsToDurableOnboarding` — cancel, keyboard-visible confirmation, reset and durable onboarding (44.517 seconds; also passed in the preceding run).
3. `HistoricalLoggingUITests.testAddingBleedingDaysKeepsOnePeriodAndPersists` — alternate continuation route, confirmed bleeding, relaunch and editing (36.825 seconds).

Additional UI scenarios passed in the preceding resumed run: Apple cancellation, profile persistence/editing, period metadata/end-date editing with discarded changes, and delete cancellation/confirmation with recalculation. Across the two resumed runs, seven distinct selected UI scenarios passed. **The entire UI target was not run or declared passing.**

`PhaseFivePrivacyTests.completeProtectionCoversExportsStoresAndSidecars` remains explicitly skipped on Simulator and requires physical-device execution; production protection has not been downgraded. The complete unit target includes the existing migration, invalid-store preservation, rollback, reset-failure, deterministic prediction and mock-AI coverage.

Source diagnostics were clear for all three edited Swift files. On-disk diffs were reviewed and `git diff --check` passed. The earlier successful unsigned Release archive covers unchanged app source; no new Release archive or signed distribution validation was performed during this test-only resumption.

## Acceptance disposition

- **CE-02 / CE-04:** The previously unresolved reset and successful clean-onboarding/new-record UI scenarios now pass with persistence evidence. Physical upgrades/timezone changes, native Apple/Health/Mail/permission paths and the complete workflow matrix remain open.
- **CE-06:** The two checkpoint UI failures are resolved in selected simulator runs. This is not minimum-OS, physical VoiceOver/keyboard/Reduced Motion/contrast, locked-storage, airplane-mode or measured dense-history performance acceptance.
- **CE-01 / CE-03 / CE-05 / CE-07:** Earlier implementation maps, fixes and selected test evidence are preserved; no new closure is claimed. Authoritative gateway/provider contracts, retention/logging/abuse/cost controls, semantic/allergy safety and qualified review remain required. Approved public policy/support URLs and in-app policy link, Apple authentication/deletion applicability, artwork/metadata and signed distribution validation remain open.

## Editor limitation

Swift edits succeeded and were verified on disk. Markdown editing still failed: `P1_LAUNCH_VALIDATION.md` returned **“Could not find source editor element”** through both editing paths, and the editor's `IMPLEMENTATION_PLAN.md` snapshot differed from the actual disk contents. Those documents were left unchanged rather than risking overwriting newer content. This new report is the durable resumption record; attempted links to older documents are not claimed as applied. Xcode was not force-quit.
