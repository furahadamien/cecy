# Native developer support

## October 2, 2026 — implementation

- Settings → About → Contact support displays `support@thabo.xyz` using the existing grouped Settings styling and Dynamic Type.
- Email developer checks `MFMailComposeViewController.canSendMail()` before presenting Apple's native in-app composer via a SwiftUI representable. The delegate dismisses the sheet for cancel, save, send and failure.
- If Mail composition is unavailable, SwiftUI `openURL` opens a `mailto:` link using the system's mail handler. A rejected URL displays actionable copy-address guidance, not a dead-end disabled button.
- The address is always visible/selectable and an explicit Copy email address button works without a mail account. Copy is local-only, not shared through Universal Clipboard.
- Both paths prefill only the support recipient and the generic subject “Cecy support”. The view has no tracker session reference. No health records, profile, device identifiers, logs or attachments are added; there is no analytics, backend, dependency or database change.
- Users review messages before sending. The screen explains that their email provider handles email and advises against sensitive details. Support email is not covered by the app's local-only record storage promise.
- Cancellation has no success/error claim. Saved drafts are described as unsent; a sent result means handed to Mail, not verified delivery. Failures are sanitized and leave the copy fallback available.
- Native composition deliberately retains Apple's controls and draft/cancel behavior rather than introducing an app-owned message editor or support backend.

## Research before implementation

Apple recommends checking availability before creating a mail composer, assigning a delegate and dismissing explicitly. A sent result does not verify delivery. SwiftUI supports `mailto:` handoff with an acceptance callback; acceptance also does not mean an email was sent.

- [MFMailComposeViewController](https://developer.apple.com/documentation/messageui/mfmailcomposeviewcontroller)
- [canSendMail](https://developer.apple.com/documentation/messageui/mfmailcomposeviewcontroller/cansendmail())
- [OpenURLAction](https://developer.apple.com/documentation/swiftui/openurlaction)

## Validation

Focused validation passed on October 2, 2026: all six ContactSupportTests unit tests and the ContactSupportUITests Settings/address/copy scenario passed together on the iPhone 17 Pro simulator (iOS 26.2). Tests verify recipient/subject-only URL construction, cancellation, unsent-draft and handoff-not-delivery wording, sanitized failures, navigation and copying. Debug app/test compilation and the separate unsigned generic-iOS Release build passed within their time limits. No external mail app was opened and no email was sent. Source diagnostics are clear. Logs: `/tmp/cecy-contact-support-validation.log` and `/tmp/cecy-contact-support-release.log`.

Real-device checks remain open: configured Apple Mail composition/cancel/save/send; third-party default mail app when native composition is unavailable; no installed email handler; offline sending/queue behavior; VoiceOver, largest text sizes and dark mode. Automated checks do not validate mailbox reachability, delivery or support response times. Historical full-suite and release acceptance gates remain unchanged. No live email or AI requests, commits or pushes.