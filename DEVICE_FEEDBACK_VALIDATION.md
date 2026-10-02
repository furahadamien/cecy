# Device-feedback refinements — October 1, 2026

Branch: `testing/on-device-fixes`. User-authorized UI/profile refinements; no backend changes, live requests or blanket resumption of the deferred full-app acceptance milestone.

## Implemented scope

- Activity level, diet and allergy status now use wrapping selection chips like symptoms/exercises. Common food allergens and custom entries use multi-select chips; unanswered and explicitly no known allergies remain distinct. Changes commit only through Profile Save; cancellation preserves existing data.
- Short wellness disclosure: preferences are stored locally, but selected details are sent when suggestions are requested. We cannot truthfully claim all processing stays on-device. The optional consent screen still names the external providers and scope. Repeated branding is removed from normal loading/results/logging flows.
- Loading uses **Generating insights** or **Mapping your symptoms**. Results use **Key insights**, cards, readable body spacing and section icons. Optional safety messages, severe-symptom caution, allergy checks and local supporting facts remain available. Output is still plain text, not executable Markdown/HTML.
- Record questions have a bordered, labeled input and count-only **n / 100** counter. UI, context builder and remote service enforce 100 characters. Descriptions/private notes retain their independent 2,000-character limits.
- Month Calendar and Today share deterministic recorded-day markers: period/confirmed bleeding, each symptom’s existing symbol, and a sexual-activity heart with full activity names in accessibility labels. Multiple markers wrap rather than disappearing. Predictions never create recorded markers.
- Today opens a horizontal date strip centered on today; past/future ranges expand while scrolling. A Today button recenters. Tapping another day shows its records and targets logging to that date; future logging stays disabled. Today’s cycle summary and wellness context still refer to today.
- Separate optional **Your gender** and **Who do you have sex with?** onboarding steps support skipping, clearing, review/back navigation and inclusive choices. Partner answers can be multi-selected; not sexually active/prefer not to say are exclusive. Progress uses the actual step count. Answers can be edited in Profile.
- Optional Codable profile fields preserve old SwiftData V6 payloads; no schema rewrite. Answers are never added to AI contexts or prediction inputs. Gender export needs profile consent; partner answers need both profile and sexual-information consent. Exports containing the new fields use version 5; old formats remain unchanged when fields are excluded. Reset uses existing profile deletion.

## Validation

- Initial Debug build-for-testing passed: `/tmp/cecy-device-feedback/build.log`.
- **86 unit/storage/transport tests in 12 suites passed** against the corrected source in `/tmp/cecy-device-feedback/corrected.xcresult` (3.192 seconds). These include nine new tests: eight device-feedback tests plus the transport question-boundary test. All requests use synthetic fixtures, never the live gateway.
- **All 11 affected UI scenarios have passing evidence across reruns**, not one green full-suite invocation. All four existing AI flows and three wellness flows passed in `/tmp/cecy-device-feedback/focused.xcresult`. New onboarding, question-cap and Today/month-calendar scenarios passed in `/tmp/cecy-device-feedback/corrected.xcresult`. Profile edit/save/relaunch/clear/second-relaunch passed in `/tmp/cecy-device-feedback/profile-final.xcresult` (79.750 seconds; TEST SUCCEEDED).
- **Unsigned iOS Release build passed** against the final app source: `/tmp/cecy-device-feedback/release-final.log`, `generic/platform=iOS`, `CODE_SIGNING_ALLOWED=NO`. Only the expected AppIntents metadata warning appeared. Not a signed-device or minimum-OS runtime result.
- Environment: Xcode 27, iPhone 17 Pro simulator / iOS 26.2. Test diagnostics collection was disabled; test logs and result bundles remain. No failures or expectations were disabled.
- Initial unit evidence in `unit.xcresult` was 85/86: a test compared profiles with different newly generated UUIDs. Fixed the fixture comparison, retaining full equality and legacy-decoding checks.
- Initial UI checks exposed a real native text-field issue: truncating only inside a custom binding capped stored state but left over-limit text visible. Direct binding plus bounded state normalization fixed it; the 100-character visible-text assertion now passes. Disclosure identifiers are now scoped to labels so nested profile controls retain their own identifiers. Test helpers distinguish toolbar buttons from form content, wait for expansion, and clear each lazy form section while visible. Save and relaunch assertions remain intact.
- The existing dynamic-Form invalid-frame runtime warning still appears in some flows. It is not treated as resolved by passing functional tests; physical layout/accessibility checks remain open. The editor also reported a stale `No such module Testing` diagnostic while Xcode compiled and executed those tests successfully.
- Added unit coverage: legacy decoding, partner exclusivity/clearing, durable profile reopen, independent export permissions, excluded identity context, question bounds including Unicode/all suggested prompts, mixed-day marker semantics and SF Symbol availability.
- Added UI coverage: centered/swipable Today dates, disabled future logging, mixed Calendar/Today records, question cap, profile edit/relaunch/clear, optional onboarding steps/back/skip. Existing AI/wellness/onboarding helpers are updated for the intended UI changes, not disabled.

## Still open

- Recheck these screens on the user’s physical device, including large text, VoiceOver, dark mode, iPad and privacy shielding.
- Existing live gateway contract/provider review and the historical full-app regression baseline remain open. Focused changes do not waive those gates.
- No commit or push unless requested.
