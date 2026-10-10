# Daily insights and continuing-period logging

October 10, 2026. Working-tree changes; not committed or pushed.

## Triage

| Request | App work | Dependency / limitation |
| --- | --- | --- |
| Replace Today’s estimates with Today’s insights | Shared card added after phase content; duplicate estimates removed | Existing backend supports food, movement, hydration and recovery, not structured skincare or phase evidence |
| Automatic preparation and once-daily Today popup | Asynchronous foreground preparation; consent/setup popup when disabled, ready-result popup when enabled; persisted daily presentation marker | Requires explicit online-AI consent, renewed automatic consent and completed local wellness preferences |
| Same generation on Today and Insights | Both observe `session.dailyAI` and use `daily_wellness_recommendation` | No new endpoint is assumed |
| Recording-progress subtitle | Exact requested wording applied | None |
| Period droplet color | Today/Calendar logging and Today current-period status use confirmed-period palette | Light/dark palette preserved |
| Daily preparation clarity | Control moved beside the actual daily result/generation action, named “Prepare automatically on Today”; concise preparing/ready status on cards | No extra explanatory cards; required consent disclosure retained |
| Add bleeding to an existing period | Selected day saves confirmed daily bleeding with a period link; original start/end/overall flow/note remain unchanged; daily flow optional; no end-date controls in continuation mode | Closed-end contradictions and conflicting existing answers require review, not silent rewriting |
| Phase-aware self-care and skincare | Backend handoff written | See `DAILY_INSIGHTS_BACKEND_HANDOFF.md`; not available until backend contract and iOS integration are completed |

## Diagnosis

Previously, automatic “daily preparation” requested `answer_cycle_question` through `recordInsights()`. It described aggregated recorded facts and unknowns, not today's wellness actions. The For Today wellness destination used a different coordinator/cache and explicit Generate button. The quoted symptoms/allergies sentence was static form copy, not a generated answer. Incomplete preferences, missing consent or a generation control below the viewport could leave only that copy visible.

There was no ready-result popup. Automatic attempts were reserved once daily before sending, while generated results stayed in memory. Failure, interruption or relaunch could therefore leave no result that day and no automatic retry. This was intentional request/privacy limiting but its placement obscured its purpose.

Now both tabs and the popup share one wellness request/result. Visiting the daily destination no longer cancels its request. Automatic consent is renewed because wellness requests include diet, allergies, exercise and goals, broader than the previous automatic record-summary scope. Enabling ordinary AI consent alone still sends nothing. Enabling the separate automatic toggle immediately prepares when prerequisites are complete. Missing preferences link to the local profile; service failures expose the existing error and explicit Generate retry.

## Lifecycle/privacy behavior

- No scheduled background upload: work is asynchronous while Cecy is active and unlocked. App backgrounding cancels pending requests.
- At most one automatic attempt per local civil day, shared across tabs and app launches. Explicit manual retries are allowed; they do not provoke another automatic attempt.
- Popup is shown only on Today, not over the period/history sheets, and no more than once per civil day. A manual visit to the same daily destination also consumes that day's presentation.
- Generated content stays in memory, never in exports or persistent records. Relaunching the same day requires explicit regeneration; persistent daily results are not part of this change.
- Day/record changes invalidate output. Consent loss, lock, sign-out and reset revoke access/cancel work. Privacy persistence failures fail closed.
- Legacy automatic consent does not silently authorize the broader wellness payload. Existing manual consent remains governed by its existing version.
- Unknown cycle phase and skincare are not fabricated or sent through undocumented fields.

## Bleeding semantics

The old continuation option copied the period, set `end` to the selected day and enabled the inclusive-range toggle. This made “more bleeding” look like ending the period and treated all intervening days as confirmed.

Continuation now uses `BleedingReconciliation.recordBleeding`: one explicit `.bleeding` observation, selected day, optional daily flow, link to the original period. Open periods accept explicit linked days only before the next recorded start. Confirmed ends remain hard boundaries. Negative/uncertain daily answers are not overwritten by this shortcut. The existing reconciliation transaction rejects stale drafts and preserves unrelated records. Period metadata edits retain valid daily links; changed boundaries show detached-answer review. The explicitly linked day is recognized as a recorded current-period day in Today and Calendar; intervening days remain unknown.

The stored schema is unchanged. Period duration and completed-cycle calculations still depend on existing period records; daily answers are never converted into an inferred inclusive duration.

## Validation

- Final serial run on iPhone 16e / iOS 26.2: **397 unit tests and six selected UI tests passed**, with one physical-device protection test skipped. Swift Testing reports 398 tests including the skip; the combined summary reports 403 passed and one skipped.
- UI coverage: confirmed bleeding-day save and relaunch without an end date; immediate opt-in preparation and once-daily popup; shared Today/Insights output; memory-only results after relaunch; recording ranges and appointment navigation; consent and missing-preference gates.
- Unit coverage includes consent renewal, deduplication, cancellation, stale output, persistence/migrations, conflicts, and preserved period boundaries.
- Unsigned generic-iOS **Release build passed**. `git diff --check` passed.
- Evidence: `/Users/furahadamien/Dev/cecy-validation/daily-guidance-oct10/` contains `regression.xcresult`, `regression.log`, `regression-summary.json`, and `release.log` outside the repository.
- The earlier `final` attempt exposed two UI-query failures (an icon instead of text, and duplicate insight text behind the popup) and a stalled result collector. Corrected queries preserve the original content/persistence assertions. The final regression run completed normally with `TEST SUCCEEDED`.
- No live AI requests, full UI-suite run, physical-device review, or signed release validation performed. Phase-aware/skincare guidance still requires backend work and subsequent iOS integration. Nothing committed or pushed.

## Follow-up fixes (device feedback)

**Daily preparation showing only a link.** Root cause: automatic preparation could be enabled while required wellness answers (activity, exercise, diet, allergies, goals) were missing. `AIContextBuilder.wellness` then produced no request, so nothing was prepared, while the card still said “Automatic preparation on” and linked to the unrelated profile form. Unknown answers are not defaulted.

- The card now renders full Food, Movement, Hydration and Recovery guidance inline, with safety and allergy notes.
- States are explicit: preparing, ready, paused/finish setup, consent needed, and retry.
- “Finish insight setup” opens the existing preference controls with one **Save & prepare** action. It saves only wellness preferences and prepares immediately when consent allows; without consent, it only saves locally.
- Automatic preparation cannot be newly enabled until the existing API prerequisites are complete.

**Add bleeding day displayed as other bleeding.** Root cause: `DayActivityMarker`/`DayActivityIndex` ignored the daily answer’s period link and always emitted the green `dailyBleeding` marker. A validated linked `.bleeding` answer now renders as the red `period` marker (“Confirmed bleeding”) in Today and Calendar, and selected-day details show “Period bleeding” in red. Only that explicit day changes: gaps stay unknown, the period end is unchanged, and unlinked bleeding/spotting remain green other bleeding.

Validation: 403 unit tests passed (one device-only skip). Affected UI checks passed: linked period day after relaunch, inline insights/popup/no repeat after relaunch, shared Today/Insights result, direct setup route, consent gate, and recording ranges. The popup check initially found a duplicate consent button behind the sheet; its query was scoped to the popup and passed on rerun. Unsigned Release build passed. Evidence: `fix.xcresult`, `popup2.xcresult`, and `fix-release.log` in `/Users/furahadamien/Dev/cecy-validation/daily-guidance-oct10/`. Not committed or pushed.
