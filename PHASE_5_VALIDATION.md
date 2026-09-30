# Phase 5 — Verification and release gates

September 30, 2026 · `phase-5`

## Implemented scope
- Versioned local privacy preferences; unreadable/corrupt settings fail closed, rather than disabling the lock.
- Optional device-owner authentication (Face ID/Touch ID with device passcode fallback). Generation checks reject stale replies after backgrounding; store loading and mutations are gated while locked.
- App-switcher cover above app-owned sheets, synchronized with UIKit notifications and SwiftUI scene activity. The cover is not a claim of screen-capture prevention.
- Versioned JSON export with civil dates, identifiers, metadata, flow and symptom ratings. Private notes require explicit selection. Exports are readable, not encrypted archives or an import feature.
- Complete Data Protection requested for the store directory and sidecars, preference and export writes, plus default file protection entitlement. Temporary export directory is excluded from backups; cleanup is scoped to app-owned exports.
- Opt-in daily and next-window local reminders. No health details in notification text. Scheduling is serialized/coalesced; reset waits for reconciliation and keeps the app-lock preference.
- No health schema migration, network service, third-party package, HealthKit, cloud, AI or monetization changes.

## Current automated results
- Debug app and test targets compile.
- The complete unit run executed **65 tests across ten suites: 64 passed and one failed**, with four assertions in `protectedExportsExcludeBackupsAndCleanupIsScoped`.
- Passing privacy tests cover note consent and export fields, civil dates/DST/travel, opt-in behavior, corrupt preferences, locked startup, cancellation/stale authentication, preference write failures, export cleanup failure preserving records, denied/revoked permissions, failed scheduling/retry, coalescing and reset during an in-flight add.
- The failing test completes its export, backup-exclusion and scoped-cleanup checks, but cannot read the expected complete-protection attribute on the simulator. Both attempted casts produced no usable value. This is not proof that a signed device is protected, and the full unit suite is **not green**.
- Approval was requested to separate device-only protection readback from simulator-safe filesystem tests. The failing assertions remain intact; they were not silently removed or weakened.
- Initial UI runs exposed navigation/scroll targeting and native share-sheet synchronization failures. The privacy cover now also follows SwiftUI scene activity, and tests wait for share-sheet interactivity and dismissal.
- The final complete rerun passed **all 15 UI flows with zero failures**, including all 12 earlier regressions and three new export, lock/relaunch/cancellation/background, and reminders/reset flows.
- **Release generic iOS Simulator build passed** for arm64/x86_64 with iOS 17 deployment target. This is not a signed-device or iOS 17 runtime result.
- The editor diagnostic helper reports a standalone `No such module XCTest` for the new UI test file, while Xcode’s actual test target compiles and all tests execute successfully. No test framework dependency was added or import removed to mask that discrepancy.

Evidence (temporary, not committed): `/tmp/cecy-phase5-build.log`, `/tmp/cecy-phase5-unit-checked.xcresult` (one failing unit test), `/tmp/cecy-phase5-ui-final.xcresult` (15 UI passes), `/tmp/cecy-phase5-ui.xcresult` and `/tmp/cecy-phase5-ui-focused.xcresult` (initial failure history), `/tmp/cecy-phase5-release-final.log` (Release success). No commit or push performed. Tests used isolated synthetic records and injected authentication/notification services, not production data or real biometric authorization.

## Required signed-device checks
Keep these open until actually performed on a passcode-protected iPhone/iPad:

- [ ] Verify the signed app carries `com.apple.developer.default-data-protection = NSFileProtectionComplete`.
- [ ] Inspect protection attributes on the actual SwiftData store, WAL/SHM, preferences and exported file, including sidecars recreated after reopening/writing.
- [ ] Lock the device after an initial unlock and verify protected files cannot be read; verify unlocking restores access without data reset or silent replacement.
- [ ] Test Face ID, Touch ID where available, device-passcode fallback, cancellation, lockout, changed enrollment, missing passcode, repeated backgrounding and relaunch.
- [ ] Verify app-switcher snapshots show only the generic cover over Today, Calendar, notes/editing forms, reset and export sheets. Check Control Center, permission prompts, rotation, iPad layouts and multiple-scene behavior; do not assume simulator accessibility tests prove visual shielding.
- [ ] Verify the lock's disclosed unsaved-draft behavior and that failed authentication never reveals sensitive views.
- [ ] Inspect backup behavior: records/preferences may be backed up, temporary exports are excluded. Do not promise that local deletion erases previous backups or shared copies.
- [ ] Test actual notification authorization/denial/revocation, Focus suppression, DST/time-zone changes, passed windows and record edits. Confirm payloads are discreet and reset clears owned pending/delivered notifications without altering unrelated requests.
- [ ] Test saving/sharing JSON to trusted destinations, cancellation/background interruption, next-launch cleanup after forced termination and cleanup failure recovery. Verify exported copies remain outside Cecy's deletion control.
- [ ] Verify iOS 17 runtime compatibility, airplane-mode operation, VoiceOver, Dynamic Type, contrast, dark mode and iPad/split-view layouts.

## Deferred within Phase 5
A human-readable/PDF report was considered and deferred: the initial portable JSON export is the foundation. There is no import/restore UI, custom PIN, custom cryptography, background prediction refresh or remote notification service.
