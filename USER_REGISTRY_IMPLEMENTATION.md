# iOS user registry implementation

Date: 2026-10-05. Branch: `feature/apple-user-registry`, based on `8fc3607`.
Source contract: `CecyAI/IOS_USER_REGISTRY_HANDOFF.md` (252-line handoff).

## Scope

Implemented registry activation/deactivation through the existing Azure Function host. No health-schema changes, migrations, sync, backend implementation, analytics dashboard, or disclosure-text changes. Registry availability never determines local account access. Logout does not deactivate a user.

### Integration

- `AppleAccount.link` signals success only after secure identity storage succeeds. Cancelled, rejected, stale, or failed authentication does not signal success. Credential checks and app opens are not new sign-ins.
- `TrackerSession` queues activation only after the matching local profile and completed onboarding are available. Initial setup waits for its final local commit; returning sign-in uses the persisted preferred name. Blank names or email-like names use `Cecy User`.
- Registry IDs are deterministic lowercase SHA-256 of the Apple subject identifier. The raw identifier remains in existing local identity storage and is not sent to the registry.
- `RemoteUserRegistryService` uses Foundation URLSession, following the existing AI client's privacy policy: ephemeral configuration, no cookies/cache/credentials, no redirects, bounded responses, 15-second request and 20-second resource timeouts. No API key or bearer token is added.
- PUT body is exactly `displayName`; PATCH body is exactly `status: inactive`. Activation accepts 200/201; deactivation accepts 200/404. Successful JSON replies must confirm success, the requested ID and status. Response bodies and identifiers are not logged.

### Durable queue and deletion

`KeychainRegistryOperationStore` uses a separate, non-synchronizing, WhenUnlockedThisDeviceOnly item. Existing Apple identity and SwiftData formats remain unchanged.

1. Save a hashed-ID-only `deleting` intent before changing local data. This replaces pending activation for that ID and strips the name. A failed journal write prevents destructive cleanup.
2. Complete existing notification/privacy cleanup, delete local records, then remove the local identity. Keeping the identity until the record transaction commits fixes the previous risk of losing it on a failed deletion.
3. Promote the intent to `deactivate` only after local cleanup succeeds. Failed/partial deletion never sends PATCH.
4. Remove the queued operation after confirmed success, including a deletion 404. Network failure never restores deleted records.
5. If the process stops after local deletion but before journal promotion, the next successful load promotes the intent only when the store is empty and identity is verified absent. It does not automatically delete any records on startup.

The queue serializes requests. Revisions prevent stale responses from clearing newer operations, and a new successful sign-in supersedes pending deactivation for the same ID. Other users' pending deactivations are preserved.

Network errors, 408/429, 5xx and invalid responses retain state and retry with exponential delays starting at 5 seconds, capped at 300 seconds, while active/unlocked. Other HTTP errors retain a blocked operation and emit only a generic diagnostic rather than retrying continuously. Foreground/unlock resumes eligible work; background/lock pauses new requests. An already-started request may finish within its timeout. No background execution entitlement is added.

A failed activation journal write is reported through generic diagnostics and retried while the successful authorization remains in memory; no client can promise persistence if secure storage itself is unavailable. A later successful sign-in also retries activation.

## Verification

- Final full unit target: **passed**, Swift Testing reports 301 tests in 57 suites. The existing physical-device file-protection test is explicitly skipped on Simulator.
- Four existing UI regressions: **passed**:
  - `PhaseTwoUITests/testResetCancelThenConfirmReturnsToDurableOnboarding`
  - `TodayDetailsAndWelcomeUITests/testWelcomeRetainsProfileSignInAndDeletionSafeguards`
  - `cecyUITests/testCompleteOnboardingLogAndRelaunch`
  - `cecyUITests/testOnboardingDraftDoesNotCommitBeforeAppleSignIn`
- New service tests cover methods, paths, exact body keys, absent credentials/raw ID, hash determinism, name fallback, 200/201/404, transient/permanent errors, cancellation, invalid responses and response-size limits.
- New lifecycle tests cover serialized retry state across coordinator recreation, both directions of in-flight activation/deactivation races, separate accounts, failed final setup commit, successful repeat sign-in, cancelled/failed/stale authorization, partial signed-in/signed-out reset, failed health-store commit, failed queue persistence and crash recovery.
- Tests use synthetic HTTP stubs, memory/encoded retry state and isolated local stores; they never call the production registry. Native Keychain persistence and real Apple authorization still need signed-device acceptance.
- Editor diagnostics: none in edited Swift files. Diff whitespace checks pass.
- Intermediate compile failures (actor-isolated default construction and a missing test import) were corrected before the passing run. Existing unrelated test warnings remain; no broad cleanup was performed.

Local artifacts:
- `/tmp/cecy-registry-tests-v3.xcresult`: full unit target plus four UI regressions.
- `/tmp/cecy-registry-final-units.xcresult`: final full unit target including two additional failure/race tests.
- `/tmp/cecy-registry-release.log` and `/tmp/cecy-registry-release.xcarchive`: unsigned Release archive **passed**, with only the existing AppIntents metadata-extraction warning (no AppIntents dependency).

## Remaining release risks — not waived by implementation

- The endpoint is anonymous. Knowing an ID allows unauthorized record mutation; client-side hashing does not provide server authorization. No live deployment validation was performed.
- A stable hash is pseudonymous, not anonymous; the requested display name can be personal information. Per explicit instruction, app disclosures were left unchanged. This does not establish privacy/disclosure compliance.
- Marking inactive retains the server row/name according to the handoff. This is not server-side erasure.
- The existing app has no Apple token-exchange/revocation implementation, and the handoff supplies no such endpoint. Removing the local identity and patching registry status do not revoke Apple authorization. That prerequisite remains unresolved for public release.
- Serialization/revisions protect local queue ordering, but the anonymous API has no version/conditional-write contract. A timed-out request might still finish on the server later, and another device/caller can change the same row. Full server ordering guarantees need backend support.
- Retry depends on the app running again with accessible device storage and networking. App uninstall, permanent abandonment, or unrecoverable Keychain failure cannot guarantee delivery. Corrupt/unavailable retry state is not silently overwritten.

No public-release sign-off, production API writes, commits, or pushes are implied by these results.
