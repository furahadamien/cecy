# Cecy — Phase 0 Foundations

Date: September 29, 2026

Status: Foundation decisions established. Tracking implementation remains Phase 1 work.

Companion: [Implementation plan](IMPLEMENTATION_PLAN.md)

## 1. Scope and current-state audit

Phase 0 establishes the implementation baseline, not a functioning tracker. The existing four-tab canvas remains a labeled visual fixture and must not be mistaken for real predictions or saved records.

Repository findings:

- The app root launches `ContentView` without initializing a persistence container.
- `Persistence.swift` is disconnected template code using `NSPersistentCloudKitContainer`, with template fatal-error handling.
- The Core Data model contains only an `Item` with an optional timestamp. It does not represent periods or symptoms.
- No real health-data schema, migration code, or persisted health records were identified in the repository. This is not proof that older installed builds have no local stores. Device app containers were not inspected.
- The initial project targeted iOS, macOS, and visionOS 27.0. Xcode 27.0 is installed and successfully builds the canvas; the deployment-version change below is a product-support decision, not a correction of an invalid SDK.
- The entitlement file contained iCloud and push keys, but no explicit `CODE_SIGN_ENTITLEMENTS` assignment was found. These declarations do not prove an active or provisioned cloud integration.
- `Info.plist` declared the remote-notification background mode. There are no current features requiring it.
- Swift source membership is discovered through Xcode file-system-synchronized groups. Future source files under the app/test folders do not need individual PBX file references.
- Unit tests use Swift Testing and contain an empty placeholder. UI tests use XCTest and contain template launch/performance coverage. There is no domain or feature coverage yet.
- There are no external package dependencies.

## 2. Platform decision

**Baseline: iOS/iPadOS 17.0 and later, iPhone-first with an adaptive iPad layout.**

Rationale:

- SwiftData is available from iOS 17.
- The existing SwiftUI canvas compiles against this minimum.
- There is no current requirement for an iOS 27-only API.
- Keep one iOS app target rather than adding platform-specific architecture prematurely.

Applied in Phase 0:

- Align Debug and Release deployment targets for the app, unit tests, and UI tests to 17.0.
- Limit supported platforms to `iphoneos` and `iphonesimulator`, and device families to iPhone/iPad.
- Disable Mac Catalyst, Designed for iPad on Mac, and Designed for iPad on Apple Vision Pro support.
- Retain the bundle identifiers, development team, Swift language/concurrency settings, and current Xcode project format.
- Remove unused cloud/push declarations and the remote-notification background mode. Do not add permissions or services.

Installed simulator runtimes are iOS 26.2 and 27.0. Compiling with a deployment target of 17.0 checks API availability; it does not establish runtime compatibility on iOS 17. A supported minimum-version device/runtime test remains a release gate. Do not claim older Xcode project-format compatibility merely because the deployment minimum is lower.

## 3. Persistence and transition decision

**Use local SwiftData storage behind a repository in Phase 1. Do not initialize it in Phase 0.**

### First persisted observation

The first period record will contain only:

- A stable UUID.
- A required start calendar day.
- An optional end calendar day.
- Created and updated timestamps, stored as absolute `Date` instants.

Add flow, notes, symptoms, and preferences when their features require them. Do not create placeholder entities for future services. Do not persist cycles, current cycle day, statistics, predictions, or insights initially.

### Non-destructive transition

1. Create an explicitly named SwiftData store at a separate Application Support location, distinct from any template Core Data store; proposed location: `Cecy/CecyPeriodsV1.store`.
2. Configure its CloudKit database explicitly as `.none`; do not rely solely on removed capabilities or default configuration.
3. Introduce a versioned V1 schema before real period records are saved. Future schema changes require an explicit migration review and migration tests.
4. Never reinterpret template `Item.timestamp` values as menstrual observations. They were generic sample timestamps and cannot be reliably converted.
5. Do not delete, overwrite, open for migration, or reset any older template store automatically. Leave any such on-device files untouched.
6. Remove the obsolete persistence source/model from the active app build during Phase 1 after confirming there are no remaining references. Removing source files is not authorization to delete users' store files.
7. If actual prior health records or distributed builds are discovered later, stop the transition and design a preservation/import path before changing stores.

No template-data migration is planned because the template has no menstrual semantics. Preservation is achieved by not touching the old store, rather than by assuming it is empty.

### Repository and failure behavior

- Domain calculations consume plain Swift values, not managed persistence objects.
- Start with a main-actor SwiftData repository appropriate for the small dataset. Do not add background actors or additional targets without need.
- Keep calculation services independent of the view and repository; explicitly handle the target's default MainActor isolation when implementing pure domain types.
- Inject the repository, clock/as-of day, and calendar/time-zone conversion at appropriate boundaries for testing.
- Validate before writes, explicitly save, and surface failure without presenting an unsaved record as confirmed.
- Preserve entered values for retry. Do not dismiss onboarding or mark it complete after a failed save.
- Store-load failures must offer a recoverable error/retry path. Never silently replace a broken persistent store with an empty or in-memory one.
- Never log health values or use `fatalError` for expected persistence failures.
- In-memory storage is for tests and explicitly labeled previews only; never seed production storage with canvas fixtures.
- Local storage may participate in system device backups. Do not promise that data can never leave the device through backups; protection and backup behavior require verification before release.

## 4. Calendar-day semantics

**Observations are civil calendar days, not timestamps or elapsed 24-hour durations.**

### Representation

- The domain will use a validated date-only value with Gregorian year, month, and day components.
- Persist that value as an integer day key `YYYYMMDD` (year × 10000 + month × 100 + day). An optional end key is either entirely absent or a valid day.
- Validate real dates; numeric ordering alone does not validate February 30.
- Do not subtract integer day keys to calculate durations.
- Use a fixed Gregorian calendar with UTC for calendar arithmetic on these values. UTC is an internal arithmetic convention, not the user's observation time zone.
- At date-picker/input boundaries, extract the selected Gregorian calendar day using the UI's explicit time-zone context. Convert back consistently for display; never show an internal UTC anchor as a local timestamp.
- Localize date wording and week layout without changing the stored civil day. Initial calculations use the Gregorian calendar explicitly, not `Calendar.current` implicitly.

### Today, travel, and clock changes

- Determine today from an injected clock and the device's current time zone, with Gregorian day components.
- Recompute on foregrounding, local day changes, and significant time-zone/clock changes.
- Traveling never rewrites a saved observation day. A record labeled September 2 remains September 2.
- Current cycle day follows local today, so crossing the date line may move it forward or back by one. Do not rewrite history to hide that effect.
- If the latest saved start appears later than today after a clock/time-zone change, show a date-check/unavailable state rather than a negative cycle day. Do not delete it automatically.
- Use Gregorian calendar addition/difference rather than dividing seconds by 86,400. DST must not change a day count.

### Definitions

- Cycle length: number of calendar days between two consecutive recorded starts. Four starts yield three completed start-to-start intervals, even if bleeding end dates are unknown.
- Current cycle day: days from the latest start to today, plus one. A recorded start today is day 1.
- Period duration: days from start through end, inclusive. Same-day start/end means one day.
- A missing end means duration unknown, not zero days, not a typical five-day period, and not proof of ongoing bleeding.
- Calendar marks only the start day when the end is unknown. When both endpoints are confirmed, it marks the inclusive recorded span.
- Period phase, ovulation, and fertile-window estimation are not part of Phase 1.

## 5. Validation and correction rules

Apply these rules both in feature validation and at the write/use-case boundary. User-facing errors should explain how to correct the entry.

| Situation | Rule |
| --- | --- |
| Invalid calendar day | Reject; never normalize an impossible date into a different month. |
| Start or end later than local today at save time | Reject new/edited observations. Predictions are separate derived values and may be future dates. |
| End earlier than start | Reject. |
| End equal to start | Allow; duration is one day. |
| Duplicate start day | Reject the new record and direct the user to the existing one. Repeated taps must not create duplicates. |
| Duplicate dates within onboarding draft | Identify the conflicting rows before any save. Do not silently merge. |
| Confirmed bleeding spans overlap | Reject until corrected, including a new start on an existing confirmed end day. |
| Start-only records | Treat the confirmed interval as the single start day for overlap validation; do not infer indefinite bleeding. |
| Adjacent non-overlapping periods | Allow. Do not automatically merge records or label them abnormal. |
| Very short/long interval | Retain as entered if structurally valid; do not apply an undocumented clinical validity cutoff. Prediction may be withheld under the policy below. |
| Unsorted history | Sort for calculations. Preserve record identifiers and entered values. |
| Historical edit | Validate against all other records excluding itself, preserve ID/created timestamp, update updated timestamp, then recompute all affected intervals and estimates. |
| Deleted record | Recompute neighboring intervals; never leave stale prediction/statistics caches. Full persisted-record editing/deletion UI follows in Phase 2. |
| Corrupt/invalid repository input | Surface a data issue and withhold affected calculations; do not silently repair or overwrite it. |

An onboarding batch is validated before saving. On save failure, retain the draft and leave onboarding incomplete. Sample data is never automatically inserted into a real user's history.

## 6. Initial prediction contract

**This is an uncalibrated engineering baseline for Phase 1, not a clinically validated model or probability interval.** Phase 4 must evaluate error and interval coverage before stronger accuracy/confidence claims are made.

### Inputs and deterministic policy: baseline V1

1. Validate records and order the recorded starts.
2. Derive all completed consecutive start-to-start lengths. The ongoing interval is not a completed cycle.
3. For the prediction only, use at most the six most recent completed lengths; preserve the full history for display and future analysis.
4. Require at least three completed lengths (four recorded starts). With fewer, show available history/current day but no period window or confidence label.
5. If the selected maximum minus minimum exceeds 14 days, withhold a window and explain that the recorded intervals vary too widely for this simple estimate. The 14-day threshold is a provisional product heuristic, not a medical cutoff.
6. Otherwise, use the median length for the central estimate, rounding a half-day upward to a whole calendar day.
7. Earliest offset = `max(1, minimum selected length − 2)` calendar days from the latest start.
8. Latest offset = `maximum selected length + 2` calendar days from the latest start.
9. Central date = latest start plus the rounded median offset. All endpoints are calendar dates and the display interval is inclusive.
10. Confidence is **Low** with three to five lengths. With six lengths it is **Moderate** only if their spread is at most seven days, otherwise **Low**. Do not emit High confidence in baseline V1.

The two-day padding, history count, and spread thresholds are explicit replaceable choices. They do not establish coverage percentages or physiological normality. Even a Moderate label must be explained as a rough assessment based on count and consistency, not a measured probability.

### Missing, unusual, and elapsed history

- Do not remove outliers, add synthetic starts, infer missed periods, or quietly truncate a recorded gap.
- Explain that a large interval may include an unrecorded period; allow correction without assuming that this is what happened.
- Never display a population-default 28-day prediction when personal history is insufficient.
- If today is later than the latest predicted date, retain the original window as a passed estimate. Say that the estimated window has passed and invite record review; do not silently roll the estimate forward or declare a medical condition.
- If the date input is invalid or inconsistent with today, show an unavailable state rather than a plausible-looking result.
- Store none of these calculated values initially. Return a structured result with availability reason, range, center, confidence, source lengths, and explanation inputs.
- Keep the policy behind a small replaceable domain interface. The UI formats the result; it never implements the arithmetic.
- Copy should prefer “Estimated next-period window” and “Based on your recorded starts.” Do not claim contraceptive reliability or infer pregnancy.

### Worked fixture

As-of date: September 29, 2026. Recorded starts: June 7, July 5, August 4, September 2, 2026.

- Completed lengths: 28, 30, 29 days.
- Current cycle day: 28.
- Median/center offset: 29 days → October 1.
- Earliest offset: 26 days → September 28.
- Latest offset: 32 days → October 4.
- Confidence: Low (three completed intervals).
- If the latest period ends September 6, its duration is five days.

The existing canvas's dates and Moderate label are illustrative fixtures, not this policy's output. Replace them with real domain results in Phase 1 rather than adjusting calculations to match the mockup.

## 7. Visual and accessibility baseline

Keep the current canvas as a visual reference, not a production feature architecture.

| Token | Light RGB | Dark RGB |
| --- | --- | --- |
| Background | 0.97, 0.96, 0.93 | 0.09, 0.11, 0.10 |
| Surface | 1.00, 0.99, 0.97 | 0.14, 0.17, 0.15 |
| Accent | 0.25, 0.38, 0.29 | 0.69, 0.82, 0.71 |
| Sage highlight | 0.87, 0.91, 0.84 | 0.19, 0.27, 0.22 |

- Use semantic primary/secondary foreground styles, native text styles, semibold section headings, and the rounded cycle-day treatment.
- Layout baseline: 24-point page/card padding, 24-point card corners, 8/12/16/24-point spacing, and a 640-point readable content width where space allows.
- Record indicators: filled drop plus textual/accessibility description. Predictions: dashed outline plus explicit estimated label. Selection must remain distinguishable from either state.
- Keep Today focused on current day, expected range, quick logging, and at most a few useful observations.
- Four main destinations: Today, Calendar, Insights, Settings. Logging is a sheet/action, not another tab.
- Use native controls, visible labels, VoiceOver ordering, and at least 44-by-44-point interactive targets.
- The current dense calendar requires further small-screen/large-text review; its nominal row height does not prove compliant target width. Adapt card padding or offer an accessible day list where needed.
- Allow content to grow or stack for Dynamic Type; never shrink important text to fit.
- Verify contrast in both appearances, including secondary text. Target WCAG AA (4.5:1 for ordinary text, 3:1 for large text and essential non-text indicators).
- Respect Reduce Motion. Avoid animation required to understand state.
- These are design requirements, not claims that a complete accessibility audit has passed.

## 8. Phase 1 acceptance specification

**All cases below are planned tests, not executed feature tests.** Use injected dates and deterministic fixtures; never depend on the real current day in unit tests.

| ID | Scenario | Required outcome |
| --- | --- | --- |
| A01 | Fresh install, offline, no history | Minimal onboarding; no account/permission prompts. User can skip history. Today shows no known cycle day or window, never sample health data. |
| A02 | One start on September 2; today September 29 | Record persists; current day 28; no completed lengths and no prediction. |
| A03 | Two or three valid starts | One or two completed intervals displayed as available; no prediction and no confidence badge. |
| A04 | Worked four-start fixture above | Lengths 28/30/29, cycle day 28, center October 1, range September 28–October 4, Low confidence. |
| A05 | Six completed lengths 28/29/30/28/29/30 | Center offset 29, range offsets 26–32, Moderate confidence; explanation includes selected lengths. |
| A06 | Three identical lengths 28/28/28 | Range offsets 26–30, Low confidence; never a zero-width or certain estimate. |
| A07 | Lengths 20/29/40 | Preserve all observations; spread 20 means no prediction, with descriptive explanation. |
| A08 | More than six completed intervals | Prediction uses the latest six in chronological order; history remains intact. |
| A09 | Even median lengths 28/29/30/31 | Median 29.5 rounds upward to central offset 30. |
| A10 | Same fixture viewed October 5 | Original window is marked passed; current day is 34, not reset; no new fabricated period. |
| A11 | Duplicate start, future input, reversed end, overlapping spans | Clear validation error; no partial saved batch or duplicate record. A start-only entry does not imply a continuing span. |
| A12 | September 2–6 and same-day September 2–2 | Inclusive durations 5 and 1 respectively. Missing end yields unknown duration and only one confirmed calendar day. |
| A13 | Unsorted input and correction before onboarding save | Results match sorted valid input. Draft correction triggers revalidation without losing other entries. |
| A14 | Repository/use-case edit September 2 to September 3 in the worked fixture | Lengths become 28/30/30; as-of September 29 is day 27; center October 3 and window September 29–October 5. Full edit UI is Phase 2. |
| A15 | Leap-year and year boundaries | February 28→March 1, 2024 is 2 days; same dates in 2025 are 1 day; December 31→January 1 is 1 day. |
| A16 | DST in America/Los_Angeles | March 7→9, 2026 and October 31→November 2, 2026 both count as 2 calendar days regardless of elapsed hours. |
| A17 | Travel between America/Los_Angeles and Pacific/Kiritimati | Stored day keys never change. Today/current-day rendering follows the injected local day; clock-skew states never show negative cycle days. |
| A18 | Save failure or store startup failure | Visible recoverable error; draft preserved for retry; no false save success, empty-store reset, or fatal crash. |
| A19 | Relaunch after successful onboarding and quick start logging | Records and onboarding completion persist correctly; onboarding is not repeated; computations reconstruct from raw records. |
| A20 | Calendar and Today | Confirmed and predicted dates differ by shape/text/VoiceOver, not just color; a start-only record does not paint assumed bleeding days. |
| A21 | Offline, signed out of iCloud | Entire vertical slice works. No network, HealthKit, AI, subscription, account, or notification dependency. |
| A22 | Accessibility and layouts | Validate light/dark, VoiceOver, large text, narrow iPhone, iPad, orientation, and Reduce Motion; key controls remain readable and operable. |
| A23 | Storage isolation and fixtures | Separate local store with CloudKit disabled; old template stores untouched; production launches never seed preview values. |
| A24 | History correction/deletion at repository level | Recompute neighbors and derived results; invalid imported records produce a visible issue rather than silent repair. |

Test layers:

- Pure Swift unit tests for day values, validation, intervals, median/ranges, eligibility, and confidence.
- Repository tests using temporary local stores for round trips, isolation, and failure handling; in-memory stores for lightweight cases where appropriate.
- Focused UI tests for onboarding → Today → Calendar, quick logging, restart, empty/error states, and accessibility labels.
- Manual runtime checks on the minimum supported OS and a current OS before release. Test compilation alone is not feature validation.

## 9. Phase 1 boundary

Next implementation scope, only when authorized:

1. Introduce the date-only domain type, validation, calculator, and baseline prediction policy with tests.
2. Add the local period repository and versioned SwiftData schema; keep cloud off and template stores untouched.
3. Replace demo content with minimal onboarding and real Today/Calendar data flow.
4. Complete the vertical-slice acceptance checks above.

Do not add symptoms, pattern detection, platform integrations, subscriptions, AI, partner sharing, or speculative backend infrastructure in this slice.

## 10. Validation and follow-up

Phase 0 configuration validation is recorded in the implementation plan. The first-slice scenarios above remain unimplemented until Phase 1.

Before release, still required:

- Runtime testing on the chosen minimum OS; only newer simulators are installed locally.
- Actual accessibility and contrast review, not just preview compilation.
- Physical-device signing, privacy disclosures, Data Protection and backup verification.
- Statistical backtesting and medical-language review before making stronger prediction claims.
- A revised data-preservation assessment if evidence of a previously distributed health-data build appears.
