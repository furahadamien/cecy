# Final engineering cleanup — October 3, 2026

**Status: scoped cleanup and validation complete. Not engineering-ready for public release.**

Scope: final engineering cleanup only; no new product features, storage model/migration, backend, authentication redesign, analytics, sync or monetization. Existing P1 and icon work and the user's agent edit are preserved. Branch: `engineering/p1-launch-readiness`; HEAD: `8e7c654e13b318a7ac92e0c7989467fa424506c0` plus the dirty working tree. No commits, pushes or submissions.

Acceptance: `PRODUCT_READINESS_AND_ENGINEERING_HANDOFF.md`, especially CE-02–07 and the Launch Definition of Done. `RELEASE_READINESS_VALIDATION.md` records the earlier full suite, not results of this cleanup. Its deferred-icon finding predates the now-completed icon work.

## Inspection and plan

Reviewed active composition, lifecycle, SwiftData repository and migration plan, privacy/Keychain/reset paths, Apple Health and reminder wrappers, AI client/coordinator/models, calendar/form controls, release configuration and the fifteen previously failing UI tests. Searched source/configuration for logging, debug flags, force unwraps, unsafe concurrency patterns and credential literals. Rechecked suspicious search results against actual source and target membership rather than accepting them as defects.

Priorities:
1. Close the confirmed reset mutation-exclusion gap and validate data integrity.
2. Remove internal-only copy from Release without removing privacy/medical limitations.
3. Repair demonstrated stale/ambiguous UI automation while preserving behavioral acceptance.
4. Run all unit tests and targeted UI regressions; archive and inspect the final Release product.
5. Document unresolved external/device evidence rather than inventing compliance or performing speculative refactors.

## Material findings and fixes

### EC-01 — Reset reentrancy and pending-save exclusion (high; data integrity)

`TrackerSession.deleteAllAndWait()` previously awaited notification cleanup with `isSaving == false`. A concurrent caller could enter another mutation during reset. Reset could also overtake the 50 ms presentation suspension before a pending save. UI disabling is useful but is not a substitute for enforcing the session API's mutation boundary.

Fix in `cecy/App/TrackerSession.swift`:
- Hold `isSaving` across asynchronous reset cleanup, releasing it without a suspension immediately before the existing synchronous deletion transaction.
- Reject reset while another mutation/prediction update is active; reject logout during a pending prediction update.
- If the reset task is cancelled before deletion, retain records and report that reminders may already have been disabled.
- Preserve existing cross-system partial-failure messages, rollback behavior and signed-out reset path.

`cecyTests/FinalEngineeringTests.swift` covers paused reminder cleanup, rejected concurrent mutations, cancellation preserving an existing record, guard release and pending-save exclusion. The pre-fix run recorded reset-guard failures. That first fixture also used the host timezone incorrectly; it was corrected to UTC before final validation. Its separate future-date failures are **not** counted as product defects. Xcode stalled after Swift Testing reported completion; the owned runner was terminated after graceful signals did not finish it. The pre-fix log is retained, but it is not a cleanly finalized suite result.

### EC-02 — Internal prototype copy compiled into Release (submission quality)

`TrackerSettingsView.swift` now confines the internal/synthetic-only About notice to `#if DEBUG`; the version row no longer labels all builds “Prototype.” `AISharedViews.swift` describes the optional online service without a stale prototype designation. External processing, consent, provider-policy, fallibility, medical and local-tracking limitations remain. Removing internal build copy is **not** a claim that external release gates have passed.

### EC-03 — Stale and ambiguous UI regressions (maintainability/acceptance)

Corrections are limited to the demonstrated failure paths:
- A stable `selectedCalendarDetails` container scopes the selected date separately from repeated upcoming forecast text; the test also opens uncertainty details and checks the no-safe-days warning.
- Ordinary-size logging checks targets, non-overlap and position below predictions; the existing accessibility-size vertical-layout test remains.
- Period tests choose New period explicitly rather than bypassing the continuation guard.
- Repeat logging verifies the existing edit form and durable interval count rather than requiring an obsolete duplicate-error presentation.
- Future activity logging is verified as present **and disabled**, not incorrectly required to be absent.
- The Today window check uses the remaining window beginning on fixture today, September 29.
- Unknown-end checks target the current “End not recorded” badge.
- Native logout confirmation is scoped, wheel-collapse checks wait for state changes, and date-strip movement is bounded rather than a fling.
- `UIViewport.swift` provides bounded margin-based scrolling for affected lazy-form scenarios, away from interactive rows; rating controls are revealed before requiring their existence.
- Reminder tests tap the actual switch thumb and verify the draft state before saving. Activity cancellation checks a real changed draft before requiring the discard alert.

No tests are skipped or acceptance assertions removed simply to obtain a green result. Earlier full-suite results are retained; new results apply only to the tests actually executed.

## Audit dispositions

| Area | Finding / disposition |
|---|---|
| Compiler diagnostics | Debug compilation and unsigned Release archive succeeded. No Swift compiler warnings/errors observed. Release emits one non-blocking AppIntents metadata-extraction warning because the app does not use AppIntents; no dependency added or warning suppressed to silence it. |
| Dead code | `Persistence.swift` is the excluded timestamp-template store, not active tracker persistence. No deletion or broad cleanup was justified. |
| Debug flags / fixtures | Production composition is explicit. UI fixtures and environment switches are Debug-guarded. Actual Release executable inspection found none of the checked fixture markers or internal prototype/synthetic-only notices. |
| Logging / secrets | No active app health-payload logging or high-confidence embedded credential matches found in inspected source/configuration. This is not a server-side logging audit. The public HTTPS Azure endpoint and Apple development-team identifier are not secrets. |
| Force unwraps | Inspected fixed URLs/timezones, validated civil dates, guarded array/dictionary accesses, supported HealthKit type and fixture constants. No current unguarded external-input crash was demonstrated; no blanket rewrites performed. |
| Error swallowing | Store errors propagate to fail-closed UI; derived unavailable data is intentionally withheld; auth/transport errors are sanitized. Cleanup preserves primary errors and reports relevant failures. No sensitive raw error logging added. |
| Main thread / concurrency | Store/session/UI use MainActor intentionally; transport is actor-isolated. Reset exclusion corrected. Dense-history latency is not measured; no speculative background-store migration. |
| Duplicate AI calls / timeout | Consent before dispatch, manual-vs-daily coordination, durable daily reservation, generation checks, cancellation and 75-second transport/coordinator deadlines inspected. Client tests use synthetic services. |
| SwiftData / Core Data | Autosave disabled, explicit saves and rollback, validation before mutations, failed opens preserve store. Active configuration explicitly disables CloudKit. |
| Migrations | V6 remains unchanged, with five lightweight transitions. Constructed migration tests passed with the full unit target; signed installed-version upgrades remain external validation. |
| AI safety | Typed/size/schema checks and reviewed symptom save protect client boundaries. They do not prove factual, allergy or medical safety of deployed generated prose. |
| Accessibility | Selected-detail scope and test interactions corrected without redesign. Physical VoiceOver/contrast/keyboard/Reduced Motion acceptance remains outstanding. |
| Runtime layout warnings | Four “Invalid frame dimension (negative or non-finite).” warnings reproduced in the first cleanup run when opening Describe symptoms and revealing the allergy-name field; the selected AI failure case reproduced its warning in follow-up. Retained action logs contain no source location/stack. Root cause/visible impact remain unverified. No speculative layout rewrite or diagnostic suppression applied. |
| Release/App Store config | iOS 17 floor, iPhone/iPad, version 1.0/build 1, correct icon/launch assets, Apple/Health/complete-protection entitlements, no CloudKit. Signing and App Store metadata are not validated by an unsigned archive. |

## Validation evidence

Artifacts: `/tmp/cecy-final-cleanup-20261003`.

- `baseline.diff`, `baseline-status.txt`, `implemented.diff`, `regression-source-fingerprints.json`: provenance and source state.
- `reset-before.log`, `reset-before.status`: pre-fix reproduction and interrupted harness finalization.
- `regression-command.json`, `regression.log`, `regression.xcresult`, `regression.status`: full unit target plus fifteen earlier UI failures and five reset/AI/wellness regressions; no live provider calls.
- `previous-action-log.json`: retained full-run runtime-warning context.
- `credential-scan.json`, `force-unwrap-inventory.json`: bounded static audit evidence.
- `archive.log`, `archive.status`, `cecy-unsigned.xcarchive`: successful unsigned Release build, followed by `release-artifact-inspection.json` checks.

### Executed results

Environment: Xcode 27.0, iPhone 16e Simulator on iOS 26.2, English/en_US. Fixtures use September 29, 2026; civil-day regression clocks explicitly use UTC. No physical-device operations, real Apple authorization, real Health data, live AI calls or distribution submissions.

| Execution | Results | Scope |
|---|---|---|
| Complete unit target (`regression`) | **271 passed, 0 failed, 1 skipped** | 272 declarations / 52 suites; 7.318 seconds. Reset exclusion/cancellation, migrations, rollback, AI consent/failure/timeout/stale-response and branding included. |
| First cleanup UI run (`regression`) | **12 passed, 8 failed** | Twenty selected scenarios. Combined bundle: 283 passed / 8 failed / 1 skipped; exit 65. Failures retained. |
| Follow-up (`followup`) | **14 passed, 4 failed** | Five focused unit declarations passed; UI nine passed / four failed; exit 65. |
| Final settings (`settings-final`) | **8 passed, 0 failed** | Three settings UI scenarios plus five reset/branding unit declarations; exit 0. |
| Final calendar (`calendar-final`) | **1 passed, 0 failed** | Past-day activity persistence and disabled future logging, using the final compiled helper; exit 0. |
| Unsigned Release archive | **PASS**, exit 0 | Actual bundle `xyz.thabo.cecy`, iOS 17 floor, iPhone/iPad, version 1.0/build 1; AppIcon/LaunchIcon/LaunchScreen and checked fixture/prototype exclusions verified. No embedded provisioning profile or privacy manifest. |

Do not sum repeated tests across runs or count parameterized invocations as additional declarations. The skipped test is `PhaseFivePrivacyTests.completeProtectionCoversExportsStoresAndSidecars`, which requires a physical device.

### Earlier UI failure disposition

All fifteen earlier failures now have passing focused results. IDs refer to `RELEASE_READINESS_VALIDATION.md`:

| Earlier failures | Latest passing run |
|---|---|
| UI-02 compact logging; UI-04 date strip; UI-05 logout/reconnect | `regression` |
| UI-01 ovulation detail; UI-03 flow/goal persistence; UI-06 measurement conversion/clearing; UI-10/11 rated observations; UI-13 activity CRUD; UI-14 prediction/duplicate protection; UI-15 large-text unknown-end detail | `followup` |
| UI-07 reminders/relaunch/reset; UI-08 largest-text settings; UI-09 About/privacy/storage navigation | `settings-final` |
| UI-12 past-day activity and disabled future logging | `calendar-final` |

The five additional selected scenarios also have passing evidence: typed period reset, AI consent/save/revoke, cancellation/background, failure/manual fallback, and wellness save/relaunch/clear. Runtime warnings still occurred in passing AI/wellness scenarios. `latest-ui-outcomes.json` records all twenty latest results with originating runs and durations; this is **not** a merged full-suite pass.

Follow-up corrections address observed automation issues: controls behind the onboarding footer, offscreen lazy fields whose UIKit type was guessed too early, keyboard accessory bars consuming scroll gestures, insufficient backward searches, corrective drags below native pan thresholds, and UIKit combining saved reminder labels as “Daily check-in, On/Off.” Exact state, persistence, cancellation and reset checks remain.

**No fresh complete 71-test UI suite was run after cleanup.** Earlier complete-suite results remain historical. Targeted passes across separate runs do not establish a single green complete candidate suite or physical accessibility acceptance.

Command JSON, logs, result bundles, status files and summaries/test trees are retained for `regression`, `followup`, `settings-final` and `calendar-final`. Source fingerprints distinguish intermediate helper versions from the final version. `release-artifact-inspection.json` records actual archived product checks. `final-source-fingerprints.json` was verified against final Swift files; `git diff --check` passes. Branding, entitlements, storage models/migrations, deterministic domain logic and unrelated user edits were preserved. Preserve artifacts outside temporary storage before release; do not publish diagnostic data indiscriminately.

## Remaining release gates

- A final complete candidate UI run and resolution/owner disposition of reproduced invalid-frame warnings. The previous fifteen failures now have focused passes, not a final complete-suite pass.
- Approved publicly accessible privacy/support URLs and an in-app privacy-policy route; no URL or retention promise invented.
- Authoritative Azure/OpenAI retention/logging/deletion/rate/abuse controls and authorized synthetic live contract/safety evidence.
- Native Apple sign-in and applicable token-revocation/account-deletion decision, without embedding a secret or inventing a backend.
- Physical complete file protection, locked-device/app-switcher behavior, offline/native Health/notifications/Mail, signed upgrades/timezone changes, VoiceOver/contrast/keyboard/Reduced Motion, supported OS/iPad matrix and dense-history performance.
- Signed distribution validation and owner-approved App Store metadata/privacy answers/screenshots/reviewer access.

**Engineering readiness: not approved.** Final cleanup can close concrete code defects, not supply missing external or physical-device evidence.