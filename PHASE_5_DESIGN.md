# Cecy — Phase 5 privacy, export and reminders

September 30, 2026 · phase-5 · Implemented; verification incomplete. All 15 UI flows and Release build passed; 64 of 65 unit tests passed. Protection-attribute readback on Simulator remains unresolved. See [PHASE_5_VALIDATION.md](PHASE_5_VALIDATION.md).

## Boundaries
Native LocalAuthentication, UserNotifications, Foundation and UIKit integrations behind injectable services. No networking, analytics, cloud, HealthKit, purchases, or health-schema migration. Core tracking remains offline and permission-free.

## Storage and preferences
- Apply NSFileProtectionComplete to the private store directory, existing files and SQLite sidecars before opening and after creating the container. Set the default Data Protection entitlement for newly created files. Never replace an inaccessible store with an empty one.
- A separate versioned, atomically written protected preferences file holds only app-lock choice and reminder choices/time. Missing file means defaults; corrupt/unreadable preferences fail closed before displaying records. No secrets requiring custom cryptography.
- Persistent records and preferences remain eligible for system backups. Temporary exports are excluded. Explain backups are controlled by iOS/user settings and local deletion does not remove external copies, backups or guarantee overwriting SQLite pages.

## Lock lifecycle and UX
- Off by default. Enable and disable require fresh device-owner authentication: Face ID/Touch ID with system device-passcode fallback. No app-specific PIN, custom password, account recovery or bypass on failed authentication.
- Cold launch with lock enabled gates store loading. Unlock is an explicit button, not an automatic prompt loop. Cancel/unavailable/lockout leave content locked and show neutral retry guidance. No error logs containing records.
- Backgrounding relocks and invalidates in-flight authentication; a generation check prevents stale completions unlocking later. System authentication can cause inactivity, so inactivity hides content but does not invalidate authentication until actual backgrounding.
- A UIKit privacy cover at the window level shields sheets as well as the underlying SwiftUI content before app-switcher snapshots. It is generic and contains no health information. The lock gate removes the tracking hierarchy while locked; unsaved drafts can be lost on relock (disclose this in Settings).
- Lock remains enabled after delete-all-data as a security preference; reminder preferences reset. Disabling lock remains a separately authenticated action. No claim of protection against a compromised OS or someone who knows the device passcode.

## JSON export
- Export version 1, generated UTC timestamp, stable IDs/types, civil dates (YYYY-MM-DD), timestamps, flow, symptom ratings. No predictions or derived insights masquerading as raw records.
- Private notes excluded by default; explicit Include private notes toggle. Export all raw records, including dates needing correction, without silently filtering. Validate structural integrity first.
- Explain JSON is readable health data, not an encrypted archive or an import/restore feature. Sharing/saving creates copies outside Cecy's control.
- Protected, backup-excluded private temporary directory, generic filename, one export at a time. Cleanup on share completion/cancel, relock and next startup (including crash leftovers); cleanup failures are visible and retried. Leaving the app during sharing may cancel the export.

## Local reminders
- One daily logging reminder plus at most one next-window reminder (day before earliest estimated start), both optional, default time 20:00 local. No exact-date clinical claims; no symptom/flow/notes/predicted dates in notification payloads. Generic title Cecy and body. No remote notifications or advertising identifiers.
- Request permission only following a user enabling a reminder. Denial keeps it off with Settings guidance. On foreground refresh, recheck authorization, remove obsolete requests and show status for revocation/disabled alerts. No permission prompts at launch or onboarding.
- Window reminder only if an estimate and a future fire time exist. Never synthesize another window or schedule catch-up alerts. Foundation calendar resolves DST; daily reminders follow system local-time behavior. Reschedule on records/preferences/date/time-zone changes while app runs. No background refresh requirement; edits made outside a running app cannot be observed.
- Serialize notification replacement. Coalesce revisions while OS operations await; a final clear/flush after reset prevents an in-flight obsolete add surviving reset. Keep identifiers namespaced and remove only owned requests/delivered notifications. Scheduling failure clears partial schedules and reports failure, not saved-success messaging.
- Notification delivery can be delayed/suppressed by Focus, device settings or the OS. Locking does not disable already authorized discreet reminders.

## Reset/failure ordering
Disable reminder preferences and clean temporary exports before deleting records. If ancillary cleanup fails, preserve tracker records and report that reminders may already be disabled. Repository reset remains one store transaction; legacy cleanup is independently irreversible as before. UI waits for notification reconciliation before leaving reset. Do not claim external copies or backups were erased.

## Verification plan
- Unit tests: export fields/note consent/date semantics, protection and cleanup, preference corruption, lock cancellation/stale replies/fallback/enable-disable persistence, reminder scheduling date boundaries/denial/revocation/failed replacement/coalescing/reset race, session recomputation/reset.
- Isolated UI tests: privacy settings navigation, permission-free onboarding, lock/relaunch/cancel, export warning/options, reminder choices/reset, prior flows. Test factories never use production preferences, exports or notifications.
- Headless Debug and Release checks. iOS 17 runtime, signed device protection/locked-file access, backup contents, actual biometric/passcode flows, app-switcher snapshots over system sheets, DST delivery, VoiceOver and iPad layouts remain manual release gates.
