import AuthenticationServices
import SwiftUI

struct AppleSignInSection: View {
    enum Purpose {
        case saveDetails, connect, reconnect
        var title: String {
            switch self {
            case .saveDetails: "Sign in with Apple to save your data and begin cycle tracking."
            case .connect: "Connect your Apple Account."
            case .reconnect: "Sign in to see your saved details."
            }
        }
    }
    @Environment(\.colorScheme) private var colorScheme
    let session: TrackerSession
    let profileID: UUID
    var purpose: Purpose = .saveDetails
    let onSuccess: () -> Void
    @State private var requestToken: UUID?

    var body: some View {
        Section {
            Text(purpose.title).font(.headline)
                .accessibilityIdentifier("appleSignInPurpose")
            if purpose != .saveDetails {
                Text("Your health records stay on this device.").foregroundStyle(.secondary)
            }
            #if DEBUG
            if session.account.usesTestAuthorization {
                Button("Continue with Apple (test)") {
                    if session.account.authorizeForUITest(profileID: profileID, protectsExistingProfile: session.snapshot.profile != nil) { onSuccess() }
                }.frame(minHeight: 50).accessibilityIdentifier("continueWithApple")
            } else { appleButton }
            #else
            appleButton
            #endif
            if let message = session.account.message { InlineError(message: message) }
        } footer: {
            if purpose != .saveDetails {
                Text("No cloud backup or cross-device restore. Internet is needed for Apple sign-in.")
            }
        }
        .disabled(!session.privacy.canAccess || session.account.isSigningIn || session.isSaving)
    }

    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            request.requestedScopes = [] // The preferred name comes from the local draft. No email is needed.
            requestToken = session.account.beginAuthorization()
        } onCompletion: { result in
            guard session.privacy.canAccess, let token = requestToken else { return }
            requestToken = nil
            if session.account.accept(result, token: token, profileID: profileID,
                                      protectsExistingProfile: session.snapshot.profile != nil) { onSuccess() }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 50)
        .accessibilityIdentifier("continueWithApple")
        .disabled(session.account.isSigningIn || session.isSaving)
    }
}
