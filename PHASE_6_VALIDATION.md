# Phase 6 — Validation record

September 30, 2026 · `phase-6`

## Status

Read-only Apple Health review/import is implemented. **Not a release sign-off.** Real HealthKit authorization, signed-device behavior and earlier privacy gates remain open. No cloud/AI/subscription work is included.

## Automated evidence

- Debug app and both test targets compiled for iOS Simulator with Xcode 27.
- Initial unfiltered unit run: 112 tests, three failing test functions (11 failed assertions). All 11 initial Phase 6 tests passed.
- Focused rerun: all three Phase 6 UI tests passed on iPhone 17 Pro / iOS 26.2 with synthetic injected Health samples. Covers confirmation, persistence/repeat review, stop/discard, unavailable/empty access, and return to local tracking.
- Latest full unit run: **113 of 114 tests passed**, including **all 13 Phase 6 domain/repository/state tests**, after the date-line travel correction. Four failed assertions belong to the existing `protectedExportsExcludeBackupsAndCleanupIsScoped` simulator protection-attribute check. Assertions remain unchanged; no tests excluded from that run.
- Full UI regression run: **19 of 30 passed**, including all three Phase 6 flows. Eleven earlier-feature tests failed; they remain unresolved acceptance gates.
- Release simulator build: **passed**.
- Later acceptance rerun: two of three Phase 6 UI tests passed; import/relaunch failed locating Settings after relaunch. The helper now handles restored navigation/scroll position. The recovery run passed **all three Phase 6 UI tests** (80.6 seconds; `/tmp/cecy-phase6-ui-recovery.xcresult`). Earlier instability remains recorded; this focused pass does not clear the full-suite failures.

### Unresolved UI regression gates

- Onboarding: Apple cancellation, largest-text cycle choices, logout/reconnect, profile persistence/editing.
- Settings: reminder persistence/reset and summary/detail navigation.
- Symptoms: Calendar ratings/reset and Today duplicate/edit/cancel/delete/relaunch.
- Period management: reset back to durable onboarding.
- Core onboarding: complete/log/relaunch and draft-not-committed-before-sign-in.

The onboarding helper now dismisses the name keyboard and uses bounded directional drags instead of overshooting horizontal choices. Two targeted reruns passed earlier failure points but failed later at common-symptom lookup and selected-state verification. Those flows are **not verified**. Do not assume all failures are test-only: investigate app behavior and test assumptions before release.

### Baseline fixes found by the unfiltered run

- The activity lock test used the preview authentication fake's deliberate failure default. It now explicitly injects successful authentication and asserts the lock setting before verifying denied writes. Production authentication did not change.
- `head.profile` was missing on the tested OS. It is replaced with `brain.head.profile`; symptom-symbol tests now name any missing symbol. The final unit run passed those checks.
- The stray `phase` token in `SexualActivity.swift` was removed to restore compilation.

### Phase 6 coverage

- Source time-zone conversion, missing/invalid-zone fallback, DST, leap day and date-line travel. Past timestamps may have source-zone dates ahead of local today; explicit correction is allowed, but future confirmed dates remain invalid.
- User-confirmed start only: no inferred end, notes or whole-period flow from daily/multi-day samples.
- Unknown/no-flow/future records and manual-date conflicts.
- Export includes accepted period dates but excludes source identifiers/metadata.
- Atomic period-and-receipt rollback/retry and reset rollback.
- UUID idempotency, source edits, local correction/deletion with receipt retention.
- File-backed V5 → V6 migration preserving periods, symptoms, profile, onboarding and activity; reopen preserves receipts.
- No implicit authorization, empty is not denial, unavailable/failing reader isolation.
- Same-day different sources remain distinct; duplicate UUIDs do not duplicate review rows.
- Late read responses are rejected after cancellation/access loss.
- Session requires review, recalculates after acceptance and clears review/receipts on reset.

## Result locations (local only)

- `/tmp/cecy-phase6-build.log`
- `/tmp/cecy-phase6-unit.xcresult` and `.log`
- `/tmp/cecy-phase6-focused.xcresult` and `.log`
- `/tmp/cecy-phase6-unit-final.xcresult` and `.log`
- Full regression output: `/tmp/cecy-phase6-ui-final.xcresult` and `.log`
- Release output: `/tmp/cecy-phase6-release.log`

Test stores and samples are synthetic and isolated from production. Headless simulator runs do not open the Simulator app. Test fakes never request real Health permissions.

Additional results: `/tmp/cecy-phase6-acceptance.xcresult`, `/tmp/cecy-phase6-onboarding-rerun.xcresult`, `/tmp/cecy-phase6-ui-recovery.xcresult` and their matching `.log` files.

The unit-final and full-UI diagnostic collectors were stopped after assertions finished to avoid lengthy simulator stalls. Failing assertions/logs were retained. Later runs disable verbose diagnostic collection, not tests.

## Signed-device acceptance — not yet performed

Use synthetic Health samples and a signed build with the HealthKit capability enabled for the App ID/provisioning profile. No write or background-delivery capability is needed.

- [ ] Brand-new installation/onboarding and existing local records work without any Health request.
- [ ] Settings → Apple Health → Review requests only menstrual-flow read access; cancellation and denial preserve local functionality.
- [ ] Review real readable flow samples with/without cycle-start/time-zone metadata, across DST/travel and multiple source apps.
- [ ] Inspect multi-day/overlapping samples; confirm a start and verify no end/whole-period flow is inferred. Conflicts cannot overwrite existing history.
- [ ] Relaunch and repeat review: accepted UUIDs remain reviewed. Local edits persist; deleted periods do not reappear. Source changes/deletions cannot remove or overwrite local history.
- [ ] Stop, tab switch, background, device lock, app lock and logout discard pending review; late callbacks cannot save anything.
- [ ] Revoke Health read access in system settings and retry. Empty reads do not falsely claim denial or absence of records.
- [ ] Reset removes local imports/receipts but leaves Apple Health unchanged; export disclosures match exported data.
- [ ] iOS 17-compatible signed-device behavior, unavailable-device fallback, VoiceOver, Dynamic Type, smaller phones, dark mode and iPad.
- [ ] Finish Phase 5 Data Protection, backups, biometric/passcode, app-switcher and reminder-delivery checks and onboarding Apple-identity device gates.

No future-probability claims, write-back, automatic synchronization or changes to the prediction algorithm were introduced.

- [ ] Publish/review the required HealthKit privacy policy and App Store disclosures before distribution. In-app explanations do not replace the policy.

## Apple reference checks

- [Authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data): read denial is not directly exposed; historical access may be limited. Empty results never prove absence of records.
- [Query descriptors](https://developer.apple.com/documentation/healthkit/hksamplequerydescriptor): one-shot async queries available before the iOS 17 minimum.
- [Privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy): clear health purpose, no advertising use, required privacy policy.
