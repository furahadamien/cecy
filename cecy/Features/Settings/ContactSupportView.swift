import SwiftUI
import MessageUI
import UIKit

/// Deliberately independent of the session: no records or diagnostics enter an email.
enum SupportContact {
    static let email = "support@thabo.xyz"
    static let subject = "Cecy support"

    static var mailURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        return components.url
    }

    static let unavailableMessage = "No email app could be opened. Copy the address and contact us from your preferred email service."

    static func completionMessage(for result: MFMailComposeResult, failed: Bool) -> String? {
        if failed { return "Your email couldn’t be prepared for sending. Try again, or copy the address to use another email app." }
        switch result {
        case .cancelled: return nil
        case .saved: return "Draft saved in Mail. It hasn’t been sent."
        case .sent: return "Your message was handed to Mail for sending. Check Mail for delivery status."
        case .failed: return "Your email couldn’t be prepared for sending. Try again, or copy the address to use another email app."
        @unknown default: return "Check Mail for the status of your message."
        }
    }
}

struct ContactSupportView: View {
    @Environment(\.openURL) private var openURL
    @State private var showComposer = false
    @State private var openingMail = false
    @State private var status: String?
    @AccessibilityFocusState private var statusFocused: Bool

    var body: some View {
        SettingsForm(title: "Contact support") {
            Section {
                Label("Reach the developer", systemImage: "envelope")
                    .font(.headline)
                Text("Questions, feedback, or something not working? Email the developer of Cecy.")
                Text(verbatim: SupportContact.email)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("supportEmailAddress")
                Button(action: composeEmail) {
                    Label("Email developer", systemImage: "square.and.pencil")
                        .frame(minHeight: 44)
                }
                .disabled(showComposer || openingMail)
                .accessibilityIdentifier("emailSupport")
                Button {
                    // Explicit copy only; don't sync the address through Universal Clipboard.
                    UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: SupportContact.email]],
                                                 options: [.localOnly: true])
                    status = "Email address copied."
                    statusFocused = true
                } label: {
                    Label("Copy email address", systemImage: "doc.on.doc")
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("copySupportEmail")
            } footer: {
                Text("You review the message before sending. Cecy adds no health records, personal details, or diagnostics. Email is handled by your email provider; avoid including sensitive information.")
            }
            if let status {
                Section {
                    Text(status)
                        .accessibilityFocused($statusFocused)
                        .accessibilityIdentifier("supportStatus")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showComposer, onDismiss: {
            statusFocused = status != nil
        }) {
            SupportMailComposer { result, failed in
                status = SupportContact.completionMessage(for: result, failed: failed)
                showComposer = false
            }
            .ignoresSafeArea()
        }
    }

    private func composeEmail() {
        guard !showComposer, !openingMail else { return }
        status = nil
        if MFMailComposeViewController.canSendMail() {
            showComposer = true
        } else if let url = SupportContact.mailURL {
            openingMail = true
            openURL(url) { accepted in
                openingMail = false
                if !accepted {
                    status = SupportContact.unavailableMessage
                    statusFocused = true
                }
            }
        } else {
            status = SupportContact.unavailableMessage
            statusFocused = true
        }
    }
}

private struct SupportMailComposer: UIViewControllerRepresentable {
    let onFinish: (MFMailComposeResult, Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([SupportContact.email])
        controller.setSubject(SupportContact.subject)
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (MFMailComposeResult, Bool) -> Void

        init(onFinish: @escaping (MFMailComposeResult, Bool) -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            onFinish(result, error != nil)
        }
    }
}