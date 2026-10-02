# Device feedback — Calendar logging, deletion warning, onboarding chips

Date: October 2, 2026 · Branch: `testing/on-device-fixes`

## Implemented

- **Corrected logging placement:** Today’s period, symptom, and sex controls are together again in the original logging card below the cycle/prediction cards. On the **Calendar tab**, all three controls now sit immediately below the dates and before the icon legend. The compact row stacks at accessibility text sizes. Selected-date behavior is preserved; future-date logging stays disabled, and recording another overlapping period stays disabled. Record details and editing remain available below/in the existing accessible date list.
- **Permanent-deletion warning:** tapping Settings → Delete all data first presents an explicit “Are you sure?” alert explaining permanent deletion and that it cannot be undone. Cancel leaves records untouched. Continue opens the existing detailed review and requires typing `DELETE` before the actual protected asynchronous reset. External copies, Apple Health, and app-lock exceptions remain explained in that review. No deletion occurs on the initial tap or Continue.
- **Consistent onboarding selections:** Cycle context and Your goals use the same wrapping `SelectionChip` layout as earlier pages. Multiple selections, exclusive None/Prefer not to say behavior, accessibility values, back navigation, save/relaunch persistence, and later Profile editing remain intact. The shared Profile controls receive the same styling.
- **Previous work preserved:** Today’s indexed/lazy calendar, prediction markers, date-formatter caching, unified sparse-data prediction engine, AI insight availability, and single-point charts are unchanged. This follow-up supersedes only the Today quick-action placement described in `DEVICE_FEEDBACK_ROUND_4.md`.

## Validation

- Debug/app/test compilation passed.
- **15 focused unit tests in three suites passed** (onboarding rules, sparse-data behavior, and activity-index state).
- **All five affected UI scenarios passed across focused runs:** Calendar control ordering and selection guards; largest-text context/goal wrapping; onboarding selection/back/save/relaunch; restored Today placement with calendar markers; and cancel-then-confirm deletion followed by durable onboarding after relaunch.
- The initial reset UI run encountered duplicate native-alert accessibility nodes for Continue. The test now uses the explicit `reviewDataDeletion` identifier’s first match; no product safeguard or assertion was removed. The isolated reset rerun passed in 54.455 seconds, with a successful test job.
- **Unsigned iOS Release build passed** in 74.8 seconds.
- Source uniqueness and whitespace checks passed. Runs had hard limits of 150–360 seconds. Evidence: `/tmp/cecy-feedback5-validation.log`, `/tmp/cecy-feedback5-reset.log`, `/tmp/cecy-feedback5-release.log`, and corresponding status files.
- No live AI requests, backend changes, commits, or pushes. This is focused validation, not full-suite or physical-device acceptance; earlier privacy/device gates remain open.
