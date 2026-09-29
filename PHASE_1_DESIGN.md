# Cecy — Phase 1 System and UI/UX Design

Date: September 29, 2026  
Branch: `phase-1`  
Status: Phase 1 implemented; automated checks passed, with manual acceptance checks pending. Saved-record editing/deletion UI remains in Phase 2, so Phase 1 remains an internal prototype. See IMPLEMENTATION_PLAN.md for verified results and outstanding checks.

References:
- [Implementation plan](IMPLEMENTATION_PLAN.md)
- [Phase 0 foundations and acceptance cases](PHASE_0_FOUNDATIONS.md)

## 1. Design objective

Deliver one trustworthy, complete local tracking experience, not a collection of promising-looking screens.

**User outcome:** “I can record what happened, see where I am in my recorded cycle, understand a rough estimate of my next start, and see which information is known versus estimated.”

**Primary path:** first launch → optional historical entry → locally saved records → Today → Calendar → quick start logging.

Success means the path works offline, survives relaunch, handles mistakes and failures honestly, and remains usable with little or no history. The visual experience should be calm, discreet, and fast. More data should make the app more informative, not more demanding.

The design intentionally does not maximize feature count, abstraction count, animation, or prediction precision.

## 2. Scope and decision hierarchy

The product brief sets the privacy and health boundaries. Phase 0 remains authoritative for date semantics, validation, storage separation, and baseline V1 arithmetic. This document specifies how to implement and present those decisions without quietly changing them.

### In the approved Phase 1 slice

- iPhone-first SwiftUI app with adaptive iPad support, iOS/iPadOS 17+.
- Optional historical entry during onboarding; ability to add history later.
- Local, versioned SwiftData storage with cloud explicitly disabled.
- Start records with optional confirmed ends, identifiers, and audit timestamps.
- Pure Swift validation, calendar-day arithmetic, cycle lengths, current day, and baseline prediction results.
- Real Today and Calendar screens replacing sample values.
- Quick logging, basic record viewing, and minimal Settings.
- History presentation sufficient to explain calculations; no advanced Insights engine.
- Recoverable startup/save errors and tests for the vertical slice.

### Outside this slice

Symptoms, flow/notes entry, ongoing-bleeding inference, phase/ovulation/fertility estimation, advanced statistics, trends, notifications, biometric locking, export, HealthKit, StoreKit, AI, CloudKit, partner sharing, analytics SDKs, and backend infrastructure.

### Recommended scope refinement — not assumed authorized

**Add minimal saved-record date correction and deletion before any real-user release.** Reuse the period form from read-only record details, preserve identity on edits, and require confirmation for deletion. No bulk editing or advanced history management is needed.

The current plan defers saved-record editing/deletion UI to Phase 2. The base Phase 1 design below respects that boundary: draft correction and tested repository mutation exist, but saved-record edit/delete controls are not exposed. This makes Phase 1 an internal prototype, not a release-ready health-data product. Do not hide the limitation behind a disabled control or claim the tracker is ready for public use.

Decision at the start of implementation: either explicitly adopt this small refinement or retain the Phase 2 boundary and keep Phase 1 internal. The implementation agent must not silently expand scope.

## 3. Important semantic distinctions

1. **Predicted start window, not bleeding duration.** September 28–October 4 means possible dates on which the next period could start. It does not mean bleeding is expected for seven days.
2. **A completed cycle interval needs two starts, not an end date.** Four start-only observations yield three completed start-to-start intervals. Unknown bleeding ends must not disqualify those intervals.
3. **Unknown end is not ongoing bleeding.** A September 2 start without an end marks September 2 only. It does not imply bleeding through today.
4. **Current day is a count from the last recorded start.** It is not proof of a physiological phase or that every intervening period was logged.
5. **No estimate is a valid result.** Sparse, inconsistent, or widely varying data should not produce a default 28-day forecast.
6. **Confidence is a provisional heuristic.** Low/Moderate labels describe record quantity/consistency, not calibrated probabilities or medical certainty.
7. **The canvas is a visual reference only.** Its sample Moderate label and dates are not acceptance outputs. No production screen may retain fabricated health numbers.

## 4. System structure

### 4.1 Dependency direction

SwiftUI feature views → main-actor feature/app state → domain use cases and repository contract → SwiftData implementation.

Pure Swift domain calculations receive immutable values and explicit dates. They never fetch storage, read the environment, invoke UI, or contact a service.

The composition root chooses concrete dependencies once. Views do not create containers or reach for shared persistence singletons.

### 4.2 Planned responsibilities

| Area | Responsibility | Must not do |
| --- | --- | --- |
| App composition | Create local repository, clock/date context, app state; coordinate startup/retry and lifecycle refresh | Seed fixtures or silently fall back to an empty store |
| App/feature state | Publish load/save states, immutable snapshots, selected tabs/dates, drafts and user-facing errors | Implement prediction formulas or manipulate SwiftData objects directly |
| Period use cases | Validate candidate records, orchestrate onboarding/logging and recomputation | Depend on SwiftUI or accept invalid records because a picker allowed them |
| Domain | Date-only values, period values, interval derivation, eligibility, prediction and confidence | Know storage URLs, ModelContext, views, or the real current clock |
| Repository contract | Load a coherent snapshot and save validated changes atomically | Leak persistent model instances into feature views |
| SwiftData adapter | Map raw fields, control context/save/rollback, enforce data integrity and persistence boundaries | Infer cycles or implement medical/statistical rules |
| Presentation helpers | Localized date/range formatting, day decorations, explanations from structured reasons | Recalculate confidence or decide eligibility independently |
| Shared UI | Small reusable cards, buttons, validation messaging, spacing/color tokens | Become a general design-system framework |

### 4.3 Organization when implementation starts

- **App:** composition root, root launch state, tab/navigation coordination.
- **Domain:** date-only values, period values, validation, calculator, prediction policy, repository contract/use cases.
- **Data:** V1 schema, persistent record mapping, local repository.
- **Features:** Onboarding, Today, Calendar, Logging, a lightweight Insights/history surface, Settings.
- **Shared:** date formatting and the few visual components used by multiple features.
- **Tests:** domain, repository, feature-state, and focused UI suites.

Use the existing app/test targets initially. No feature packages, coordinator hierarchy, global service locator, event bus, generic repository framework, or future service scaffolding.

A type deserves an abstraction when it isolates persistence, time, or a replaceable calculation policy—not merely because every class could have a protocol.

### 4.4 State ownership

A single main-actor tracker state owns the last successfully loaded snapshot and its derived cycle overview. Today, Calendar, and history consume the same revision, so they cannot independently disagree about a save.

Short-lived form state owns draft values separately. Selecting a date or toggling an optional end does not mutate a saved record. Navigation state is not a health observation and need not be persisted in Phase 1.

Avoid a view model per card. Add a feature-specific state object only for real responsibilities such as a multi-record onboarding draft or calendar selection.

### 4.5 Concurrency

- The SwiftData context and its repository remain main-actor confined with autosave disabled.
- Feature/app state is main-actor isolated.
- Domain value types are immutable and Sendable where appropriate; pure operations are explicitly nonisolated where the target's default MainActor setting would otherwise apply.
- Unit tests call domain operations without starting SwiftUI or creating a store.
- Use async boundaries for app-level loading/retry coordination where useful, but do not pretend that synchronous context work becomes background work merely by wrapping it in a Task.
- Keep the small Phase 1 read/compute path simple and measure it. No detached task may capture a ModelContext or model object.
- Serialize write operations. Disable duplicate submissions while saving and validate again inside the save boundary.
- If a future background calculation is needed, pass an immutable snapshot plus a revision token and discard stale results. Do not add this machinery before profiling justifies it.

## 5. Data design and local consistency

### 5.1 V1 schema

| Record | Fields | Purpose |
| --- | --- | --- |
| Period record | UUID; required start day key; optional end day key; createdAt; updatedAt | Raw user observation only |
| Local app-state record | Stable singleton key; onboardingCompletedAt (optional) | Durable completion even when the user chooses no history |

The app-state record is a narrow addition needed by the actual onboarding feature, not a container for future preferences. Both records belong to the same V1 local store so onboarding dates and completion can be saved together.

Day keys follow Phase 0's validated Gregorian `YYYYMMDD` convention. Created/updated/completion timestamps are absolute instants. No persisted prediction, cycle entity, average, confidence, or calendar decoration is introduced.

Do not use a unique start-date constraint as an implicit conflict-resolution mechanism: SwiftData uniqueness behavior must not silently merge two user entries. Explicit duplicate validation is required before inserting and when reading a snapshot. Stable record IDs support idempotent retries; tests must verify that identity conflicts are reported, not silently overwritten.

A missing app-state record means onboarding is incomplete. Multiple conflicting app-state records are a data-integrity error, not permission to choose an arbitrary one.

### 5.2 Store ownership and transition

- One container, one repository-owned write context, one explicitly named local store under Application Support: `Cecy/CecyPeriodsV1.store`.
- CloudKit database explicitly set to none.
- Introduce the versioned schema before persisting observations. Add a migration plan when there is an actual next schema to migrate to; do not create speculative migration stages.
- Old template stores remain untouched. Generic timestamps must never be converted into periods.
- Retire the unused Core Data source/model from the active build only after reference checks; deleting source is not deleting user stores.
- Never save health content into UserDefaults, global singletons, console logs, or crash metadata.
- Local storage may be included in system device backups. No promise of custom encryption, end-to-end synchronization, or permanent exclusion from backups is made.

### 5.3 Read boundary

Fetch raw records → map and validate fields → validate cross-record invariants → produce a sorted immutable snapshot → derive the overview with an explicit as-of day.

Do not silently skip invalid records and compute from the remainder. A corrupt or contradictory record can change every subsequent interval. Fail the affected calculation explicitly while preserving the raw store.

A later read failure may retain a visibly stale, last-known snapshot, but must not present it as freshly loaded or accept additional writes until the repository is ready again. First-load failure has no trusted snapshot and shows recovery instead of fake empty history.

### 5.4 Write boundary

Prepare stable draft identifiers → validate the entire candidate dataset → apply changes and, for onboarding, the completion marker in one context transaction → explicitly save → publish the committed snapshot → derive the overview once → report success.

On failure: roll back context changes, retain the feature draft, leave the previous committed snapshot unchanged, and explain that the save did not complete. Never advance onboarding before the save succeeds.

Avoid a second fallible read after a successful save being reported as a failed save: construct the committed value snapshot from the validated candidate state, or distinctly report a refresh failure without encouraging a duplicate insertion.

The write path must have no interleaving validation/save gap that allows a second form to insert the same start. A successful save is the point after which the UI may say “Recorded.”

### 5.5 Onboarding durability

- With history: save the validated batch and completion marker atomically.
- Without history: save the completion marker alone, then show the empty Today state.
- Failure in either path keeps the user on onboarding with their draft intact.
- If records already exist but onboarding is incomplete, preserve them and allow completion without duplicating them.
- Onboarding drafts stay in memory until committed. Backgrounding retains them while the process lives; termination before save can lose them. The screen must say that dates are saved when the user continues.
- Do not persist half-completed sensitive drafts merely for convenience in this slice.

## 6. Domain result design

### 6.1 Inputs

An immutable period snapshot, explicit as-of civil day, and baseline V1 policy. A clock converts an instant to local today at the app boundary; calculation services never call the real clock themselves.

### 6.2 Derived overview

Return distinct concepts rather than many loosely related optional properties:

- Snapshot revision/context.
- Current-cycle-day availability and latest recorded start.
- All completed start-to-start intervals, preserving the source record IDs/days.
- Prediction outcome with a typed unavailability reason or a valid prediction.
- Prediction center, earliest/latest start dates, selected source lengths, confidence, and explanation inputs.
- Temporal presentation status: upcoming, within the window, or window passed.

Insufficient history, wide variation, invalid data, and dates later than local today are not the same state. A save failure is not a prediction result at all.

Explanations derive from structured reasons. UI strings do not become the business rules.

### 6.3 Baseline V1 — unchanged from Phase 0

- Three completed intervals required; four recorded starts.
- At most six most recent completed intervals inform prediction.
- Spread greater than 14 days means no estimated window.
- Center uses the median, with half-day rounding upward.
- Earliest offset: maximum of one day and minimum length minus two days.
- Latest offset: maximum length plus two days.
- Low confidence for three to five intervals; with six, Moderate only for spread at most seven days, otherwise Low. No High label.
- No outlier deletion, default 28-day forecast, synthetic cycles, or automatic roll-forward.

These are prototype heuristics, not statistical coverage guarantees. Identical intervals still receive a padded range. Unknown ends do not reduce completed-interval count. The open interval from the latest start to today is excluded from prediction inputs.

### 6.4 Known model limitations

The policy cannot know whether a period was missed in logging, whether the record represents spotting, or whether medical circumstances make prediction inappropriate. Stable but unusual intervals do not become clinically normal because the algorithm can produce a range.

Do not solicit additional sensitive reproductive information solely to make this simple algorithm appear more capable. Use modest language, no fertile-day claims, and no numerical certainty. Any change to eligibility or confidence belongs in a documented policy revision with tests and later backtesting.

## 7. Application and interaction state machines

### 7.1 Launch

Launching → opening local store → loading validated snapshot → onboarding or ready.

At any initialization failure: recovery screen → explicit Retry → same initialization path. There is no route from failure to an empty replacement store, permanent spinner, or sample dashboard.

### 7.2 Save

Editing → validating → saving → saved.

Validation failure returns to editing with inline field/record errors. Save failure returns to editing with a form-level recovery message and preserved input. Cancel before saving dismisses without a write. Once save is committed, cancellation must not be described as undo.

Keep validation/submission short and serialized. Never initiate a write merely because a sheet disappears.

### 7.3 Date and lifecycle refresh

Refresh today and derived results on foregrounding, local day changes, and significant time-zone/clock changes. Do not poll continuously.

Do not reset a calendar month, selected historical day, or an open draft when the day changes. Revalidate the draft at save time using current local today. Travel never rewrites saved day keys.

If a previously valid latest start now appears ahead of local today, preserve it and show a date-check state rather than a negative day count or silent deletion.

## 8. Information architecture

Maintain the familiar four-destination shell already established by the canvas:

| Destination | Phase 1 responsibility |
| --- | --- |
| Today | Current recorded cycle context, start-window estimate/reason, primary logging action |
| Calendar | Browse dates, distinguish records/estimates, view a record, log for a past/current date |
| Insights | Lightweight “Your cycle history” and prediction evidence from existing derived intervals; no new insight engine or advanced statistics |
| Settings | Privacy/storage explanation, prediction-method limitations, app/version information |

Do not fill Insights with sample averages or Settings with inactive toggles for unimplemented integrations. Advanced insights are Phase 2+, not pretend features.

If the minimal Insights surface cannot provide real information, use one honest empty state. It must not become a second dashboard. Logging stays a sheet/action, never a fifth tab.

## 9. Onboarding UX

### 9.1 One focused screen, not a questionnaire

Header: **“A clearer view of your cycle”**.

Short supporting text: “Start with dates you remember. Your records are stored on this device; no account is needed.” A privacy details link explains backups and the absence of integrations without demanding that the user read a policy before continuing.

History section: **“Previous period starts”**.

Supporting text: “Add the first day of each period. Four recorded starts let Cecy make an initial estimate. You can start with fewer.”

Do not require age, usual cycle length, reproductive goals, symptoms, name, or notification permission.

### 9.2 Adding history

- “Add a previous period” opens the reusable period-entry sheet.
- Require only a start date; optionally reveal “Add an end date, if known.”
- An end is entered only if the user explicitly chooses one. Never prefill and silently save a typical duration.
- Add the validated entry to an unsaved draft list, ordered by start, with Edit and Remove actions.
- Rows show the full date including year and either a confirmed end or “End not recorded.”
- Clearly label the list as not yet saved. Confirmation through Continue saves the batch.
- Editing within this draft is approved Phase 1 scope; it is distinct from editing saved records.
- Duplicate/overlap messages point to the conflicting draft or existing record without throwing away other entries.

Use native date controls with an explicit Gregorian/date-only conversion boundary and localized presentation. Provide practical month/year access through the date picker rather than making old-history entry require dozens of month-arrow taps.

### 9.3 Footer behavior

- Empty draft: primary **“Continue without history”**; adding history remains available.
- Nonempty valid draft: primary **“Save and continue”** with a concise record count.
- Invalid draft: preserve inputs, explain errors, and prevent submission.
- Saving: show progress in the action, disable duplicate submission, retain layout.
- Failed save: remain on this screen with “Your dates haven’t been saved. Try again.” and retained rows.

Do not offer a second ambiguous Skip action that discards a populated draft. If a user chooses to abandon a populated draft, confirm the discard.

Once completed, onboarding is not shown again just because the saved period list is empty.

## 10. Today UX

### 10.1 Content order

1. Small “Today” heading and localized current date.
2. **Cycle card:** current day when known; always ground it in the last recorded start.
3. **Estimate section:** start window or a useful unavailability explanation, with an optional explanation sheet.
4. **Primary action:** “Log period start.” Secondary text action: “Add previous periods.”
5. At most one factual supporting item, such as how many completed intervals are available. No fabricated personal observation.

The current canvas's large introductory slogan is reduced in priority so actual information and logging are reachable sooner. Avoid a decorative circular progress ring: there is no known fixed cycle completion percentage.

### 10.2 Visual hierarchy

The cycle card can use sage, with “Day 28” in a rounded scalable title and “Since your recorded start on September 2” underneath. The date range receives a clear heading and title-sized text, not a warning color or medical badge.

Copy: **“Estimated next start”**, then **“Sep 28 – Oct 4”**. Include year where needed, especially ranges crossing a year boundary.

Secondary explanation: “A rough window based on your recorded starts.” Confidence appears only for a real available estimate; it is not a decorative score.

### 10.3 State matrix

| Data/state | Cycle area | Estimate area | Useful action |
| --- | --- | --- | --- |
| No starts | “Your cycle history starts here.” No invented day | “Add previous starts when you’re ready.” No range or confidence | Log period start / Add previous periods |
| One start | Day count and its recorded origin | “One start recorded. Four starts are needed for an initial estimate.” | Add previous periods |
| Two starts | Day count | “Two starts recorded; one completed interval.” Explain four-start requirement | Add previous periods |
| Three starts | Day count | “Three starts recorded; two completed intervals.” No forecast yet | Add previous periods |
| Eligible history | Day count | Estimated next-start range, Low/Moderate label, explanation | Log period start |
| Wide variation | Day count still available if dates are valid | “Your recorded intervals vary more than this simple estimate can support.” No range/confidence | View recorded history |
| Window underway | Same day count | Same original range; “You’re within the estimated start window.” No certainty claim | Log period start |
| Window passed | Day count continues | Original range marked “Estimated window passed.” “No new start has been recorded.” | Log a start / View history |
| Latest start ahead of local today | No negative cycle day | “A recorded date is ahead of today. Check your device date and recorded history.” Withhold affected estimate | View history; correction if refinement approved |
| Loading failure | No fabricated empty-state data | Recovery screen, not an unavailable prediction card | Retry |

No red “late” countdown, pregnancy suggestion, diagnostic interpretation, or assumed phase. Do not imply that adding more data guarantees an estimate if variability remains high.

### 10.4 Explanation sheet

Triggered by a clearly labeled “How this estimate works” action, not an unlabeled information icon.

Order:

1. Estimated start window and provisional confidence.
2. “Based on these completed intervals” with actual lengths, source dates, and count.
3. Plain explanation that the prototype uses recent recorded intervals and adds a small margin.
4. Specific reason for Low/Moderate confidence based on the actual record count/spread.
5. “This is a rough estimate, not a guarantee. Missing records can affect it. It is not suitable for contraception or diagnosis.”

Put technical details behind a secondary disclosure if necessary. The central date is not promoted over the range; users should not leave thinking the center is an exact promise.

## 11. Period-entry sheet UX

Use one reusable form for adding an onboarding draft, recording a new entry, and—only if approved—editing an existing entry. Mode determines commit behavior and button wording.

### Quick current-start path

Today → “Log period start” → sheet showing today as the start → “Record start” → committed confirmation on Today.

Two intentional taps with no date change. Do not write immediately on opening the sheet. Do not add an extra generic confirmation dialog for a non-destructive save: the form itself is the review surface.

### Form fields

- Title: “Record a period.”
- Start date, required, defaulting to today or the selected calendar day.
- Optional disclosure: “Add an end date, if known.” Off by default.
- If enabled: explicit end-date picker, bounded from start through today. A same-day end is allowed.
- Short note: “Leaving the end blank records the start only.”
- Cancel and a context-specific save action.

The optional end is accepted on initial entry, including historical onboarding, because the schema and calendar already support confirmed spans. Phase 2 adds the full ongoing editing workflow; Phase 1 must never infer an end on behalf of the user.

When start changes after an end was entered, show validation rather than silently moving the end. Date choices live as civil days, not long-lived Date instants that shift during travel.

### Validation messages

- Duplicate: “A period already starts on this date.” Offer viewing the existing entry where available; do not create a second record.
- Future start/end: “Recorded dates can’t be later than today.”
- Reversed dates: “The end date must be on or after the start date.”
- Overlap: “These dates overlap another recorded period.” Show the relevant record range.
- Save error: “This entry wasn’t saved. Your dates are still here so you can try again.”

Avoid displaying raw system errors, database paths, or medical conclusions. VoiceOver should announce the relevant validation summary and allow navigation to the field.

### Completion and dismissal

After successful save, close the sheet and show a persistent, dismissible confirmation near the updated context, not a fleeting toast as the only feedback. VoiceOver announces success. The calendar/Today snapshot updates together.

Swipe dismissal or Cancel with meaningful unsaved changes should confirm discard. While saving, prevent a second submission and ambiguous dismissal. Failure keeps the form open. Never save from an on-disappear callback.

A saved record is not silently deleted by dismissing its confirmation. A real Undo action would require a transactional inverse and is not a substitute for a designed correction workflow.

## 12. Calendar UX

### 12.1 Layout

- Header: “Calendar.”
- Month/year heading with accessible previous/next controls.
- “Today” action and “Go to date” date-picker action for practical history access.
- Localized weekday labels, Gregorian month grid, and a concise recorded/estimated legend.
- Selected-date detail directly below the grid, or inline with the selected row in list layout.
- Logging action anchored to the selected past/current date.

Initial month/selection is today. Navigating months preserves the selected day-of-month where valid, clamping to the last day when needed. “Today” intentionally resets both. Tab switching and background refresh do not unexpectedly jump the user away from history.

The calendar can display future dates to show estimates, but cannot record future observations. A future selected day explains this and does not offer an enabled recording action.

### 12.2 Separate visual channels

| Meaning | Visual representation | Spoken/text meaning |
| --- | --- | --- |
| Confirmed start/day | Sage fill and filled-drop mark | “Recorded period start” or “Recorded period day” |
| Estimated start possibility | Dashed boundary | “Possible next period start; estimate” |
| Selected day | Underlined/bold day number and selected accessibility trait | “Selected” |
| Today | Small neutral marker, with explicit Today in detail/VoiceOver | “Today” |
| No record | Ordinary cell | “No recorded entry” |

Selection must not replace the dashed prediction boundary. If a confirmed span and estimate overlap, preserve both meanings instead of painting the estimate as fact. The detail explains each separately. Color alone never encodes state.

Predicted marks cover possible **start dates only**. Do not paint a projected five-day bleeding span from the center or each possible start. The legend says “Estimated start window,” not simply “Period.”

A month-edge window continues visibly in the next month. The selected-date detail and explanation provide the full range.

### 12.3 Detail states

- Start-only record: start date, “End not recorded,” no invented duration.
- Confirmed span: start, end, inclusive duration; identify the owning record rather than one new record per day.
- Estimated date: full possible-start range and explanation access; clearly not saved history.
- Empty past/current day: “No period recorded for this day” and “Record a period.”
- Future day: available estimate information, otherwise “No recorded entry”; future logging unavailable.
- Multiple invalid overlapping raw records: surface integrity error rather than pick one silently.

Base Phase 1 detail is read-only for existing records. If the recommended refinement is adopted, add “Edit dates” and destructive “Delete entry” below the factual content, reusing the same validation and form.

### 12.4 Accessible grid sizing

A seven-column grid with 44-point minimum cells and six 2-point gaps needs at least **320 points of inner width**, before page/card padding. Check available width, not device model names.

Use reduced calendar-specific padding rather than inheriting 24-point card padding blindly. On a 375-point-wide screen, 16-point outer margins and 8-point inner margins leave 327 points for the grid. Narrower containers or accessibility text sizes should use an accessible day-list layout instead of shrinking text or touch targets.

In list mode, each row has a full localized date, status text, and an accessible selection action of at least 44 points. Selected detail expands near its row. Month controls and Today remain available. Essential information does not require long press, precise tapping, or horizontal swiping.

Only materialize the displayed month (roughly 28–31 dates plus grid padding). Never construct a day object for every day in a user's lifetime.

## 13. Minimal Insights and Settings

### Insights / Your cycle history

- Show a simple list of completed start-to-start intervals already computed by the domain layer.
- Identify date boundaries and length; label the latest ongoing interval as not completed rather than adding it to averages.
- Offer access to the current estimate explanation when available.
- With fewer than two starts, explain that completed intervals appear after another start is recorded.
- Do not add trends, symptom patterns, average-duration widgets, distribution charts, or AI-style narratives in this slice.

This is supporting evidence for the core tracker, not delivery of the later Insights feature phase.

### Settings

Only truthful, implemented content:

- On-device storage and system-backup explanation.
- No account required; no optional integrations connected.
- Prediction-method limitations and privacy/health boundaries.
- App/version information.

No disabled HealthKit, Face ID, subscription, notification, or AI switches. Avoid “Delete all data” or “Export” buttons until they work. Their absence, together with saved-record correction limitations, is part of why this slice is internal-only until subsequent release gates are satisfied.

## 14. Visual design system

Preserve the canvas's warm neutral background, sage highlights, charcoal/semantic text, and restrained rounded cards. Do not introduce a pink default, branded illustration dependency, or decorative cycle wheel.

### Foundations

- Reuse Phase 0's light/dark palette; extract only reusable tokens during implementation.
- Text hierarchy: large title for page heading, rounded title for current day, title2 for estimated range, headline for sections, body/subheadline for explanations, footnote for secondary caveats.
- Text scales with Dynamic Type; never use a tiny fixed font for critical interpretation.
- Spacing scale: 8, 12, 16, 24 points; 24-point card radius; adjust layout where accessibility requires it.
- Standard page/card spacing can remain 24 points; calendar is an explicit compact-padding exception.
- Cards have one primary purpose. Prefer spacing and semantic text to heavy shadows, gradients, multiple nested outlines, or dense badges.
- Use native tab bars, sheets, date pickers, confirmation dialogs, and controls where they behave better than custom equivalents.
- On iPad, retain readable content width and use a two-column Calendar/detail layout only when there is enough space; do not invent a separate navigation system.

### Motion, privacy, and tone

- Only subtle state transitions, never animation required to understand the result.
- Respect Reduce Motion and preserve VoiceOver focus during updates.
- No streaks, completion rings, shame language, missed-log guilt, or “normal/abnormal” scores.
- “You recorded…” is more honest than “Your body is…” when all the app knows is a log.
- No permission prompts, network spinners, paywalls, or external links required to use the slice.
- Concealing app-switcher content and biometric locks remain later privacy work; do not advertise them as already present.

## 15. Accessibility and localization specification

- Every primary action and calendar cell has at least a 44-by-44-point target; compact icon size must not imply compact hit area.
- Full VoiceOver date/status labels include the year when relevant, recorded versus estimated meaning, today, and selection.
- Group related facts without making whole complex cards one un-navigable accessibility element.
- Label headings and controls semantically; announce save/error results once, not on every recomputation.
- Move focus to validation summary when needed; preserve the user's reading position on calendar/day refresh.
- Support Dynamic Type through accessibility sizes, landscape, split-screen iPad, increased contrast, light/dark appearances, and Reduce Motion.
- Verify WCAG AA contrast in actual rendered states, including secondary text and disabled states; palette choice alone is not evidence of compliance.
- Localize complete sentences with pluralization for starts/intervals. Do not concatenate fragments that break grammatical agreement.
- Use locale-aware date and number presentation. Stored day keys always use Gregorian semantics; UI conversion must be explicit when the system calendar differs.
- Derive week ordering deliberately from locale preferences, without switching the domain calendar or rewriting dates.
- Test right-to-left layout and avoid hardcoded directional assumptions in navigation icons.
- Gregorian-only month browsing is an initial limitation; do not claim full alternative-calendar support until tested/designed.

## 16. Error and recovery design

| Failure | What the user sees | What the system preserves |
| --- | --- | --- |
| Store cannot open on launch | “Your records couldn’t be opened.” Retry; no reset button | Original store and files; no substitute empty history |
| Protected data temporarily unavailable | Generic availability explanation; retry after device access returns where detectable | All records; no repeated crash loop |
| Load detects invalid records | “Some recorded data needs attention.” No affected prediction | Raw data for future recovery; no silent filtering |
| Save fails | Form-level message, Retry, retained inputs | Previous committed snapshot and unsaved draft |
| Duplicate or overlap | Inline explanation linked to relevant dates | All valid existing/draft entries |
| Clock/time-zone inconsistency | Date-check message, preserved record values | Original civil dates and history |
| Calculation cannot represent a date | Unavailable result, not wrapped/overflowed dates | Valid raw records and their identities |

Use structured internal error categories and safe user-facing messages. Do not leak health records, raw SQL, file paths, or NSError userInfo into diagnostics. Avoid unbounded automatic retries. If a UI cannot actually repair corrupted storage yet, say so; do not promise that Retry repairs corruption.

## 17. Privacy and security boundaries

- No feature-originated network requests or third-party analytics/advertising dependencies in Phase 1.
- Do not collect unrelated identifying, sexual, medication, or symptom data.
- No health records in logging, pasteboards, URL routes, notification payloads, launch arguments, screenshots used as fixtures, or shared containers.
- Normal user screenshots remain possible; do not claim screenshot blocking.
- No backend or developer secrets are needed; no Keychain service is introduced without a real secret to protect.
- Validate local storage access/protection and device-backup behavior before release. Use Apple platform protections; do not invent encryption.
- On-disk Phase 0 checks confirmed empty entitlement and Info.plist dictionaries. The implementation preflight must verify the actual built configuration again, rather than relying on stale editor attachments.
- Keeping old stores untouched is preservation, not a claim that future delete-all will erase them. Phase 2/5 deletion design must explicitly inventory any app-owned legacy stores before promising “all data.”

## 18. Preview and test isolation

Create a debug-only preview factory that supplies fixed date contexts and an explicitly in-memory repository/store. Production composition accepts neither sample seeding nor a runtime “demo mode” switch.

Do not rely on the assumption that a preview macro alone excludes every fixture from production. Wrap fixture implementations in DEBUG compilation conditions and ensure the release app root has no dependency on them.

Provide previews for:

- Empty Today after skipping history.
- One, two, and three recorded starts.
- Available estimate with Low and Moderate confidence.
- High variability and passed-window states.
- Onboarding with draft entries and an inline validation error.
- Logging save failure with preserved values.
- Calendar recorded start, confirmed span, prediction, overlapping display meanings, and narrow/list layout.
- Light, dark, accessibility text sizes, and iPad.

UI tests use isolated test stores and fixed clocks via debug-only test composition. Never reset production history based on a launch argument in a Release build. Domain tests do not need the app container or simulator UI. Repository tests include real temporary file-backed stores, not only in-memory mocks.

## 19. Acceptance and verification plan

Phase 0 cases A01–A24 remain the baseline. These design-specific checks refine them rather than claim implementation has passed.

| Area | Required verification | Foundation cases |
| --- | --- | --- |
| Date values and validation | Impossible dates, leap days, year boundaries, DST, date-line travel, same-day spans, duplicates/overlaps | A11–A17 |
| Domain calculations | Start-only records count toward completed intervals; open latest interval does not; exact fixture arithmetic | A02–A10, A12, A14 |
| Prediction boundaries | Exactly 3 versus 2 intervals; exactly 6; spread 7/8 and 14/15; half rounding; padding; final window day versus day after | A03–A10 |
| Onboarding | Empty completion survives relaunch; batch/completion atomicity; draft errors; retries cannot duplicate records | A01, A11, A13, A18–A19 |
| Repository | Mapping round trips, invalid stored input, rollback, store separation, explicit cloud-off configuration, edit/delete recomputation | A18–A19, A23–A24 |
| Shared state | Today/history/Calendar show the same saved revision; no stale overview after mutation or local-day changes | A14, A17, A19–A20 |
| Calendar semantics | Window denotes start possibilities, not bleeding; unknown ends mark one day; month/year crossing and selection shape | A12, A20, A22 |
| Recovery | Startup failure differs from empty history; no destructive fallback; no false save success | A18 |
| Privacy | No sample seeding or feature networking; no health payload logging; offline and signed-out-of-iCloud operation | A21, A23 |
| Accessibility | Dynamic Type, 44-point target dimensions, VoiceOver, right-to-left, contrast, orientation and list fallback | A22 |

Performance checks should cover realistic synthetic multi-year histories (for example, hundreds of starts), rapid repeated taps, and repeated month navigation. Do not use real health data in fixtures. Recompute once per committed change/day-context change, not for every view body evaluation.

Compile Debug and Release, run domain/repository/feature-state tests, and execute focused UI flows on an available simulator. Record the actual environment and results. Minimum iOS 17 runtime and physical-device validation remain distinct release gates; builds against a lower deployment target do not replace them.

## 20. Implementation order once authorized

1. **Domain first:** validated day values, periods, validation, interval calculator, baseline prediction result/policy; exhaustive deterministic tests.
2. **Storage boundary:** V1 schema including required onboarding state, isolated local repository, read validation and atomic writes; file-backed repository tests.
3. **Application state:** composition, launch/retry, snapshot/overview, injected date context and lifecycle refresh; state tests.
4. **Onboarding and shared entry form:** draft add/edit/remove, optional end, empty completion, save/error behavior.
5. **Today:** replace samples with real overview, quick recording, unavailable states and explanation sheet.
6. **Calendar:** month/date navigation, recorded versus estimated rendering, details, selected-date logging and accessible list layout.
7. **Supporting surfaces:** minimal history and Settings; remove fake statistics, preview banners and placeholder service controls from production.
8. **End-to-end hardening:** relaunch, retry/rollback, date/time-zone changes, offline behavior, accessibility, release build and acceptance tracking.

Each step should compile and have meaningful tests. Avoid creating all proposed files as empty scaffolding. Do not mark the phase complete after domain tests alone: the actual end-to-end offline user flow is the milestone.

## 21. Decisions to settle before coding

| Question | Recommended position | Scope effect |
| --- | --- | --- |
| Saved-record correction before real users? | Reuse the form for minimal edit/delete, but obtain explicit approval to move this from Phase 2. Otherwise keep Phase 1 internal. | Only proposed expansion |
| Persist skipped-onboarding completion? | Yes, in the same V1 store as period records for atomic completion. | Necessary implementation detail |
| Optional end on first entry? | Yes, explicitly opt-in; no assumed duration or ongoing bleeding. | Clarifies existing optional-end model |
| Four tabs versus empty feature shells? | Preserve four tabs; Insights shows only real interval history/evidence, Settings only implemented information. | No advanced insights/services |
| Prediction wording? | “Estimated next start” / “Estimated start window.” | Clarification, no algorithm change |
| Date and confidence policy? | Keep Phase 0 unchanged, including the four-start minimum and provisional labels. | No scope change |
| Public release at the end of this slice? | No. Complete later correction/privacy/accessibility/release gates first. | Matches phased roadmap |

## 22. Design completion checklist

- [x] System boundaries and state ownership defined.
- [x] Local schema, skipped onboarding, and atomic-save behavior specified.
- [x] Start-window semantics and unknown-end behavior clarified.
- [x] Onboarding, Today, logging, Calendar, history, and Settings behavior specified.
- [x] Empty, uncertain, passed-window, invalid-date, and storage-error states specified.
- [x] Calendar touch-target and non-color selection strategy defined.
- [x] Accessibility, localization, privacy, preview isolation, and test approach documented.
- [x] Implementation order and scope recommendation made explicit.
- [x] Proceed with the base design; saved-record correction remains in Phase 2 (no scope expansion).
- [x] Phase 1 implementation authorized and started.

These checks track design work only. They do not mark any Phase 1 implementation task or runtime test complete.
