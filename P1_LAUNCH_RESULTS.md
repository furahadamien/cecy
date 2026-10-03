# P1 launch checkpoint — final results

**October 3, 2026 · Partial completion, not release sign-off.**

This is the final execution record for this checkpoint. It supersedes the in-progress execution rows in [P1_LAUNCH_VALIDATION.md](P1_LAUNCH_VALIDATION.md), which contains the CE-01 implementation/workflow map, field-level AI data-flow audit, document reconciliation and Section 13 release checklist. The original [handoff](PRODUCT_READINESS_AND_ENGINEERING_HANDOFF.md) remains the acceptance reference.

## Scope and changes

Branch: `engineering/p1-launch-readiness`, based on `8e7c654e13b318a7ac92e0c7989467fa424506c0`, plus the uncommitted working-tree changes. No commits or pushes. The pre-existing `.github/agents/Principal Sofware Engineer.agent.md` edit was preserved.

CE-01–07 were treated as first-release quality/verification work, not post-launch feature expansion. No P2/P3, new AI operation, backend, account, subscription, synchronization, sharing, schema or prediction-policy implementation was added. Existing optional AI is not approved for release merely because its client tests pass.

| Evidence-supported fix | Behavior and acceptance | Scope / indicative engineering size | Privacy impact |
|---|---|---|---|
| Calendar list logging | One existing logging group immediately after the selected day, before the remaining month; future guards and sheet selection preserved. Both new largest-text UI cases pass. Grid behavior also passes. | One existing view; small (<1 day excluding device acceptance) | No record, payload or permission changes |
| Onboarding disclosure | Replace the blanket never-cloud statement with local records plus optional, consented online AI processing. Updated disclosure assertions pass in the Apple-cancellation journey. Full successful-onboarding journey remains unresolved below. | One copy change plus existing helper assertions; small | More accurate disclosure; no new consent grant or data transmission |
| AI explanation provenance | Reuse the existing deterministic `InsightCard` before/after requests; display only a still-current insight. Label generated supporting prose as AI interpretation, not verified records. Exact local text remains unchanged through consent decline, success and failure in UI tests. | Two existing views and focused tests; small | No new outbound fields or persisted output |
| Regression accuracy | Preserve 44-point compact target/placement checks, replace invalid accessibility-frame glyph-height assertions with containment, and test the existing recorded-period edit route. | Existing UI tests; small | None |
| Protection-test portability | Keep portable export/backup/cleanup checks running. Move strict complete-protection checks for exports/directories/store/WAL/SHM/nested files into an explicitly skipped Simulator test that must run on a physical iOS device. | Existing unit suite; small | No change to production protection; hardware acceptance is not waived |

Added three passing unit regressions: corrupt SQLite bytes remain intact across failed startup/retry; an unreadable file-backed profile does not erase healthy records; partial signed-out reset/Keychain cleanup is reported honestly and can retry. No storage fix was justified by these tests.

## Executed validation

Environment: macOS 27.0.1 (26A434), Xcode 27.0 (27A266a); iPhone 16e Simulator, iOS 26.2 (23C54), arm64. Deployment remains iOS 17.0 on iPhone/iPad. Only synthetic data and existing test doubles were used; no live AI calls, real Apple authorization, email sends, provisioning changes or uploads.

Artifacts: **`/tmp/cecy-p1.gQXvct`**. Each run retains its log, command file, status and `.xcresult`; machine-readable summaries are retained where noted. Preserve these outside `/tmp` before a release decision.

| Run | Outcome |
|---|---|
| `baseline-units` | App and both test targets compiled. 262 unit tests passed, one failed with four missing file-protection-attribute assertions. The run finalized with exit 65. |
| `reproduction` | Three new integrity/reset tests passed. A temporary probe confirmed the Simulator omits the protection attribute itself. Two compact UI tests reproduced 44-vs-24-point assertion errors; initial calendar helper attempts overscrolled. Probe removed after diagnosis. |
| `calendar-reproduction-and-units` | 266 unit tests passed, one physical-device test skipped. Early-month list placement reproduced: actions around y=10,140.7, next date around y=647.7. Future test still had an unrelated long-distance scrolling dependency, subsequently removed. |
| `calendar-regression` | **Passed:** 266 unit tests plus seven UI scenarios; one physical-device protection test skipped. Summary: 274 total, 273 passed, 0 failed, 1 skipped. Includes both new largest-text cases, both compact logging cases, current/later/context forecast explanations and support navigation. |
| `workflow-regression` | **Failed:** 266 unit tests and 14 of 16 UI scenarios passed; two UI failures; one physical-device protection test skipped. Summary: 283 total, 280 passed, 2 failed, 1 skipped. All five AI UI cases, historical logging, Apple cancellation, edit/delete persistence, export cancellation, app lock and activity CRUD passed. |
| `workflow-failure-recheck` | **Failed again:** the two selected UI scenarios were rerun once, without product changes. Both failed; details below. No further retry loop. |
| `unsigned-release-archive` | **Archive succeeded**, exit 0. `cecy-unsigned.xcarchive` is an unsigned iOS Release build, **not** signed-device or App Store validation. |

Overall: **266 unit tests pass, one physical-device test is explicitly skipped; 21 distinct targeted UI scenarios pass and two remain unresolved.** This is not a passing complete UI suite. The successful scenarios were executed across selected runs, not one passing full-app run.

### Unresolved UI failures

1. `PhaseTwoUITests.testResetCancelThenConfirmReturnsToDurableOnboarding`
   - Failed at `PhaseTwoUITests.swift:23` in the one-direction `reveal` helper, while trying to reach `confirmReset` after typing `DELETE`.
   - Repeated in the focused recheck (44.1 seconds).
   - Source has a confirmation field and conditional destructive button. The failure alone does not establish a deletion/persistence defect or prove keyboard accessibility is adequate.
   - Proposed next diagnostic: keyboard/viewport-aware scrolling, verify the entered value and enabled state, then test actual reset/relaunch. **Attempts to apply this helper change failed in the editor bridge; `PhaseTwoUITests.swift` is unchanged.**
2. `cecyUITests.testCompleteOnboardingLogAndRelaunch`
   - Broad run failed at `OnboardingUITestSupport.swift:95`, waiting for the profile-name field.
   - Recheck advanced further but failed at line 155, waiting for the creating-account message after Apple confirmation. This suggests timing/state investigation is needed; it is not proof of a specific root cause.
   - Apple-cancellation onboarding passed, including the corrected disclosure, but does not substitute for successful first-record onboarding.
   - Recheck with a responsive editor and capture the actual visible step/completion state before changing product behavior or weakening transient-state assertions.

Failed-test attachment export produced no matching attachments; only the manifest was created. The retained logs/result bundles remain the available evidence. No screenshot-based diagnosis is claimed.

## Release artifact inspection

`release-artifact-inspection.json` records inspection of the built archive:

- Bundle `xyz.thabo.cecy`, version 1.0/build 1, minimum iOS 17.0, iPhone/iPad, SDK `iphoneos27.0`.
- Face ID and read-only menstrual-flow HealthKit purpose strings present.
- No `CECY_UI_TEST_ID`, `CECY_UI_APPLE_AUTH`, `CECY_UI_AI` or synthetic-insight fixture strings found in the Release executable. Source also guards fixture composition with `#if DEBUG`; string inspection alone is not exhaustive security verification.
- The old blanket cloud statement is absent from the Release executable.
- No compiled `CFBundleIcons` entry; source icon slots have no filenames. A valid approved release icon is still required.
- No `PrivacyInfo.xcprivacy` in the archive. Focused app-only source search found no direct required-reason APIs listed in the implementation report; do not invent declarations or infer an approved App Privacy label. Final privacy/SDK review remains open.

## CE-01–07 acceptance disposition

| Item | Status at stop |
|---|---|
| CE-01 implementation evidence | Repository/workflow/AI/configuration map recorded with commit/configuration and explicit external gaps. |
| CE-02 records/predictions | Full unit target and representative CRUD/relaunch/migration scenarios pass. New failure-preservation tests pass. Physical timezone-change and actual signed-upgrade/locked-storage acceptance remain open; reset UI acceptance unresolved. |
| CE-03 AI/wellness/privacy | Client provenance/disclosure fixes and mock contract/lifecycle/UI tests pass. Provider/gateway retention/logging/controls, semantic fact preservation, allergy/preference safety and qualified escalation review remain unverified. |
| CE-04 core completion | Representative journeys pass, but successful clean onboarding and complete reset UI acceptance cannot close. Native Apple/Health/Mail/permission and full workflow matrix still require verification. |
| CE-05 calendar | Reproduced placement defect fixed; new and existing selected scenarios pass. Existing forecast explanations were adequate and reused. Physical VoiceOver/narrow-device traversal remains open. |
| CE-06 reliability/accessibility | Unit tests and targeted runtime coverage recorded; two UI failures remain. Physical protection, VoiceOver, Reduced Motion, keyboard/contrast/target matrix, iOS 17/current device coverage and ten-year-history p95 performance measurement remain open. |
| CE-07 release reconciliation | Unsigned Release archive and bundle audit complete. Approved artwork, policy/support URLs and in-app policy link, monitored support delivery, metadata/screenshots/privacy labels, native authorization/deletion requirements and signed distribution validation remain open. |

### Required owner/external evidence — not P2/P3 work

- Actual gateway/provider contracts, processing locations, logging/retention/deletion, rate/abuse/token/cost controls and authorized synthetic safety evaluations. Passing response-schema tests do not enforce allergy exclusions or establish medical safety.
- Approved public HTTPS privacy/support pages and accurate in-app/store disclosures, icon/screenshots/metadata and support monitoring.
- Resolve existing Apple setup/account-deletion obligations. [Apple's account-deletion guidance](https://developer.apple.com/support/offering-account-deletion-in-your-app/) (consulted October 3, 2026) calls for token revocation for apps using Sign in with Apple for account creation/authentication. Current local reset explicitly does not revoke Apple's authorization; local Keychain removal is not equivalent. Do not declare this satisfied or introduce an app-embedded secret/new backend without an approved approach.
- Physical-device acceptance, deployment-floor testing, measured accessibility/performance, and signed archive/distribution validation.

Subscriptions, sync, sharing, new accounts/backends, advanced integrations, product analytics and competitive research remain outside this implementation; their absence is not a release defect.

## Why work stopped / resumption

Xcode's editor bridge began rejecting edits with **“Could not find source editor element”**, including existing Markdown documents and the reset UI test. The fallback editor also failed. Opening the project/source again did not recover it; bounded AppleEvents to Xcode timed out, including after all build/test processes completed. The editor also returned inconsistent/stale source line counts; disk/Git checks verified the app source is not duplicated. Xcode was **not force-quit**, to avoid losing unrelated unsaved work. The simulator is in Shutdown state and no test/archive process remains running.

Consequently, attempted links/updates to `IMPLEMENTATION_PLAN.md`, the original handoff and the intermediate validation report were **not applied**; their historical status is not the final checkpoint. This new file is the durable final record. No reset-helper fix is claimed.

Before stopping, the actual on-disk diffs were reviewed and `git diff --check` passed. App changes remain confined to four view files. Relevant source diagnostics were clear before the editor failure. Build/test results refer to disk contents, not inconsistent editor snapshots.

**Resume with a responsive Xcode session, resolve the two UI failures without weakening behavior assertions, rerun affected tests, then complete the external/device/release gates. All P1 acceptance is not complete.**
